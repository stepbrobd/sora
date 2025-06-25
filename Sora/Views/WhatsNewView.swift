//
//  WhatsNewView.swift
//  Sora
//
//  Created by Francesco on 25/06/25.
//

import SwiftUI
import SlideOverCard

struct WhatsNewView: View {
    @AppStorage("lastVersionPrompt") private var lastVersionPrompt: String = ""
    @Binding var isPresented: Bool
    
    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    private let whatsNewItems = [
        WhatsNewItem(title: "Brand new UI", description: "Enjoy this brand new look of Sora", icon: "sparkles"),
        WhatsNewItem(title: "TMDB Metadata", description: "Various UI improvements and animations across the app", icon: "bolt.fill"),
        WhatsNewItem(title: "Download Support", description: "For both mp4 and HLS with Multi server support", icon: "tray.and.arrow.down.fill")
    ]
    
    var body: some View {
        VStack(alignment: .center, spacing: 25) {
            HStack {
                Text("What's New in Sora")
                    .font(.system(size: 28, weight: .bold))
                Text("Version \(currentVersion)")
                    .foregroundColor(.gray)
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(whatsNewItems) { item in
                        WhatsNewItemView(item: item)
                    }
                }
                .padding(.horizontal)
            }
            
            VStack(spacing: 0) {
                Button("Continue", action: {
                    lastVersionPrompt = currentVersion
                    isPresented = false
                }).buttonStyle(SOCActionButton())
                
                Button("Release Notes", action: {
                    if let url = URL(string: "https://github.com/cranci1/Sora/releases/tag/1.0.0") {
                        UIApplication.shared.open(url)
                    }
                }).buttonStyle(SOCEmptyButton())
            }
        }
        .frame(height: 480)
    }
}

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
}

struct WhatsNewItemView: View {
    let item: WhatsNewItem
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: item.icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
