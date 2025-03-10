//
//  DownloadManager.swift
//  Sulfur
//
//  Created by Francesco on 09/03/25.
//

import Foundation
import FFmpegSupport

class DownloadManager {
    static let shared = DownloadManager()
    
    private init() {}
    
    /// - Parameters:
    ///   - url: The stream URL (either .m3u8 or .mp4).
    ///   - title: The title used for creating the folder.
    ///   - episode: The episode number used for naming the output file.
    ///   - subtitleURL: An optional URL for the subtitle file (expects a .srt or .vtt file). (should work but not sure tbh).
    ///   - completion: Completion handler with a Bool indicating success and the URL of the output file.
    func downloadAndConvertHLS(from url: URL, title: String, episode: Int, subtitleURL: URL? = nil, completion: @escaping (Bool, URL?) -> Void) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(false, nil)
            return
        }
        
        let folderURL = documentsDirectory.appendingPathComponent(title)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating folder: \(error)")
                completion(false, nil)
                return
            }
        }
        
        let outputFileName = "\(title)_Episode\(episode).mp4"
        let outputFileURL = folderURL.appendingPathComponent(outputFileName)
        let downloadID = UUID()
        NotificationCenter.default.post(name: .downloadStarted, object: nil, userInfo: ["fileName": outputFileName, "id": downloadID])
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "mp4" {
            let delegate = DownloadTaskDelegate(downloadID: downloadID, fileName: outputFileName, outputFileURL: outputFileURL, completion: completion)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        } else if fileExtension == "m3u8" {
            DispatchQueue.global(qos: .background).async {
                var ffmpegCommand = ["ffmpeg", "-threads", "0", "-i", url.absoluteString]
                
                if let subtitleURL = subtitleURL {
                    do {
                        let subtitleData = try Data(contentsOf: subtitleURL)
                        let subtitleFileExtension = subtitleURL.pathExtension.lowercased()
                        if subtitleFileExtension != "srt" && subtitleFileExtension != "vtt" {
                            Logger.shared.log("❌ Unsupported subtitle format: \(subtitleFileExtension)")
                        }
                        let subtitleFileName = "\(title)_Episode\(episode).\(subtitleFileExtension)"
                        let subtitleLocalURL = folderURL.appendingPathComponent(subtitleFileName)
                        try subtitleData.write(to: subtitleLocalURL)
                        ffmpegCommand.append(contentsOf: ["-i", subtitleLocalURL.path])
                        ffmpegCommand.append(contentsOf: ["-c", "copy", "-c:s", "mov_text", outputFileURL.path])
                    } catch {
                        Logger.shared.log("❌ Subtitle download failed: \(error)")
                        ffmpegCommand.append(contentsOf: ["-c", "copy", outputFileURL.path])
                    }
                } else {
                    ffmpegCommand.append(contentsOf: ["-c", "copy", outputFileURL.path])
                }
                
                let success = ffmpeg(ffmpegCommand)
                DispatchQueue.main.async {
                    if success == 0 {
                        Logger.shared.log("✅ Conversion successful: \(outputFileURL)")
                        NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["id": downloadID, "success": true])
                        completion(true, outputFileURL)
                    } else {
                        Logger.shared.log("❌ Conversion failed")
                        NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["id": downloadID, "success": false])
                        completion(false, nil)
                    }
                }
            }
        } else {
            Logger.shared.log("❌ Unsupported file type: \(fileExtension)")
            completion(false, nil)
        }
    }
}

class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate {
    let downloadID: UUID
    let outputFileURL: URL
    let completion: (Bool, URL?) -> Void
    let fileName: String
    let startTime: Date
    var lastTime: Date
    
    init(downloadID: UUID, fileName: String, outputFileURL: URL, completion: @escaping (Bool, URL?) -> Void) {
        self.downloadID = downloadID
        self.fileName = fileName
        self.outputFileURL = outputFileURL
        self.completion = completion
        self.startTime = Date()
        self.lastTime = Date()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastTime)
        var speed: Double = 0.0
        if timeInterval > 0 {
            speed = Double(bytesWritten) / timeInterval
        }
        lastTime = now
        
        let downloadedMB = Double(totalBytesWritten) / 1024.0 / 1024.0
        let speedMB = speed / 1024.0 / 1024.0
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .downloadProgressUpdate, object: nil, userInfo: [
                "id": self.downloadID,
                "progress": progress,
                "downloadedSize": String(format: "%.2f MB", downloadedMB),
                "downloadSpeed": String(format: "%.2f MB/s", speedMB)
            ])
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            try FileManager.default.moveItem(at: location, to: outputFileURL)
            DispatchQueue.main.async {
                Logger.shared.log("✅ Download successful: \(self.outputFileURL)")
                NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["id": self.downloadID, "success": true])
                self.completion(true, self.outputFileURL)
            }
        } catch {
            DispatchQueue.main.async {
                Logger.shared.log("❌ Download failed: \(error)")
                NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["id": self.downloadID, "success": false])
                self.completion(false, nil)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                Logger.shared.log("❌ Download failed: \(error.localizedDescription)")
                NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: ["id": self.downloadID, "success": false])
                self.completion(false, nil)
            }
        }
    }
}
