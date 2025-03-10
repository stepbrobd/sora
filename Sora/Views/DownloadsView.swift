//
//  DownloadsView.swift
//  Sulfur
//
//  Created by Francesco on 10/03/25.
//

import SwiftUI
import Combine

extension Notification.Name {
    static let downloadStarted = Notification.Name("downloadStarted")
    static let downloadProgressUpdate = Notification.Name("downloadProgressUpdate")
    static let downloadCompleted = Notification.Name("downloadCompleted")
}

struct DownloadItem: Identifiable {
    let id = UUID()
    let fileName: String
    var status: String = "Downloading"
    var progress: Double = 0.0
    var downloadedSize: String = "0 MB"
    var downloadSpeed: String = "0 MB/s"
}

class DownloadsViewModel: ObservableObject {
    @Published var downloads: [DownloadItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: .downloadStarted)
            .sink { [weak self] notification in
                if let fileName = notification.userInfo?["fileName"] as? String {
                    let newDownload = DownloadItem(fileName: fileName)
                    self?.downloads.append(newDownload)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .downloadProgressUpdate)
            .sink { [weak self] notification in
                guard let id = notification.userInfo?["id"] as? UUID,
                      let progress = notification.userInfo?["progress"] as? Double,
                      let downloadedSize = notification.userInfo?["downloadedSize"] as? String,
                      let downloadSpeed = notification.userInfo?["downloadSpeed"] as? String else {
                    return
                }
                if let index = self?.downloads.firstIndex(where: { $0.id == id }) {
                    self?.downloads[index].progress = progress
                    self?.downloads[index].downloadedSize = downloadedSize
                    self?.downloads[index].downloadSpeed = downloadSpeed
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .downloadCompleted)
            .sink { [weak self] notification in
                guard let id = notification.userInfo?["id"] as? UUID,
                      let success = notification.userInfo?["success"] as? Bool else {
                    return
                }
                if let index = self?.downloads.firstIndex(where: { $0.id == id }) {
                    self?.downloads[index].status = success ? "Completed" : "Failed"
                    self?.downloads[index].progress = success ? 1.0 : self?.downloads[index].progress ?? 0.0
                }
            }
            .store(in: &cancellables)
    }
}

struct DownloadsView: View {
    @StateObject var viewModel = DownloadsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.downloads) { download in
                DownloadRow(download: download)
            }
            .navigationTitle("Downloads")
        }
    }
}

struct DownloadRow: View {
    let download: DownloadItem
    
    var iconName: String {
        switch download.status {
        case "Downloading":
            return "arrow.down.circle"
        case "Completed":
            return "checkmark.circle"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.blue)
                Text(download.fileName)
                    .font(.headline)
            }
            ProgressView(value: download.progress)
                .progressViewStyle(LinearProgressViewStyle())
            HStack {
                Text("Speed: \(download.downloadSpeed)")
                Spacer()
                Text("Size: \(download.downloadedSize)")
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
    }
}
