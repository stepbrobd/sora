//
//  MediaInfoView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct MediaItem: Identifiable {
    let id = UUID()
    let description: String
    let aliases: String
    let airdate: String
}

struct MediaInfoView: View {
    let title: String
    let imageUrl: String
    let href: String
    let module: ScrapingModule
    
    @State var aliases: String = ""
    @State var synopsis: String = ""
    @State var airdate: String = ""
    @State var genres: [String] = []
    @State var episodes: [String] = []
    
    @State var isLoading: Bool = true
    @State var showFullSynopsis: Bool = false
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    
    @ObservedObject var jsController = JSController()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 10) {
                            KFImage(URL(string: imageUrl))
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                                .cornerRadius(10)
                                .frame(width: 150, height: 225)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.system(size: 17))
                                    .fontWeight(.bold)
                                
                                if !aliases.isEmpty && aliases != title {
                                    Text(aliases)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(alignment: .center, spacing: 12) {
                                    Text(module.metadata.sourceName)
                                        .font(.system(size: 13))
                                        .padding(4)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.4)))
                                    
                                    Button(action: {
                                    }) {
                                        Image(systemName: "ellipsis.circle")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    }
                                    
                                    Button(action: {
                                    }) {
                                        Image(systemName: "safari")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                        }
                        
                        if !synopsis.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .center) {
                                    Text("Synopsis")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showFullSynopsis.toggle()
                                    }) {
                                        Text(showFullSynopsis ? "Less" : "More")
                                            .font(.system(size: 14))
                                    }
                                }
                                
                                Text(synopsis)
                                    .lineLimit(showFullSynopsis ? nil : 4)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        HStack {
                            Button(action: {
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.primary)
                                    Text("Start Watching")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                            }) {
                                Image(systemName: "bookmark")
                                    .resizable()
                                    .frame(width: 20, height: 27)
                            }
                        }
                    }
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarTitle(title)
                    .navigationViewStyle(StackNavigationViewStyle())
                }
            }
        }
        .onAppear {
            jsController.fetchDetails(url: href) { items in
                if let item = items.first {
                    print("Fetched item: \(item)")
                    self.synopsis = item.description
                    self.aliases = item.aliases
                    self.airdate = item.airdate
                }
                self.isLoading = false
            }
        }
    }
}
