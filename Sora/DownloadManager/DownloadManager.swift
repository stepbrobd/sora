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
    
    /// Downloads and converts an HLS stream to MP4, or downloads an MP4 stream normally.
    /// - Parameters:
    ///   - url: The stream URL (either .m3u8 or .mp4).
    ///   - title: The title used for creating the folder.
    ///   - episode: The episode number used for naming the output file.
    ///   - completion: Completion handler with a Bool indicating success and the URL of the output file.
    func downloadAndConvertHLS(from url: URL, title: String, episode: Int, completion: @escaping (Bool, URL?) -> Void) {
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
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "mp4" {
            let task = URLSession.shared.downloadTask(with: url) { tempLocalURL, response, error in
                if let tempLocalURL = tempLocalURL {
                    do {
                        try FileManager.default.moveItem(at: tempLocalURL, to: outputFileURL)
                        DispatchQueue.main.async {
                            Logger.shared.log("✅ Download successful: \(outputFileURL)")
                            completion(true, outputFileURL)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            Logger.shared.log("❌ Download failed: \(error)")
                            completion(false, nil)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        Logger.shared.log("❌ Download failed: \(error?.localizedDescription ?? "Unknown error")")
                        completion(false, nil)
                    }
                }
            }
            task.resume()
        } else if fileExtension == "m3u8" {
            let ffmpegCommand = [
                "ffmpeg",
                "-threads", "0",
                "-i", url.absoluteString,
                "-c", "copy",
                outputFileURL.path
            ]
            
            DispatchQueue.global(qos: .background).async {
                let success = ffmpeg(ffmpegCommand)
                DispatchQueue.main.async {
                    if (success == 0) {
                        Logger.shared.log("✅ Conversion successful: \(outputFileURL)")
                        completion(true, outputFileURL)
                    } else {
                        Logger.shared.log("❌ Conversion failed")
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
