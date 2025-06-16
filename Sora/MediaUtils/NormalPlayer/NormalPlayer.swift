//
//  NormalPlayer.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import AVKit
import GroupActivities

class NormalPlayer: AVPlayerViewController {
    private var originalRate: Float = 1.0
    private var holdGesture: UILongPressGestureRecognizer?
    
    var onSharePlayRequested: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupHoldGesture()
        setupAudioSession()
        setupSharePlayButton()
    }
    
    private func setupSharePlayButton() {
        let sharePlayItem = UIBarButtonItem(
            image: UIImage(systemName: "shareplay"),
            style: .plain,
            target: self,
            action: #selector(sharePlayButtonTapped)
        )
        sharePlayItem.tintColor = .white
        
        if responds(to: Selector(("setCustomControlItems:"))) {
            setValue([sharePlayItem], forKey: "customControlItems")
        }
    }
    
    @objc private func sharePlayButtonTapped() {
        onSharePlayRequested?()
    }
    
    private func setupHoldGesture() {
        holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldGesture(_:)))
        holdGesture?.minimumPressDuration = 0.5
        if let holdGesture = holdGesture {
            view.addGestureRecognizer(holdGesture)
        }
    }
    
    @objc private func handleHoldGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginHoldSpeed()
        case .ended, .cancelled:
            endHoldSpeed()
        default:
            break
        }
    }
    
    private func beginHoldSpeed() {
        guard let player = player else { return }
        originalRate = player.rate
        let holdSpeed = UserDefaults.standard.float(forKey: "holdSpeedPlayer")
        player.rate = holdSpeed > 0 ? holdSpeed : 2.0
    }
    
    private func endHoldSpeed() {
        player?.rate = originalRate
    }

    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try audioSession.setActive(true)
            
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            Logger.shared.log("Didn't set up AVAudioSession: \(error)", type: "Debug")
        }
    }
}
