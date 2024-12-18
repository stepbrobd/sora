//
//  VideoPlayerView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import UIKit
import AVKit

class VideoPlayerViewController: UIViewController {
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    var timeObserverToken: Any?
    var streamUrl: String?
    var fullUrl: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let streamUrl = streamUrl, let url = URL(string: streamUrl) else {
            return
        }
        
        player = AVPlayer(url: url)
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        addPeriodicTimeObserver(fullURL: fullUrl)
        
        if let playerViewController = playerViewController {
            playerViewController.view.frame = self.view.frame
            self.view.addSubview(playerViewController.view)
            self.addChild(playerViewController)
            playerViewController.didMove(toParent: self)
        }
        
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
        if lastPlayedTime > 0 {
             let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
             self.player?.seek(to: seekTime) { _ in
                 self.player?.play()
             }
         } else {
             self.player?.play()
         }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
         super.viewDidDisappear(animated)
         if let timeObserverToken = timeObserverToken {
             player?.removeTimeObserver(timeObserverToken)
             self.timeObserverToken = nil
         }
     }
     
     func addPeriodicTimeObserver(fullURL: String) {
         guard let player = self.player else { return }
         
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
