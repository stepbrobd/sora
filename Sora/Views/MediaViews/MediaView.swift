//
//  MediaView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import AVKit
import SwiftUI
import Kingfisher
import SafariServices

struct MediaView: View {
    let module: ModuleStruct
    let item: ItemResult
    
    @State var aliases: String = ""
    @State var synopsis: String = ""
    @State var airdate: String = ""
    @State var stars: String = ""
    @State var episodes: [String] = []
    @State var isLoading: Bool = true
    @State var showFullSynopsis: Bool = false
    @State var itemID: Int?
    @State private var selectedEpisode: String = ""
    @State private var selectedEpisodeNumber: Int = 0
    @State private var episodeRange: ClosedRange<Int> = 0...99
    @State private var selectedRange: String = "1-100"
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @StateObject private var libraryManager = LibraryManager.shared
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 10) {
                            KFImage(URL(string: item.imageUrl))
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                                .cornerRadius(10)
                                .frame(width: 150, height: 225)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.system(size: 17))
                                    .fontWeight(.bold)
                                
                                if !aliases.isEmpty && aliases != item.name {
                                    Text(aliases)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(alignment: .center, spacing: 12) {
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
                                startWatchingFirstUnfinishedEpisode()
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
                                if isItemInLibrary() {
                                    removeFromLibrary()
                                } else {
                                    addToLibrary()
                                }
                            }) {
                                Image(systemName: isItemInLibrary() ? "bookmark.fill" : "bookmark")
                                    .resizable()
                                    .frame(width: 20, height: 27)
                            }
                        }
                        
                        if !episodes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Episodes")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    if episodes.count > 100 {
                                        Menu {
                                            ForEach(0..<(episodes.count / 100) + 1, id: \.self) { index in
                                                let start = index * 100 + 1
                                                let end = min((index + 1) * 100, episodes.count)
                                                Button(action: {
                                                    episodeRange = (start - 1)...(end - 1)
                                                    selectedRange = "\(start)-\(end)"
                                                }) {
                                                    Text("\(start)-\(end)")
                                                }
                                            }
                                        } label: {
                                            Text(selectedRange)
                                                .font(.system(size: 14))
                                        }
                                    }
                                }
                                
                                ForEach(episodeRange, id: \.self) { index in
                                    if index < episodes.count {
                                        let episodeURL = episodes[index].hasPrefix("https") ? episodes[index] : "\(module.module[0].details.baseURL)\(episodes[index])"
                                        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episodeURL)")
                                        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episodeURL)")
                                        let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                        
                                        EpisodeCell(episode: episodes[index], episodeID: index, imageUrl: item.imageUrl, progress: progress, itemID: itemID ?? 0)
                                            .onTapGesture {
                                                selectedEpisode = episodes[index]
                                                selectedEpisodeNumber = index + 1
                                                fetchEpisodeStream(urlString: episodeURL)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarTitle(item.name)
                    .navigationViewStyle(StackNavigationViewStyle())
                }
            }
        }
        .onAppear {
            fetchItemDetails()
            fetchItemID(byTitle: item.name) { result in
                switch result {
                case .success(let id):
                    itemID = id
                    Logger.shared.log("Fetched Item ID: \(id)")
                case .failure(let error):
                    print("Failed to fetch Item ID: \(error)")
                    Logger.shared.log("Failed to fetch Item ID: \(error)")
                }
            }
        }
    }
    
    func isItemInLibrary() -> Bool {
        return libraryManager.libraryItems.contains(where: { $0.url == item.href })
    }
    
    func addToLibrary() {
        let libraryItem = LibraryItem(
            anilistID: itemID ?? 0,
            title: item.name,
            image: item.imageUrl,
            url: item.href,
            module: module,
            dateAdded: Date()
        )
        libraryManager.addToLibrary(libraryItem)
    }
    
    func removeFromLibrary() {
        if let libraryItem = libraryManager.libraryItems.first(where: { $0.url == item.href }) {
            libraryManager.removeFromLibrary(libraryItem)
        }
    }
    
    private func startWatchingFirstUnfinishedEpisode() {
        for (index, episode) in episodes.enumerated() {
            let episodeURL = episode.hasPrefix("https") ? episode : "\(module.module[0].details.baseURL)\(episode)"
            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episodeURL)")
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episodeURL)")
            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
            
            if progress < 0.90 {
                selectedEpisode = episode
                selectedEpisodeNumber = index + 1
                fetchEpisodeStream(urlString: episodeURL)
                break
            }
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
        } else if externalPlayer == "Sora" {
            DispatchQueue.main.async {
                let customMediaPlayer = CustomMediaPlayer(
                    module: module,
                    urlString: streamUrl,
                    fullUrl: fullURL,
                    title: item.name,
                    episodeNumber: selectedEpisodeNumber,
                    onWatchNext: {
                        selectNextEpisode()
                    }
                )
                let hostingController = UIHostingController(rootView: customMediaPlayer)
                hostingController.modalPresentationStyle = .fullScreen
                Logger.shared.log("Opening custom media player with url: \(streamUrl)")
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(hostingController, animated: true, completion: nil)
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            let videoPlayerViewController = VideoPlayerViewController(module: module)
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
    
    private func selectNextEpisode() {
        guard let currentEpisodeIndex = episodes.firstIndex(of: selectedEpisode) else { return }
        let nextEpisodeIndex = currentEpisodeIndex + 1
        if nextEpisodeIndex < episodes.count {
            selectedEpisode = episodes[nextEpisodeIndex]
            selectedEpisodeNumber = nextEpisodeIndex + 1
            let nextEpisodeURL = "\(module.module[0].details.baseURL)\(episodes[nextEpisodeIndex])"
            fetchEpisodeStream(urlString: nextEpisodeURL)
        }
    }
    
    private func openSafariViewController(with urlString: String) {
        guard let url = URL(string: item.href.hasPrefix("https") ? item.href : "\(module.module[0].details.baseURL.hasSuffix("/") ? module.module[0].details.baseURL : "\(module.module[0].details.baseURL)/")\(item.href.hasPrefix("/") ? String(item.href.dropFirst()) : item.href)") else {
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
    
    private func fetchItemID(byTitle title: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let query = """
        query {
            Media(search: "\(title)", type: ANIME) {
                id
            }
        }
        """
        
        guard let url = URL(string: "https://graphql.anilist.co") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.custom.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let media = data["Media"] as? [String: Any],
                   let id = media["id"] as? Int {
                    completion(.success(id))
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
