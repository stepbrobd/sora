//
//  DownloadView.swift
//  Sulfur
//
//  Created by Francesco on 29/04/25.
//

import SwiftUI
import AVKit

struct DownloadedAsset: Identifiable, Codable {
    let id: UUID
    var name: String
    let downloadDate: Date
    let originalURL: URL
    let localURL: URL
    var fileSize: Int64?
    
    init(id: UUID = UUID(), name: String, downloadDate: Date, originalURL: URL, localURL: URL) {
        self.id = id
        self.name = name
        self.downloadDate = downloadDate
        self.originalURL = originalURL
        self.localURL = localURL
        self.fileSize = getFileSize()
    }
    
    func getFileSize() -> Int64? {
        do {
            let values = try localURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            return nil
        }
    }
}

struct DownloadView: View {
    @StateObject private var viewModel = DownloadManager()
    @State private var showingDeleteAlert = false
    @State private var assetToDelete: DownloadedAsset?
    @State private var renameText = ""
    @State private var assetToRename: DownloadedAsset?
    
    var body: some View {
        NavigationView {
            List {
                if !viewModel.activeDownloads.isEmpty {
                    Section("Active Downloads") {
                        ForEach(viewModel.activeDownloads) { download in
                            DownloadProgressView(download: download)
                        }
                    }
                }
                
                if !viewModel.savedAssets.isEmpty {
                    Section("Completed Downloads") {
                        ForEach(viewModel.savedAssets) { asset in
                            NavigationLink {
                                VideoPlayer(player: AVPlayer(url: asset.localURL))
                                    .navigationTitle(asset.name)
                            } label: {
                                AssetRowView(asset: asset)
                            }
                            .contextMenu {
                                Button(action: { startRenaming(asset) }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: { confirmDelete(asset) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                if viewModel.activeDownloads.isEmpty && viewModel.savedAssets.isEmpty {
                    Section {
                        Text("No downloads")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Downloads")
            .alert("Delete Download", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let asset = assetToDelete {
                        viewModel.deleteAsset(asset)
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(assetToDelete?.name ?? "this download")?")
            }
            .alert("Rename Download", isPresented: Binding(
                get: { assetToRename != nil },
                set: { if !$0 { assetToRename = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renameText = ""
                    assetToRename = nil
                }
                Button("Save") {
                    if let asset = assetToRename {
                        viewModel.renameAsset(asset, newName: renameText)
                    }
                    renameText = ""
                    assetToRename = nil
                }
            }
        }
    }
    
    private func confirmDelete(_ asset: DownloadedAsset) {
        assetToDelete = asset
        showingDeleteAlert = true
    }
    
    private func startRenaming(_ asset: DownloadedAsset) {
        assetToRename = asset
        renameText = asset.name
    }
}