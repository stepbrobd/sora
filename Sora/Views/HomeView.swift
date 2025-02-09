//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.0), location: 0.3),
                                .init(color: Color.white.opacity(0.6), location: 0.5),
                                .init(color: Color.white.opacity(0.0), location: 0.7)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: self.phase * 300)
                    .blendMode(.plusLighter)
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    self.phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        self.modifier(Shimmer())
    }
}

struct SkeletonCell: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 130, height: 195)
                .cornerRadius(10)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 130, height: 20)
                .padding(.top, 4)
                .shimmering()
        }
    }
}

struct HomeView: View {
    @State private var aniListItems: [AniListItem] = []
    @State private var trendingItems: [AniListItem] = []
    
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
                                    SkeletonCell()
                                }
                            } else {
                                ForEach(aniListItems, id: \.id) { item in
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
                                    SkeletonCell()
                                }
                            } else {
                                ForEach(trendingItems, id: \.id) { item in
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
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Home")
        }
        .onAppear {
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
}
