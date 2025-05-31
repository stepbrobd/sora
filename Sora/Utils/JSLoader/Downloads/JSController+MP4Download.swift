//
//  JSController+MP4Download.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import SwiftUI

// Extension for handling MP4 direct video downloads
extension JSController {
    
    /// Initiates a download for a given MP4 URL
    /// - Parameters:
    ///   - url: The MP4 URL to download
    ///   - headers: HTTP headers to use for the request
    ///   - title: Title for the download (optional)
    ///   - imageURL: Image URL for the content (optional)
    ///   - isEpisode: Whether this is an episode (defaults to false)
    ///   - showTitle: Title of the show this episode belongs to (optional)
    ///   - season: Season number (optional)
    ///   - episode: Episode number (optional)
    ///   - subtitleURL: Optional subtitle URL to download after video (optional)
    ///   - completionHandler: Called when the download is initiated or fails
    func downloadMP4(url: URL, headers: [String: String], title: String? = nil, 
                   imageURL: URL? = nil, isEpisode: Bool = false, 
                   showTitle: String? = nil, season: Int? = nil, episode: Int? = nil,
                   subtitleURL: URL? = nil,
                   completionHandler: ((Bool, String) -> Void)? = nil) {
        
        print("---- MP4 DOWNLOAD PROCESS STARTED ----")
        print("MP4 URL: \(url.absoluteString)")
        print("Headers: \(headers)")
        print("Title: \(title ?? "None")")
        print("Is Episode: \(isEpisode), Show: \(showTitle ?? "None"), Season: \(season?.description ?? "None"), Episode: \(episode?.description ?? "None")")
        if let subtitle = subtitleURL {
            print("Subtitle URL: \(subtitle.absoluteString)")
        }
        
        // Validate URL
        guard url.scheme == "http" || url.scheme == "https" else {
            completionHandler?(false, "Invalid URL scheme")
            return
        }
        
        // Create metadata for the download
        var metadata: AssetMetadata? = nil
        if let title = title {
            metadata = AssetMetadata(
                title: title,
                posterURL: imageURL,
                showTitle: showTitle,
                season: season,
                episode: episode,
                showPosterURL: imageURL
            )
        }
        
        // Determine download type based on isEpisode
        let downloadType: DownloadType = isEpisode ? .episode : .movie
        
        // Generate a unique download ID
        let downloadID = UUID()
        
        // Get access to the download directory
        guard let downloadDirectory = getPersistentDownloadDirectory() else {
            print("MP4 Download: Failed to get download directory")
            completionHandler?(false, "Failed to create download directory")
            return
        }
        
        // Generate a safe filename for the MP4 file
        let sanitizedTitle = title?.replacingOccurrences(of: "[^A-Za-z0-9 ._-]", with: "", options: .regularExpression) ?? "download"
        let filename = "\(sanitizedTitle)_\(downloadID.uuidString.prefix(8)).mp4"
        let destinationURL = downloadDirectory.appendingPathComponent(filename)
        
        // Create an active download object with proper initial status
        var activeDownload = JSActiveDownload(
            id: downloadID,
            originalURL: url,
            task: nil, // Will be set after task creation
            queueStatus: .downloading,
            type: downloadType,
            metadata: metadata,
            title: title,
            imageURL: imageURL,
            subtitleURL: subtitleURL,
            headers: headers
        )
        
        // Enhanced session configuration for background downloads
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: "mp4-download-\(downloadID.uuidString)")
        sessionConfig.timeoutIntervalForRequest = 60.0
        sessionConfig.timeoutIntervalForResource = 3600.0 // 1 hour for large files
        sessionConfig.httpMaximumConnectionsPerHost = 1
        sessionConfig.allowsCellularAccess = true
        sessionConfig.shouldUseExtendedBackgroundIdleMode = true
        sessionConfig.waitsForConnectivity = true
        
        // Create custom session with delegate
        let customSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: .main)
        
        // Create the download task
        let downloadTask = customSession.downloadTask(with: request)
        
        // Update active download with the task
        activeDownload.task = downloadTask
        
        // Add to active downloads and create task mapping
        activeDownloads.append(activeDownload)
        activeDownloadMap[downloadTask] = downloadID
        
        // Store session reference
        storeSessionReference(session: customSession, for: downloadID)
        
        // Start download
        downloadTask.resume()
        print("MP4 Download: Task started for \(filename)")
        
        // Post initial status notification
        postDownloadNotification(.statusChange)
        
        // If this is an episode, post initial progress update
        if let episodeNumber = metadata?.episode {
            postDownloadNotification(.progress, userInfo: [
                "episodeNumber": episodeNumber,
                "progress": 0.0,
                "status": "downloading"
            ])
        }
        
        // Initial success callback
        completionHandler?(true, "Download started")
    }
    
    // MARK: - Helper Methods
    
    private func removeActiveDownload(downloadID: UUID) {
        // Find and remove the download
        if let index = activeDownloads.firstIndex(where: { $0.id == downloadID }) {
            let download = activeDownloads[index]
            activeDownloads.remove(at: index)
            
            // Clean up task mapping
            if let task = download.task {
                activeDownloadMap.removeValue(forKey: task)
            }
            
            // Clean up resources
            cleanupDownloadResources(for: downloadID)
            
            // Post status change notification
            postDownloadNotification(.statusChange)
        }
    }
    
    private func updateDownloadProgress(downloadID: UUID, progress: Double) {
        guard let index = activeDownloads.firstIndex(where: { $0.id == downloadID }) else { return }
        
        let previousProgress = activeDownloads[index].progress
        activeDownloads[index].progress = min(max(progress, 0.0), 1.0)
        
        // Only post notifications for meaningful progress changes (every 1% or completion)
        let progressDifference = progress - previousProgress
        if progressDifference >= 0.01 || progress >= 1.0 || previousProgress == 0.0 {
            // Post general progress notification
            postDownloadNotification(.progress)
            
            // Post detailed episode progress if applicable
            if let download = activeDownloads.first(where: { $0.id == downloadID }),
               let episodeNumber = download.metadata?.episode {
                let status = progress >= 1.0 ? "completed" : "downloading"
                postDownloadNotification(.progress, userInfo: [
                    "episodeNumber": episodeNumber,
                    "progress": progress,
                    "status": status
                ])
            }
        }
    }
    
    private func setupProgressObservation(for task: URLSessionDownloadTask, downloadID: UUID) {
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateDownloadProgress(downloadID: downloadID, progress: progress.fractionCompleted)
                NotificationCenter.default.post(name: NSNotification.Name("downloadProgressUpdated"), object: nil)
            }
        }
        
        if mp4ProgressObservations == nil {
            mp4ProgressObservations = [:]
        }
        mp4ProgressObservations?[downloadID] = observation
    }
    
    private func storeSessionReference(session: URLSession, for downloadID: UUID) {
        if mp4CustomSessions == nil {
            mp4CustomSessions = [:]
        }
        mp4CustomSessions?[downloadID] = session
    }
    
    private func cleanupDownloadResources(for downloadID: UUID) {
        mp4ProgressObservations?[downloadID] = nil
        mp4CustomSessions?[downloadID]?.invalidateAndCancel()
        mp4CustomSessions?[downloadID] = nil
    }
}

