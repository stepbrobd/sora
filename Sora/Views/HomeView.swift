//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct HomeView: View {
    @State private var aniListItems: [AniListItem] = []
    @State private var trendingItems: [AniListItem] = []
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    
    private var currentDeviceSeasonAndYear: (season: String, year: Int) {
        let currentDate = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        
        let season: String
        switch month {
        case 1...3:
            season = "Winter"
        case 4...6:
            season = "Spring"
        case 7...9:
            season = "Summer"
        default:
            season = "Fall"
        }
        return (season, year)
    }
    
    private var trendingDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 5) {
                        Text("Seasonal")
                            .font(.headline)
                        Text("of \(currentDeviceSeasonAndYear.season) \(String(format: "%d", currentDeviceSeasonAndYear.year))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if aniListItems.isEmpty {
                                ForEach(0..<5, id: \.self) { _ in
                                    HomeSkeletonCell()
                                }
                            } else {
                                ForEach(aniListItems, id: \.id) { item in
                                    NavigationLink(destination: AniListDetailsView(animeID: item.id)) {
                                        VStack {
                                            KFImage(URL(string: item.coverImage.large))
                                                .placeholder {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 130, height: 195)
                                                        .shimmering()
                                                }
                                                .setProcessor(RoundCornerImageProcessor(cornerRadius: 10))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 130, height: 195)
                                                .cornerRadius(10)
                                                .clipped()
                                            
                                            Text(item.title.romaji)
                                                .font(.caption)
                                                .frame(width: 130)
                                                .lineLimit(1)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    
                    HStack(alignment: .bottom, spacing: 5) {
                        Text("Trending")
                            .font(.headline)
                        Text("on \(trendingDateString)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if trendingItems.isEmpty {
                                ForEach(0..<5, id: \.self) { _ in
                                    HomeSkeletonCell()
                                }
                            } else {
                                ForEach(trendingItems, id: \.id) { item in
                                    NavigationLink(destination: AniListDetailsView(animeID: item.id)) {
                                        VStack {
                                            KFImage(URL(string: item.coverImage.large))
                                                .placeholder {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 130, height: 195)
                                                        .shimmering()
                                                }
                                                .setProcessor(RoundCornerImageProcessor(cornerRadius: 10))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 130, height: 195)
                                                .cornerRadius(10)
                                                .clipped()
                                            
                                            Text(item.title.romaji)
                                                .font(.caption)
                                                .frame(width: 130)
                                                .lineLimit(1)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    if !continueWatchingItems.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Continue Watching")
                                .font(.headline)
                                .padding(.horizontal, 8)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(continueWatchingItems) { item in
                                        Button(action: {
                                            if UserDefaults.standard.string(forKey: "externalPlayer") == "Sora" {
                                                let customMediaPlayer = CustomMediaPlayer(
                                                    module: item.module,
                                                    urlString: item.streamUrl,
                                                    fullUrl: item.fullUrl,
                                                    title: item.mediaTitle,
                                                    episodeNumber: item.episodeNumber,
                                                    onWatchNext: { },
                                                    subtitlesURL: item.subtitles,
                                                    episodeImageUrl: item.imageUrl
                                                )
                                                let hostingController = UIHostingController(rootView: customMediaPlayer)
                                                hostingController.modalPresentationStyle = .fullScreen
                                                
                                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                   let rootVC = windowScene.windows.first?.rootViewController {
                                                    rootVC.present(hostingController, animated: true, completion: nil)
                                                }
                                            } else {
                                                let videoPlayerViewController = VideoPlayerViewController(module: item.module)
                                                videoPlayerViewController.streamUrl = item.streamUrl
                                                videoPlayerViewController.fullUrl = item.fullUrl
                                                videoPlayerViewController.episodeImageUrl = item.imageUrl
                                                videoPlayerViewController.episodeNumber = item.episodeNumber
                                                videoPlayerViewController.mediaTitle = item.mediaTitle
                                                videoPlayerViewController.modalPresentationStyle = .fullScreen
                                                
                                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                   let rootVC = windowScene.windows.first?.rootViewController {
                                                    rootVC.present(videoPlayerViewController, animated: true, completion: nil)
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
                                                .padding(.horizontal, 8)
                                            }
                                            .frame(width: 250, height: 190)
                                        }
                                        .contextMenu {
                                            Button(action: { markContinueWatchingItemAsWatched(item: item) }) {
                                                Label("Mark as Watched", systemImage: "checkmark.circle")
                                            }
                                            Button(role: .destructive, action: { removeContinueWatchingItem(item: item) }) {
                                                Label("Remove Item", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .frame(height: 190)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Home")
        }
        .onAppear {
            continueWatchingItems = ContinueWatchingManager.shared.fetchItems()
            AnilistServiceSeasonalAnime().fetchSeasonalAnime { items in
                if let items = items {
                    aniListItems = items
                }
            }
            AnilistServiceTrendingAnime().fetchTrendingAnime { items in
                if let items = items {
                    trendingItems = items
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func markContinueWatchingItemAsWatched(item: ContinueWatchingItem) {
        let key = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        UserDefaults.standard.set(99999999.0, forKey: key)
        UserDefaults.standard.set(99999999.0, forKey: totalKey)
        ContinueWatchingManager.shared.remove(item: item)
        
        if let index = continueWatchingItems.firstIndex(where: { $0.id == item.id }) {
            continueWatchingItems.remove(at: index)
        }
    }
    
    private func removeContinueWatchingItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        
        if let index = continueWatchingItems.firstIndex(where: { $0.id == item.id }) {
            continueWatchingItems.remove(at: index)
        }
    }
}
