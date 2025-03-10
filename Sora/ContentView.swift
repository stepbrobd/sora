//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI
import Kingfisher

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle.fill")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