// MARK: - URLSessionDownloadDelegate for MP4 Downloads
extension JSController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Check if this is an MP4 download by checking if we have a custom session for it
        guard let downloadID = activeDownloadMap[downloadTask] else {
            // If not found in our mapping, it might be an AVAssetDownloadTask
            // Let the existing AVAssetDownloadDelegate handle it
            return
        }
        
        guard let downloadIndex = activeDownloads.firstIndex(where: { $0.id == downloadID }) else {
            print("MP4 Download: Couldn't find download for completed task")
            return
        }
        
        // Check if this download was cancelled
        if cancelledDownloadIDs.contains(downloadID) {
            print("MP4 Download: Ignoring completion for cancelled download")
            try? FileManager.default.removeItem(at: location)
            removeActiveDownload(downloadID: downloadID)
            return
        }
        
        let download = activeDownloads[downloadIndex]
        
        // Move file to final destination
        guard let downloadDirectory = getPersistentDownloadDirectory() else {
            print("MP4 Download: Failed to get download directory")
            removeActiveDownload(downloadID: downloadID)
            return
        }
        
        let sanitizedTitle = download.title?.replacingOccurrences(of: "[^A-Za-z0-9 ._-]", with: "", options: .regularExpression) ?? "download"
        let filename = "\(sanitizedTitle)_\(downloadID.uuidString.prefix(8)).mp4"
        let destinationURL = downloadDirectory.appendingPathComponent(filename)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            print("MP4 Download: Successfully saved to \(destinationURL.path)")
            
            // Verify file size
            let fileSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 ?? 0
            guard fileSize > 0 else {
                throw NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded file is empty"])
            }
            
            // Create downloaded asset
            let downloadedAsset = DownloadedAsset(
                name: download.title ?? download.originalURL.lastPathComponent,
                downloadDate: Date(),
                originalURL: download.originalURL,
                localURL: destinationURL,
                type: download.type,
                metadata: download.metadata,
                subtitleURL: download.subtitleURL
            )
            
            // Save asset
            savedAssets.append(downloadedAsset)
            saveAssets()
            
            // Update progress to complete
            updateDownloadProgress(downloadID: downloadID, progress: 1.0)
            
            // Download subtitle if provided
            if let subtitleURL = download.subtitleURL {
                downloadSubtitle(subtitleURL: subtitleURL, assetID: downloadedAsset.id.uuidString)
            }
            
            // Notify completion
            postDownloadNotification(.completed)
            
            // Clean up after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.removeActiveDownload(downloadID: downloadID)
            }
            
        } catch {
            print("MP4 Download Error saving file: \(error.localizedDescription)")
            removeActiveDownload(downloadID: downloadID)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Check if this is one of our MP4 downloads
        guard let downloadID = activeDownloadMap[downloadTask] else { return }
        
        // Calculate progress
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        
        DispatchQueue.main.async {
            self.updateDownloadProgress(downloadID: downloadID, progress: progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // Handle resume for MP4 downloads
        guard let downloadID = activeDownloadMap[downloadTask] else { return }
        
        let progress = expectedTotalBytes > 0 ? Double(fileOffset) / Double(expectedTotalBytes) : 0.0
        
        DispatchQueue.main.async {
            self.updateDownloadProgress(downloadID: downloadID, progress: progress)
            self.postDownloadNotification(.statusChange)
        }
        
        print("MP4 Download: Resumed at offset \(fileOffset) of \(expectedTotalBytes)")
    }
}

// MARK: - URLSessionDelegate
extension JSController: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        print("MP4 Download: Handling server trust challenge for host: \(host)")
        
        // Define trusted hosts for MP4 downloads
        let trustedHosts = [
            "streamtales.cc",
            "frembed.xyz", 
            "vidclouds.cc"
        ]
        
        let isTrustedHost = trustedHosts.contains { host.contains($0) }
        let isCustomSession = mp4CustomSessions?.values.contains(session) == true
        
        if isTrustedHost || isCustomSession {
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            
            print("MP4 Download: Accepting certificate for \(host)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("MP4 Download: Using default handling for \(host)")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
