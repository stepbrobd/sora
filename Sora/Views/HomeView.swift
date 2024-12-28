//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher
import SwiftSoup

struct HomeView: View {
    @StateObject private var modulesManager = ModulesManager()
    @State private var featuredItems: [String: [SearchResult]] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    if isLoading {
                        ProgressView("Loading Featured Items...")
                            .padding()
                    } else {
                        ForEach(modulesManager.modules, id: \.name) { module in
                            if let items = featuredItems[module.name], !items.isEmpty {
                                VStack(alignment: .leading) {
                                    HStack(alignment: .bottom) {
                                        Text("Featured")
                                            .font(.title2)
                                            .bold()
                                            .padding(.leading)
                                        
                                        Text("on \(module.name)")
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                            .bold()
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 20) {
                                            ForEach(items) { item in
                                                NavigationLink(destination: AnimeInfoView(module: module, anime: item)) {
                                                    VStack {
                                                        KFImage(URL(string: item.imageUrl))
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 120, height: 180)
                                                            .clipped()
                                                            .cornerRadius(8)
                                                        
                                                        Text(item.name)
                                                            .font(.caption)
                                                            .lineLimit(1)
                                                            .foregroundColor(.primary)
                                                    }
                                                    .frame(width: 120)
                                                    .padding(.leading, 5)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.bottom)
                            }
                        }
                    }
                }
                .navigationTitle("Home")
            }
            .onAppear {
                if featuredItems.isEmpty {
                    fetchFeaturedItems()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func fetchFeaturedItems() {
        isLoading = true
        let group = DispatchGroup()
        
        for module in modulesManager.modules {
            group.enter()
            fetchFeaturedItems(for: module) { items in
                DispatchQueue.main.async {
                    featuredItems[module.name] = items
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
    
    private func fetchFeaturedItems(for module: ModuleStruct, completion: @escaping ([SearchResult]) -> Void) {
        let urlString = module.module[0].featured.url
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            
            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)
                let elements = try document.select(module.module[0].featured.documentSelector)
                
                var results: [SearchResult] = []
                for element in elements {
                    let title = try element.select(module.module[0].featured.title).text()
                    let href = try element.select(module.module[0].featured.href).attr("href")
                    var imageURL = try element.select(module.module[0].featured.image.url).attr(module.module[0].featured.image.attribute)
                    
                    if !imageURL.starts(with: "http") {
                        imageURL = "\(module.module[0].details.baseURL)\(imageURL)"
                    }
                    
                    let result = SearchResult(name: title, imageUrl: imageURL, href: href)
                    results.append(result)
                }
                
                completion(results)
            } catch {
                print("Error parsing HTML: \(error)")
                Logger.shared.log("Error parsing HTML: \(error)")
                completion([])
            }
        }.resume()
    }
}
