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
    @Environment(\.presentationMode) var presentationMode
    
    let fullUrl: String
    let title: String
    let episodeNumber: Int
    let onWatchNext: () -> Void
    
    init(urlString: String, fullUrl: String, title: String, episodeNumber: Int, onWatchNext: @escaping () -> Void) {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string")
        }
        _player = State(initialValue: AVPlayer(url: url))
        self.fullUrl = fullUrl
        self.title = title
        self.episodeNumber = episodeNumber
        self.onWatchNext = onWatchNext
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
                            },
                            alignment: .center
                        )
                        .onTapGesture {
                            showControls.toggle()
                        }
                    
                    VStack {
                        Spacer()
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                if duration - currentTime <= duration * 0.06 {
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
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(32)
                                    }
                                    .padding(.trailing, 10)
                                }
                                if showControls {
                                    Menu {
                                        Menu("Playback Speed") {
                                            Button(action: {
                                                player.rate = 0.25
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("0.25", systemImage: "tortoise")
                                            }
                                            Button(action: {
                                                player.rate = 0.5
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("0.5", systemImage: "tortoise.fill")
                                            }
                                            Button(action: {
                                                player.rate = 0.75
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("0.75", systemImage: "hare")
                                            }
                                            Button(action: {
                                                player.rate = 1.0
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("1.0", systemImage: "hare.fill")
                                            }
                                            Button(action: {
                                                player.rate = 1.25
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("1.25", systemImage: "speedometer")
                                            }
                                            Button(action: {
                                                player.rate = 1.5
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("1.5", systemImage: "speedometer")
                                            }
                                            Button(action: {
                                                player.rate = 1.75
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("1.75", systemImage: "speedometer")
                                            }
                                            Button(action: {
                                                player.rate = 2.0
                                                if player.timeControlStatus != .playing {
                                                    player.pause()
                                                }
                                            }) {
                                                Label("2.0", systemImage: "speedometer")
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(.white)
                                            .font(.system(size: 15))
                                    }
                                }
                            }
                            .padding(.trailing, 10)
                            
                            if showControls {
                                MusicProgressSlider(
                                    value: $currentTime,
                                    inRange: 0...duration,
                                    activeFillColor: .white,
                                    fillColor: .white.opacity(0.5),
                                    emptyColor: .white.opacity(0.3),
                                    height: 28,
                                    onEditingChanged: { editing in
                                        if !editing {
                                            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                                        }
                                    }
                                )
                                .frame(height: 45)
                                .padding(.bottom, 10)
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