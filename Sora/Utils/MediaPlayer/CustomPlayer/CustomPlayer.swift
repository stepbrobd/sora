//
//  ContentView.swift
//  test2
//
//  Created by Francesco on 20/12/24.
//

import AVKit
import SwiftUI

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = NormalPlayer()
        controller.player = player
        controller.showsPlaybackControls = false
        player.play()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // yes? Like the plural of the famous american rapper ye? -IBHRAD
        // low taper fade the meme is massive -cranci
    }
}

struct CustomMediaPlayer: View {
    @State private var player: AVPlayer
    @State private var isPlaying = true
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 0.0
    @State private var showControls = false
    @State private var inactivityTimer: Timer?
    @State private var timeObserverToken: Any?
    @State private var isVideoLoaded = false
    @State private var showWatchNextButton = true
    @ObservedObject private var subtitlesLoader = VTTSubtitlesLoader()
    
    @AppStorage("subtitleForegroundColor") private var subtitleForegroundColor: String = "white"
    @AppStorage("subtitleBackgroundEnabled") private var subtitleBackgroundEnabled: Bool = true
    @AppStorage("subtitleFontSize") private var subtitleFontSize: Double = 20.0
    @AppStorage("subtitleShadowRadius") private var subtitleShadowRadius: Double = 1.0
    
