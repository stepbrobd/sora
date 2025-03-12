//
//  DownloadManager.swift
//  Sulfur
//
//  Created by Francesco on 09/03/25.
//

import Foundation
import FFmpegSupport
import UIKit

extension Notification.Name {
    static let DownloadManagerStatusUpdate = Notification.Name("DownloadManagerStatusUpdate")
}

class DownloadManager {
    static let shared = DownloadManager()
    
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var activeConversions = [String: Bool]()
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func applicationWillResignActive() {
        if !activeConversions.isEmpty {
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    func downloadAndConvertHLS(from url: URL, title: String, episode: Int, subtitleURL: URL? = nil, sourceName: String, completion: @escaping (Bool, URL?) -> Void) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(false, nil)
            return
        }
        
        let folderURL = documentsDirectory.appendingPathComponent(title + "-" + sourceName)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logger.shared.log("Error creating folder: \(error)")
                completion(false, nil)
                return
            }
        }
        
        let outputFileName = "\(title)_Episode\(episode)_\(sourceName).mp4"
        let outputFileURL = folderURL.appendingPathComponent(outputFileName)
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "mp4" {
            NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                "title": title,
                "episode": episode,
                "type": "mp4",
                "status": "Downloading",
                "progress": 0.0
            ])
            
            let task = URLSession.custom.downloadTask(with: url) { tempLocalURL, response, error in
                if let tempLocalURL = tempLocalURL {
                    do {
                        try FileManager.default.moveItem(at: tempLocalURL, to: outputFileURL)
                        NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                            "title": title,
                            "episode": episode,
                            "type": "mp4",
                            "status": "Completed",
                            "progress": 1.0
                        ])
                        DispatchQueue.main.async {
                            Logger.shared.log("Download successful: \(outputFileURL)")
                            completion(true, outputFileURL)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            Logger.shared.log("Download failed: \(error)")
                            completion(false, nil)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        Logger.shared.log("Download failed: \(error?.localizedDescription ?? "Unknown error")")
                        completion(false, nil)
                    }
                }
            }
            task.resume()
        } else if fileExtension == "m3u8" {
            let conversionKey = "\(title)_\(episode)_\(sourceName)"
            activeConversions[conversionKey] = true
            
            if UIApplication.shared.applicationState != .active && backgroundTaskIdentifier == .invalid {
                backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
                    self?.endBackgroundTask()
                }
            }
            
            DispatchQueue.global(qos: .background).async {
                NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                    "title": title,
                    "episode": episode,
                    "type": "hls",
                    "status": "Converting",
                    "progress": 0.0
                ])
                
                let multiThreads = UserDefaults.standard.bool(forKey: "multiThreads")
                var ffmpegCommand: [String]
                if multiThreads {
                    ffmpegCommand = ["ffmpeg", "-y", "-threads", "0", "-i", url.absoluteString]
                } else {
                    ffmpegCommand = ["ffmpeg", "-y", "-i", url.absoluteString]
                }
                
                if let subtitleURL = subtitleURL {
                    do {
                        let subtitleData = try Data(contentsOf: subtitleURL)
                        let subtitleFileExtension = subtitleURL.pathExtension.lowercased()
                        if subtitleFileExtension != "srt" && subtitleFileExtension != "vtt" {
                            Logger.shared.log("Unsupported subtitle format: \(subtitleFileExtension)")
                        }
                        let subtitleFileName = "\(title)_Episode\(episode).\(subtitleFileExtension)"
                        let subtitleLocalURL = folderURL.appendingPathComponent(subtitleFileName)
                        try subtitleData.write(to: subtitleLocalURL)
                        ffmpegCommand.append(contentsOf: ["-i", subtitleLocalURL.path])
                        ffmpegCommand.append(contentsOf: ["-c:v", "copy", "-c:a", "copy", "-c:s", "mov_text", outputFileURL.path])
                    } catch {
                        Logger.shared.log("Subtitle download failed: \(error)")
                        ffmpegCommand.append(contentsOf: ["-c:v", "copy", "-c:a", "copy", outputFileURL.path])
                    }
                } else {
                    ffmpegCommand.append(contentsOf: ["-c:v", "copy", "-c:a", "copy", outputFileURL.path])
                }
                
                NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                    "title": title,
                    "episode": episode,
                    "type": "hls",
                    "status": "Converting",
                    "progress": 0.5
                ])
                
                let success = ffmpeg(ffmpegCommand)
                DispatchQueue.main.async { [weak self] in
                    if success == 0 {
                        NotificationCenter.default.post(name: .DownloadManagerStatusUpdate, object: nil, userInfo: [
                            "title": title,
                            "episode": episode,
                            "type": "hls",
                            "status": "Completed",
                            "progress": 1.0
                        ])
                        Logger.shared.log("Conversion successful: \(outputFileURL)")
                        completion(true, outputFileURL)
                    } else {
                        Logger.shared.log("Conversion failed")
                        completion(false, nil)
                    }
                    
                    self?.activeConversions[conversionKey] = nil
                    
                    if self?.activeConversions.isEmpty ?? true {
                        self?.endBackgroundTask()
                    }
                }
            }
        } else {
            Logger.shared.log("Unsupported file type: \(fileExtension)")
            completion(false, nil)
        }
    }
}
