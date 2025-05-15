//
//  DownloadView.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import AVKit
import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadView: View {
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var selectedAsset: DownloadedAsset?
    @State private var showingDeleteAlert = false
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var selectedSegment = 0
    @State private var player: AVPlayer?
    
    @AppStorage("defaultPlayer") private var defaultPlayer: String = "Default"
    
    enum Tab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Downloads", selection: $selectedSegment) {
                    ForEach(0..<Tab.allCases.count, id: \.self) { index in
                        Text(Tab.allCases[index].rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedSegment == 0 {
                    if downloadManager.activeDownloads.isEmpty {
                        EmptyStateView(
                            title: "No Active Downloads",
                            systemImage: "arrow.down.circle",
                            description: "Downloads in progress will appear here"
                        )
                    } else {
                        List {
                            ForEach(downloadManager.activeDownloads) { download in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(download.originalURL.lastPathComponent)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    ProgressView(value: download.progress) {
                                        Text("\(Int(download.progress * 100))%")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    if downloadManager.savedAssets.isEmpty {
                        EmptyStateView(
                            title: "No Completed Downloads",
                            systemImage: "arrow.down.circle",
                            description: "Completed Downloads will appear here"
                        )
                    } else {
                        List {
                            ForEach(downloadManager.savedAssets) { asset in
                                Button(action: { playAsset(asset) }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(asset.name)
                                                .font(.headline)
                                                .lineLimit(1)
                                            
                                            if let size = asset.fileSize {
                                                Text("\(formatFileSize(size)) • \(formatDate(asset.downloadDate))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .contextMenu {
                                    Button(action: {
                                        renameText = asset.name
                                        selectedAsset = asset
                                        showingRenameAlert = true
                                    }) {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        selectedAsset = asset
                                        showingDeleteAlert = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .alert("Delete Download", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let asset = selectedAsset {
                        downloadManager.deleteAsset(asset)
                        selectedAsset = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete '\(selectedAsset?.name ?? "")'?")
            }
            .alert("Rename Download", isPresented: $showingRenameAlert) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    showingRenameAlert = false
                }
                Button("Save") {
                    if let asset = selectedAsset {
                        downloadManager.renameAsset(asset, newName: renameText)
                    }
                    showingRenameAlert = false
                }
            }
        }
    }
    private func playAsset(_ asset: DownloadedAsset) {
        if defaultPlayer == "Default" {
            let playerVC = VideoPlayerViewController(module: asset.module)
            playerVC.streamUrl = asset.localURL.absoluteString
            playerVC.fullUrl = asset.originalURL.absoluteString
            playerVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                findTopViewController.findViewController(rootVC).present(playerVC, animated: true, completion: nil)
            }
        } else {
            let playerVC = CustomMediaPlayerViewController(
                module: asset.module,
                urlString: asset.localURL.absoluteString,
                fullUrl: asset.originalURL.absoluteString,
                title: asset.name,
                episodeNumber: 1,
                onWatchNext: {},
                subtitlesURL: nil,
                aniListID: 0,
                episodeImageUrl: "",
                headers: nil
            )
            playerVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                findTopViewController.findViewController(rootVC).present(playerVC, animated: true, completion: nil)
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