    private var subtitleFGColor: Color {
        switch subtitleForegroundColor {
        case "white": return Color.white
        case "yellow": return Color.yellow
        case "green": return Color.green
        case "purple": return Color.purple
        case "blue": return Color.blue
        case "red": return Color.red
        default: return Color.white
        }
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    let module: ScrapingModule
    let streamURL: String
    let fullUrl: String
    let title: String
    let episodeNumber: Int
    let episodeImageUrl: String
    let subtitlesURL: String?
    let onWatchNext: () -> Void
    
    init(module: ScrapingModule, urlString: String, fullUrl: String, title: String, episodeNumber: Int, onWatchNext: @escaping () -> Void, subtitlesURL: String?, episodeImageUrl: String) {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string")
        }
        
        var request = URLRequest(url: url)
        if urlString.contains("ascdn") {
            request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        }
        
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        _player = State(initialValue: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
        
        self.module = module
        self.streamURL = urlString
        self.fullUrl = fullUrl
        self.title = title
        self.episodeNumber = episodeNumber
        self.episodeImageUrl = episodeImageUrl
        self.onWatchNext = onWatchNext
        self.subtitlesURL = subtitlesURL ?? ""
        
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
        if lastPlayedTime > 0 {
            let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
            self._player.wrappedValue.seek(to: seekTime)
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    CustomVideoPlayer(player: player)
                        .onAppear {
                            player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { time in
                                currentTime = time.seconds
                                if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite && !itemDuration.isNaN {
                                    duration = itemDuration
                                    isVideoLoaded = true
                                }
                            }
                            startUpdatingCurrentTime()
                            setInitialPlayerRate()
                            addPeriodicTimeObserver(fullURL: fullUrl)
                            
                            if let url = subtitlesURL, !url.isEmpty {
                                subtitlesLoader.load(from: url)
                            }
                        }
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            Group {
                                if showControls {
                                    Color.black.opacity(0.5)
                                        .edgesIgnoringSafeArea(.all)
                                    HStack(spacing: 20) {
                                        Button(action: {
                                            currentTime = max(currentTime - 10, 0)
                                            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                                        }) {
                                            Image(systemName: "gobackward.10")
                                        }
                                        .foregroundColor(.white)
                                        .font(.system(size: 25))
                                        .contentShape(Rectangle())
                                        .frame(width: 60, height: 60)
                                        
                                        Button(action: {
                                            if isPlaying {
                                                player.pause()
                                            } else {
                                                player.play()
                                            }
                                            isPlaying.toggle()
                                        }) {
                                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        }
                                        .foregroundColor(.white)
                                        .font(.system(size: 45))
                                        .contentShape(Rectangle())
                                        .frame(width: 80, height: 80)
                                        
                                        Button(action: {
                                            currentTime = min(currentTime + 10, duration)
                                            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                                        }) {
                                            Image(systemName: "goforward.10")
                                        }
                                        .foregroundColor(.white)
                                        .font(.system(size: 25))
                                        .contentShape(Rectangle())
                                        .frame(width: 60, height: 60)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: showControls),
                            alignment: .center
                        )
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                    
                    VStack {
                        Spacer()
                        if let currentCue = subtitlesLoader.cues.first(where: { currentTime >= $0.startTime && currentTime <= $0.endTime }) {
                            Text(currentCue.text.strippedHTML)
                                .font(.system(size: CGFloat(subtitleFontSize)))
                                .multilineTextAlignment(.center)
                                .padding(8)
                                .background(subtitleBackgroundEnabled ? Color.black.opacity(0.6) : Color.clear)
                                .foregroundColor(subtitleFGColor)
                                .cornerRadius(5)
                                .shadow(color: Color.black, radius: CGFloat(subtitleShadowRadius))
                                .padding(.bottom, showControls ? 80 : 0)
                        }
                    }
                    
                    VStack {
                        Spacer()
                        VStack {
                            HStack(alignment: .bottom) {
                                if showControls {
                                    VStack(alignment: .leading) {
                                        Text("Episode \(episodeNumber)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        Text(title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 32)
                                }
                                Spacer()
                                if duration - currentTime <= duration * 0.10 && currentTime != duration && showWatchNextButton && duration != 0 {
                                    Button(action: {
                                        player.pause()
                                        presentationMode.wrappedValue.dismiss()
                                        onWatchNext()
                                    }) {
                                        HStack {
                                            Image(systemName: "forward.fill")
                                                .foregroundColor(Color.black)
                                            Text("Watch Next")
                                                .font(.headline)
                                                .foregroundColor(Color.black)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(32)
                                    }
                                    .padding(.trailing, 10)
                                    .onAppear {
                                        if UserDefaults.standard.bool(forKey: "hideNextButton") {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                                showWatchNextButton = false
                                            }
                                        }
                                    }
                                }
                                if showControls {
                                    Menu {
                                        Menu("Playback Speed") {
                                            ForEach([0.5, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                                                Button(action: {
                                                    player.rate = Float(speed)
                                                    if player.timeControlStatus != .playing {
                                                        player.pause()
                                                    }
                                                }) {
                                                    Text("\(speed, specifier: "%.2f")")
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    }
                                    if let url = subtitlesURL, !url.isEmpty {
                                        Menu {
                                            Menu("Subtitle Foreground Color") {
                                                Button("White") { subtitleForegroundColor = "white" }
                                                Button("Yellow") { subtitleForegroundColor = "yellow" }
                                                Button("Green") { subtitleForegroundColor = "green" }
                                                Button("Blue") { subtitleForegroundColor = "blue" }
                                                Button("Red") { subtitleForegroundColor = "red" }
                                                Button("Purple") { subtitleForegroundColor = "purple" }
                                            }
                                            Menu("Subtitle Font Size") {
                                                Button("16") { subtitleFontSize = 16 }
                                                Button("18") { subtitleFontSize = 18 }
                                                Button("20") { subtitleFontSize = 20 }
                                                Button("22") { subtitleFontSize = 22 }
                                                Button("24") { subtitleFontSize = 24 }
                                            }
                                            Menu("Subtitle Shadow Intensity") {
                                                Button("None") { subtitleShadowRadius = 0 }
                                                Button("Low") { subtitleShadowRadius = 1 }
                                                Button("Medium") { subtitleShadowRadius = 3 }
                                                Button("High") { subtitleShadowRadius = 6 }
                                            }
                                            Button(action: {
                                                subtitleBackgroundEnabled.toggle()
                                            }) {
                                                Text(subtitleBackgroundEnabled ? "Disable Background" : "Enable Background")
                                            }
                                        } label: {
                                            Image(systemName: "text.bubble")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                        }
                                    }
                                }
                            }
                            .padding(.trailing, 32)
                            
                            if showControls {
                                MusicProgressSlider(
                                    value: $currentTime,
                                    inRange: 0...duration,
                                    activeFillColor: .white,
                                    fillColor: .white.opacity(0.5),
                                    emptyColor: .white.opacity(0.3),
                                    height: 28,
                                    onEditingChanged: { editing in
                                        if !editing && isVideoLoaded {
                                            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                                        }
                                    }
                                )
                                    .padding(.horizontal, 32)
                                    .padding(.bottom, 6)
                                    .disabled(!isVideoLoaded)
                            }
                        }
                    }
                    .onAppear {
                        startUpdatingCurrentTime()
                    }
                    .onDisappear {
                        UserDefaults.standard.set(player.rate, forKey: "lastPlaybackSpeed")
                        player.pause()
                        inactivityTimer?.invalidate()
                        if let timeObserverToken = timeObserverToken {
                            player.removeTimeObserver(timeObserverToken)
                            self.timeObserverToken = nil
                        }
                        
                        if let currentItem = player.currentItem, currentItem.duration.seconds > 0 {
                            let currentTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
                            let duration = currentItem.duration.seconds
                            let progress = currentTime / duration
                            let item = ContinueWatchingItem(
                                id: UUID(),
                                imageUrl: episodeImageUrl,
                                episodeNumber: episodeNumber,
                                mediaTitle: title,
                                progress: progress,
                                streamUrl: streamURL,
                                fullUrl: fullUrl,
                                subtitles: subtitlesURL,
                                module: module
                            )
                            ContinueWatchingManager.shared.save(item: item)
                        }
                    }
                }
            }
            VStack {
                if showControls {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                        .frame(width: 60, height: 60)
                        .contentShape(Rectangle())
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func startUpdatingCurrentTime() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let newTime = player.currentTime().seconds
            DispatchQueue.main.async {
                self.currentTime = newTime
            }
        }
    }
    
    private func setInitialPlayerRate() {
        if UserDefaults.standard.bool(forKey: "rememberPlaySpeed") {
            let lastPlayedSpeed = UserDefaults.standard.float(forKey: "lastPlaybackSpeed")
            player.rate = lastPlayedSpeed > 0 ? lastPlayedSpeed : 1.0
        }
    }
    
    private func addPeriodicTimeObserver(fullURL: String) {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let currentItem = player.currentItem,
                  currentItem.duration.seconds.isFinite else { return }
            DispatchQueue.main.async {
                let currentTimeValue = time.seconds
                self.currentTime = currentTimeValue
                let duration = currentItem.duration.seconds
                UserDefaults.standard.set(currentTimeValue, forKey: "lastPlayedTime_\(fullURL)")
                UserDefaults.standard.set(duration, forKey: "totalTime_\(fullURL)")
            }
        }
    }
}
