//
//  SubtitleManager.swift
//  Sora
//
//  Created by Francesco on 10/06/25.
//

import UIKit
import Foundation
import AVFoundation

class SubtitleManager {
    static let shared = SubtitleManager()
    private let subtitleLoader = VTTSubtitlesLoader()
    
    private init() {}
    
    func loadSubtitles(from url: URL) async throws -> [SubtitleCue] {
        return await withCheckedContinuation { continuation in
            subtitleLoader.load(from: url.absoluteString)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume(returning: self.subtitleLoader.cues)
            }
        }
    }
    
    func createSubtitleOverlay(for cues: [SubtitleCue], player: AVPlayer) -> SubtitleOverlayView {
        let overlay = SubtitleOverlayView()
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let currentTime = time.seconds
            let currentCue = cues.first { cue in
                currentTime >= cue.startTime && currentTime <= cue.endTime
            }
            overlay.update(with: currentCue?.text ?? "")
        }
        
        return overlay
    }
}

class SubtitleOverlayView: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func update(with text: String) {
        label.text = text
    }
}
