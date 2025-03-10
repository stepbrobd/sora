//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct LibraryView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Continue Watching")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal, 20)
                        
                        if continueWatchingItems.isEmpty {
                            Text("No items to continue watching")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                        } else {
                            ContinueWatchingSection(items: $continueWatchingItems, markAsWatched: { item in
                                markContinueWatchingItemAsWatched(item: item)
                            }, removeItem: { item in
                                removeContinueWatchingItem(item: item)
                            })
                        }
                    }
                    
                    Group {
                        Text("Bookmarks")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal, 20)
                        
                        if libraryManager.bookmarks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magazine")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No Items saved")
                                    .font(.headline)
                                Text("Bookmark items for easy access later")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(libraryManager.bookmarks) { item in
                                    if let module = moduleManager.modules.first(where: { $0.id.uuidString == item.moduleId }) {
                                        NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: module)) {
                                            VStack {
                                                ZStack(alignment: .bottomTrailing) {
                                                    KFImage(URL(string: item.imageUrl))
                                                        .placeholder {
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 150, height: 225)
                                                                .shimmering()
                                                        }
                                                        .resizable()
                                                        .aspectRatio(2/3, contentMode: .fill)
                                                        .cornerRadius(10)
                                                        .frame(width: 150, height: 225)
                                                    
                                                    KFImage(URL(string: module.metadata.iconUrl))
                                                        .placeholder {
                                                            Circle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 35, height: 35)
                                                                .shimmering()
                                                        }
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 35, height: 35)
                                                        .clipShape(Circle())
                                                }
                                                
                                                Text(item.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Library")
            .onAppear {
                fetchContinueWatching()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func fetchContinueWatching() {
        continueWatchingItems = ContinueWatchingManager.shared.fetchItems()
    }
    
    private func markContinueWatchingItemAsWatched(item: ContinueWatchingItem) {
        let key = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        UserDefaults.standard.set(99999999.0, forKey: key)
        UserDefaults.standard.set(99999999.0, forKey: totalKey)
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll { $0.id == item.id }
    }
    
    private func removeContinueWatchingItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll { $0.id == item.id }
    }
}

struct ContinueWatchingSection: View {
    @Binding var items: [ContinueWatchingItem]
    var markAsWatched: (ContinueWatchingItem) -> Void
    var removeItem: (ContinueWatchingItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.reversed())) { item in
                        ContinueWatchingCell(item: item,
                                             markAsWatched: {
                            markAsWatched(item)
                        },
                                             removeItem: {
                            removeItem(item)
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 190)
        }
    }
}

struct ContinueWatchingCell: View {
    let item: ContinueWatchingItem
    var markAsWatched: () -> Void
    var removeItem: () -> Void
    
    var body: some View {
        Button(action: {
            if UserDefaults.standard.string(forKey: "externalPlayer") == "Default" {
                let videoPlayerViewController = VideoPlayerViewController(module: item.module)
                videoPlayerViewController.streamUrl = item.streamUrl
                videoPlayerViewController.fullUrl = item.fullUrl
                videoPlayerViewController.episodeImageUrl = item.imageUrl
                videoPlayerViewController.episodeNumber = item.episodeNumber
                videoPlayerViewController.mediaTitle = item.mediaTitle
                videoPlayerViewController.subtitles = item.subtitles ?? ""
                videoPlayerViewController.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(videoPlayerViewController, animated: true, completion: nil)
                }
            } else {
                let customMediaPlayer = CustomMediaPlayerViewController(
                    module: item.module,
                    urlString: item.streamUrl,
                    fullUrl: item.fullUrl,
                    title: item.mediaTitle,
                    episodeNumber: item.episodeNumber,
                    onWatchNext: { },
                    subtitlesURL: item.subtitles,
                    episodeImageUrl: item.imageUrl
                )
                customMediaPlayer.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(customMediaPlayer, animated: true, completion: nil)
                }
            }
        }) {
            VStack(alignment: .leading) {
                ZStack {
                    KFImage(URL(string: item.imageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : item.imageUrl))
                        .placeholder {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 240, height: 135)
                                .shimmering()
                        }
                        .setProcessor(RoundCornerImageProcessor(cornerRadius: 10))
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 240, height: 135)
                        .cornerRadius(10)
                        .clipped()
                        .overlay(
                            KFImage(URL(string: item.module.metadata.iconUrl))
                                .resizable()
                                .frame(width: 24, height: 24)
                                .cornerRadius(4)
                                .padding(4),
                            alignment: .topLeading
                        )
                }
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .blur(radius: 3)
                            .frame(height: 30)
                        
                        ProgressView(value: item.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .padding(.horizontal, 8)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    },
                    alignment: .bottom
                )
                
                VStack(alignment: .leading) {
                    Text("Episode \(item.episodeNumber)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    Text(item.mediaTitle)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: 240, height: 170)
        }
        .contextMenu {
            Button(action: { markAsWatched() }) {
                Label("Mark as Watched", systemImage: "checkmark.circle")
            }
            Button(role: .destructive, action: { removeItem() }) {
                Label("Remove Item", systemImage: "trash")
            }
        }
    }
}
