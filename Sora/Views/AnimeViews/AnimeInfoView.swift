//
//  AnimeDetailsView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import AVKit
import SwiftUI
import Kingfisher
import SafariServices

struct AnimeInfoView: View {
    let module: ModuleStruct
    let anime: SearchResult
    
    @State var aliases: String = ""
    @State var synopsis: String = ""
    @State var airdate: String = ""
    @State var stars: String = ""
    @State var episodes: [String] = []
    @State var isLoading: Bool = true
    @State var showFullSynopsis: Bool = false
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 10) {
                            KFImage(URL(string: anime.imageUrl))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 190)
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(anime.name)
                                    .font(.system(size: 17))
                                    .fontWeight(.bold)
                                
                                if !aliases.isEmpty && aliases != anime.name {
                                    Text(aliases)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Text(module.name)
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
                                        openSafariViewController(with: "\(module.module[0].details.baseURL)")
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
                        
                        if !episodes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Episodes")
                                    .font(.system(size: 18))
                                    .fontWeight(.bold)
                                
                                ForEach(episodes.indices, id: \.self) { index in
                                    let episodeURL = "\(module.module[0].details.baseURL)\(episodes[index])"
                                    let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episodeURL)")
                                    let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episodeURL)")
                                    let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                    
                                    EpisodeCell(episode: episodes[index], episodeID: index, imageUrl: anime.imageUrl, progress: progress)
                                        .onTapGesture {
                                            fetchEpisodeStream(urlString: episodeURL)
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            fetchAnimeDetails()
        }
    }
    
    func playStream(urlString: String?, fullURL: String) {
        guard let streamUrl = urlString else { return }
        
        if externalPlayer == "Infuse" || externalPlayer == "VLC" || externalPlayer == "OutPlayer" || externalPlayer == "nPlayer" {
            var scheme: String
            switch externalPlayer {
            case "Infuse":
                scheme = "infuse://x-callback-url/play?url="
            case "VLC":
                scheme = "vlc://"
            case "OutPlayer":
                scheme = "outplayer://"
            case "nPlayer":
                scheme = "nplayer-"
            default:
                scheme = ""
            }
            openInExternalPlayer(scheme: scheme, url: streamUrl)
            Logger.shared.log("Opening external app with scheme: \(scheme)")
            return
        }
        
        DispatchQueue.main.async {
            let videoPlayerViewController = VideoPlayerViewController()
            videoPlayerViewController.streamUrl = streamUrl
            videoPlayerViewController.fullUrl = fullURL
            videoPlayerViewController.modalPresentationStyle = .fullScreen
            Logger.shared.log("Opening video player with url: \(streamUrl)")
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(videoPlayerViewController, animated: true, completion: nil)
            }
        }
    }
    
    private func openSafariViewController(with urlString: String) {
        guard let url = URL(string: anime.href.hasPrefix("http") ? anime.href : "\(module.module[0].details.baseURL)\(anime.href)") else {
            Logger.shared.log("Unable to open the webpage")
            return
        }
        let safariViewController = SFSafariViewController(url: url)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(safariViewController, animated: true, completion: nil)
        }
    }
    
    private func openInExternalPlayer(scheme: String, url: String) {
        guard let streamUrl = URL(string: "\(scheme)\(url)") else {
            Logger.shared.log("Unable to open the stream: '\(scheme)\(url)'")
            return
        }
        UIApplication.shared.open(streamUrl, options: [:], completionHandler: nil)
        Logger.shared.log("Unable to open the stream: 'streamUrl'")
    }
}
