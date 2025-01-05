//
//  ContentView.swift
//  Sora-JS
//
//  Created by Francesco on 04/01/25.
//

import SwiftUI

struct AnimeItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
}

struct ContentView: View {
    @StateObject private var jsController = JSController()
    @EnvironmentObject var moduleManager: ModuleManager
    @State private var searchText = ""
    @State private var animeItems: [AnimeItem] = []
    @State private var isSearching = false
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    
    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let selectedModule = selectedModule {
                    HStack {
                        AsyncImage(url: URL(string: selectedModule.metadata.iconUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 30, height: 30)
                        .cornerRadius(6)
                        
                        VStack(alignment: .leading) {
                            Text(selectedModule.metadata.mediaType)
                                .font(.headline)
                            Text(selectedModule.metadata.language)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(moduleManager.modules) { module in
                                Button {
                                    selectedModuleId = module.id.uuidString
                                } label: {
                                    HStack {
                                        AsyncImage(url: URL(string: module.metadata.iconUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } placeholder: {
                                            Color.gray
                                        }
                                        .frame(width: 20, height: 20)
                                        .cornerRadius(4)
                                        
                                        Text(module.metadata.mediaType)
                                        Spacer()
                                        if module.id.uuidString == selectedModuleId {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                } else {
                    VStack(spacing: 8) {
                        Text("No Module Selected")
                            .font(.headline)
                        Text("Please select a module from settings")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                }
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchText) { newValue in
                        guard !newValue.isEmpty, let module = selectedModule else {
                            animeItems = []
                            return
                        }
                        
                        isSearching = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            Task {
                                do {
                                    let jsContent = try moduleManager.getModuleContent(module)
                                    jsController.loadScript(jsContent)
                                    jsController.scrapeAnime(keyword: newValue, module: module) { items in
                                        animeItems = items
                                        isSearching = false
                                    }
                                } catch {
                                    print("Error loading module: \(error)")
                                    isSearching = false
                                }
                            }
                        }
                    }
                
                if isSearching {
                    ProgressView()
                        .padding()
                }
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(animeItems) { item in
                            VStack(alignment: .leading) {
                                if let url = URL(string: item.imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                ProgressView()
                                            )
                                    }
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(8)
                                }
                                
                                Text(item.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .padding(.vertical, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gear")
                }
            }
        }
    }
}
