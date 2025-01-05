//
//  ContentView.swift
//  Sora-JS
//
//  Created by Francesco on 04/01/25.
//

import SwiftUI
import Kingfisher

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
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
