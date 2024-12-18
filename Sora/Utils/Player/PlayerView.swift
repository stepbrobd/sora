//
//  PlayerView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import UIKit
import AVKit

class VideoPlayerViewController: UIViewController {
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    
    var streamUrl: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let streamUrl = streamUrl, let url = URL(string: streamUrl) else {
            return
        }
        
        player = AVPlayer(url: url)
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        
        if let playerViewController = playerViewController {
            playerViewController.view.frame = self.view.frame
            self.view.addSubview(playerViewController.view)
            self.addChild(playerViewController)
            playerViewController.didMove(toParent: self)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
    }
}
