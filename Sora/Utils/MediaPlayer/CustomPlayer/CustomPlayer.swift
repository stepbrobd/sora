//
//  ContentView.swift
//  test2
//
//  Created by Francesco on 20/12/24.
//

import SwiftUI
import AVKit

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
        // low taper fade the meme is massive
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
    @Environment(\.presentationMode) var presentationMode
    
    let module: ScrapingModule
    let fullUrl: String
    let title: String
    let episodeNumber: Int
    let onWatchNext: () -> Void
    
    init(module: ScrapingModule, urlString: String, fullUrl: String, title: String, episodeNumber: Int, onWatchNext: @escaping () -> Void) {
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
        self.fullUrl = fullUrl
        self.title = title
        self.episodeNumber = episodeNumber
        self.onWatchNext = onWatchNext
        
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
                            addPeriodicTimeObserver(fullURL: fullUrl)
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
                                if duration - currentTime <= duration * 0.10 && currentTime != duration && showWatchNextButton {
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
                                            .font(.system(size: 15))
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
                        player.pause()
                        inactivityTimer?.invalidate()
                        if let timeObserverToken = timeObserverToken {
                            player.removeTimeObserver(timeObserverToken)
                            self.timeObserverToken = nil
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
            currentTime = player.currentTime().seconds
        }
    }
    
    private func addPeriodicTimeObserver(fullURL: String) {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let currentItem = player.currentItem,
                  currentItem.duration.seconds.isFinite else {
                      return
                  }
            
            let currentTime = time.seconds
            let duration = currentItem.duration.seconds
            
            UserDefaults.standard.set(currentTime, forKey: "lastPlayedTime_\(fullURL)")
            UserDefaults.standard.set(duration, forKey: "totalTime_\(fullURL)")
        }
    }
}
