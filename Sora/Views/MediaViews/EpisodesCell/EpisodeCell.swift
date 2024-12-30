//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct EpisodeCell: View {
    let episode: String
    let episodeID: Int
    let imageUrl: String
    let progress: Double
    let itemID: Int
    
    @State private var episodeTitle: String = ""
    @State private var episodeImageUrl: String = ""
    @State private var isLoading: Bool = true
    
    var body: some View {
        HStack {
            ZStack {
                KFImage(URL(string: episodeImageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : episodeImageUrl))
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100, height: 56)
                    .cornerRadius(8)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            
            VStack(alignment: .leading) {
                Text("Episode \(episodeID + 1)")
                    .font(.system(size: 15))
                if !episodeTitle.isEmpty {
                    Text(episodeTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            CircularProgressBar(progress: progress)
                .frame(width: 40, height: 40)
        }
        .onAppear {
            fetchEpisodeDetails()
        }
    }
    
    func fetchEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch episode details: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeID + 1)"] as? [String: Any],
                      let title = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                          print("Invalid response format")
                          DispatchQueue.main.async {
                              self.isLoading = false
                          }
                          return
                      }
                
                DispatchQueue.main.async {
                    self.episodeTitle = title["en"] ?? ""
                    self.episodeImageUrl = image
                    self.isLoading = false
                }
            } catch {
                print("Failed to parse JSON: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
