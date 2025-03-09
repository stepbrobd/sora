//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct HomeView: View {
    @AppStorage("trackingService") private var tracingService: String = "AniList"
    @State private var aniListItems: [AniListItem] = []
    @State private var trendingItems: [AniListItem] = []
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var isLoading: Bool = true
    
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
                VStack(alignment: .leading) {
                    if !continueWatchingItems.isEmpty {
                        ContinueWatchingSection(items: $continueWatchingItems) { item in
                            markContinueWatchingItemAsWatched(item: item)
                        } removeItem: { item in
                            removeContinueWatchingItem(item: item)
                        }
                    }
                    
                    SeasonalSection(
                        title: "Seasonal of \(currentDeviceSeasonAndYear.season) \(String(format: "%d", currentDeviceSeasonAndYear.year))",
                        items: aniListItems,
                        isLoading: isLoading
                    )
                    
                    TrendingSection(
                        title: "Trending on \(trendingDateString)",
                        items: trendingItems,
                        isLoading: isLoading
                    )
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Home")
            .onAppear {
                fetchData()
            }
            .refreshable {
                fetchData()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func fetchData() {
        isLoading = true
        continueWatchingItems = ContinueWatchingManager.shared.fetchItems()
        
        let fetchSeasonal: (@escaping ([AniListItem]?) -> Void) -> Void
        let fetchTrending: (@escaping ([AniListItem]?) -> Void) -> Void
        
        if tracingService == "TMDB" {
            fetchSeasonal = TMDBSeasonal.fetchTMDBSeasonal
            fetchTrending = TMBDTrending.fetchTMDBTrending
        } else {
            fetchSeasonal = AnilistServiceSeasonalAnime().fetchSeasonalAnime
            fetchTrending = AnilistServiceTrendingAnime().fetchTrendingAnime
        }
        
        fetchSeasonal { items in
            aniListItems = items ?? []
            checkLoadingState()
        }
        
        fetchTrending { items in
            trendingItems = items ?? []
            checkLoadingState()
        }
    }
    
    private func checkLoadingState() {
        if !aniListItems.isEmpty && !trendingItems.isEmpty {
            isLoading = false
        }
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
        LazyVStack(alignment: .leading) {
            SectionHeader(title: "Continue Watching")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.reversed())) { item in
                        ContinueWatchingCell(item: item) {
                            markAsWatched(item)
                        } removeItem: {
                            removeItem(item)
                        }
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
            if UserDefaults.standard.string(forKey: "externalPlayer") == "Sora" {
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
            } else {
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

struct SeasonalSection: View {
    let title: String
    let items: [AniListItem]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            HomeSkeletonCell()
                        }
                    } else {
                        ForEach(items, id: \.id) { item in
                            NavigationLink(destination: AniListDetailsView(animeID: item.id)) {
                                AnimeItemCell(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct TrendingSection: View {
    let title: String
    let items: [AniListItem]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            HomeSkeletonCell()
                        }
                    } else {
                        ForEach(items, id: \.id) { item in
                            NavigationLink(destination: AniListDetailsView(animeID: item.id)) {
                                AnimeItemCell(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }
}

struct AnimeItemCell: View {
    let item: AniListItem
    
    var body: some View {
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
