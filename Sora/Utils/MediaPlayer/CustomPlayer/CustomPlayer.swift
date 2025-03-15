//
//  CustomPlayer.swift
//  test2
//
//  Created by Francesco on 23/02/25.
//

import UIKit
import AVKit
import SwiftUI
import AVFoundation

class SliderViewModel: ObservableObject {
    @Published var sliderValue: Double = 0.0
}

class CustomMediaPlayerViewController: UIViewController {
    let module: ScrapingModule
    let streamURL: String
    let fullUrl: String
    let titleText: String
    let episodeNumber: Int
    let episodeImageUrl: String
    let subtitlesURL: String?
    let onWatchNext: () -> Void
    
    var player: AVPlayer!
    var timeObserverToken: Any?
    var inactivityTimer: Timer?
    var updateTimer: Timer?
    
    var isPlaying = true
    var currentTimeVal: Double = 0.0
    var duration: Double = 0.0
    var isVideoLoaded = false
    var showWatchNextButton = true
    
    var subtitleForegroundColor: String = "white"
    var subtitleBackgroundEnabled: Bool = true
    var subtitleFontSize: Double = 20.0
    var subtitleShadowRadius: Double = 1.0
    var subtitlesLoader = VTTSubtitlesLoader()
    
    var playerViewController: AVPlayerViewController!
    var controlsContainerView: UIView!
    var playPauseButton: UIImageView!
    var backwardButton: UIImageView!
    var forwardButton: UIImageView!
    var subtitleLabel: UILabel!
    var dismissButton: UIButton!
    var menuButton: UIButton!
    var watchNextButton: UIButton!
    var blackCoverView: UIView!
    var speedButton: UIButton!
    var skip85Button: UIButton!
    
    var sliderHostingController: UIHostingController<MusicProgressSlider<Double>>?
    var sliderViewModel = SliderViewModel()
    var isSliderEditing = false
    
    var watchNextButtonNormalConstraints: [NSLayoutConstraint] = []
    var watchNextButtonControlsConstraints: [NSLayoutConstraint] = []
    var isControlsVisible = false
    
    var subtitleBottomConstraint: NSLayoutConstraint?
    
    var subtitleBottomPadding: CGFloat = 10.0 {
        didSet {
            updateSubtitleLabelConstraints()
        }
    }
    
    init(module: ScrapingModule,
         urlString: String,
         fullUrl: String,
         title: String,
         episodeNumber: Int,
         onWatchNext: @escaping () -> Void,
         subtitlesURL: String?,
         episodeImageUrl: String) {
        
        self.module = module
        self.streamURL = urlString
        self.fullUrl = fullUrl
        self.titleText = title
        self.episodeNumber = episodeNumber
        self.episodeImageUrl = episodeImageUrl
        self.onWatchNext = onWatchNext
        self.subtitlesURL = subtitlesURL
        
        super.init(nibName: nil, bundle: nil)
        
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string")
        }
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
        if lastPlayedTime > 0 {
            let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
            self.player.seek(to: seekTime)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Load persistent subtitle settings on launch
        loadSubtitleSettings()
        
        setupPlayerViewController()
        setupControls()
        setupSubtitleLabel()
        setupDismissButton()
        setupMenuButton()
        setupSpeedButton()
        setupWatchNextButton()
        setupSkip85Button()
        addTimeObserver()
        startUpdateTimer()
        setupAudioSession()
        
        player.play()
        
        if let url = subtitlesURL, !url.isEmpty {
            subtitlesLoader.load(from: url)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
        updateTimer?.invalidate()
        inactivityTimer?.invalidate()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        UserDefaults.standard.set(player.rate, forKey: "lastPlaybackSpeed")
        if let currentItem = player.currentItem, currentItem.duration.seconds > 0 {
            let progress = currentTimeVal / currentItem.duration.seconds
            let item = ContinueWatchingItem(
                id: UUID(),
                imageUrl: episodeImageUrl,
                episodeNumber: episodeNumber,
                mediaTitle: titleText,
                progress: progress,
                streamUrl: streamURL,
                fullUrl: fullUrl,
                subtitles: subtitlesURL,
                module: module
            )
            ContinueWatchingManager.shared.save(item: item)
        }
    }
    
    func setupPlayerViewController() {
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        playerViewController.didMove(toParent: self)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tapGesture)
    }
    
    func setupControls() {
        controlsContainerView = UIView()
        controlsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        view.addSubview(controlsContainerView)
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlsContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            controlsContainerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        blackCoverView = UIView()
        blackCoverView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        blackCoverView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.insertSubview(blackCoverView, at: 0)
        NSLayoutConstraint.activate([
            blackCoverView.topAnchor.constraint(equalTo: view.topAnchor),
            blackCoverView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blackCoverView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blackCoverView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        backwardButton = UIImageView(image: UIImage(systemName: "gobackward.10"))
        backwardButton.tintColor = .white
        backwardButton.contentMode = .scaleAspectFit
        backwardButton.isUserInteractionEnabled = true
        let backwardTap = UITapGestureRecognizer(target: self, action: #selector(seekBackward))
        backwardButton.addGestureRecognizer(backwardTap)
        controlsContainerView.addSubview(backwardButton)
        backwardButton.translatesAutoresizingMaskIntoConstraints = false
        
        playPauseButton = UIImageView(image: UIImage(systemName: "pause.fill"))
        playPauseButton.tintColor = .white
        playPauseButton.contentMode = .scaleAspectFit
        playPauseButton.isUserInteractionEnabled = true
        let playPauseTap = UITapGestureRecognizer(target: self, action: #selector(togglePlayPause))
        playPauseButton.addGestureRecognizer(playPauseTap)
        controlsContainerView.addSubview(playPauseButton)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        
        forwardButton = UIImageView(image: UIImage(systemName: "goforward.10"))
        forwardButton.tintColor = .white
        forwardButton.contentMode = .scaleAspectFit
        forwardButton.isUserInteractionEnabled = true
        let forwardTap = UITapGestureRecognizer(target: self, action: #selector(seekForward))
        forwardButton.addGestureRecognizer(forwardTap)
        controlsContainerView.addSubview(forwardButton)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        
        let sliderView = MusicProgressSlider(
            value: Binding(get: { self.sliderViewModel.sliderValue },
                           set: { self.sliderViewModel.sliderValue = $0 }),
            inRange: 0...(duration > 0 ? duration : 1.0),
            activeFillColor: .white,
            fillColor: .white.opacity(0.5),
            emptyColor: .white.opacity(0.3),
            height: 30,
            onEditingChanged: { editing in
                self.isSliderEditing = editing
                if !editing {
                    self.player.seek(to: CMTime(seconds: self.sliderViewModel.sliderValue, preferredTimescale: 600))
                }
            }
        )
        
        sliderHostingController = UIHostingController(rootView: sliderView)
        guard let sliderHostView = sliderHostingController?.view else { return }
        sliderHostView.backgroundColor = .clear
        sliderHostView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.addSubview(sliderHostView)
        
        NSLayoutConstraint.activate([
            sliderHostView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 26),
            sliderHostView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -26),
            sliderHostView.bottomAnchor.constraint(equalTo: controlsContainerView.bottomAnchor, constant: -20),
            sliderHostView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: controlsContainerView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: controlsContainerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            backwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            backwardButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -50),
            backwardButton.widthAnchor.constraint(equalToConstant: 40),
            backwardButton.heightAnchor.constraint(equalToConstant: 40),
            
            forwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            forwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 50),
            forwardButton.widthAnchor.constraint(equalToConstant: 40),
            forwardButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupSubtitleLabel() {
        subtitleLabel = UILabel()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.font = UIFont.systemFont(ofSize: CGFloat(subtitleFontSize))
        updateSubtitleLabelAppearance()
        view.addSubview(subtitleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleBottomConstraint = subtitleLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -subtitleBottomPadding)
        
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleBottomConstraint!,
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 36),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -36)
        ])
    }
    
    func updateSubtitleLabelConstraints() {
        subtitleBottomConstraint?.constant = -subtitleBottomPadding
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func setupDismissButton() {
        dismissButton = UIButton(type: .system)
        dismissButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        dismissButton.tintColor = .white
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        controlsContainerView.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 16),
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupMenuButton() {
        menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "text.bubble"), for: .normal)
        menuButton.tintColor = .white
        
        if let subtitlesURL = subtitlesURL, !subtitlesURL.isEmpty {
            menuButton.showsMenuAsPrimaryAction = true
            menuButton.menu = buildOptionsMenu()
        } else {
            menuButton.isHidden = true
        }
        
        controlsContainerView.addSubview(menuButton)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        guard let sliderView = sliderHostingController?.view else { return }
        NSLayoutConstraint.activate([
            menuButton.bottomAnchor.constraint(equalTo: sliderView.topAnchor),
            menuButton.trailingAnchor.constraint(equalTo: sliderView.trailingAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupSpeedButton() {
        speedButton = UIButton(type: .system)
        speedButton.setImage(UIImage(systemName: "speedometer"), for: .normal)
        speedButton.tintColor = .white
        
        speedButton.showsMenuAsPrimaryAction = true
        speedButton.menu = speedChangerMenu()
        
        controlsContainerView.addSubview(speedButton)
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            speedButton.bottomAnchor.constraint(equalTo: controlsContainerView.bottomAnchor, constant: -50),
            speedButton.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor),
            speedButton.widthAnchor.constraint(equalToConstant: 40),
            speedButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupWatchNextButton() {
        watchNextButton = UIButton(type: .system)
        watchNextButton.setTitle("Watch Next", for: .normal)
        watchNextButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        watchNextButton.tintColor = .black
        watchNextButton.backgroundColor = .white
        watchNextButton.layer.cornerRadius = 25
        watchNextButton.setTitleColor(.black, for: .normal)
        watchNextButton.addTarget(self, action: #selector(watchNextTapped), for: .touchUpInside)
        watchNextButton.isHidden = true
        watchNextButton.alpha = 0.8
        
        view.addSubview(watchNextButton)
        watchNextButton.translatesAutoresizingMaskIntoConstraints = false
        
        watchNextButtonNormalConstraints = [
            watchNextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            watchNextButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            watchNextButton.heightAnchor.constraint(equalToConstant: 50),
            watchNextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ]
        
        watchNextButtonControlsConstraints = [
            watchNextButton.trailingAnchor.constraint(equalTo: speedButton.leadingAnchor),
            watchNextButton.bottomAnchor.constraint(equalTo: speedButton.bottomAnchor, constant: -5),
            watchNextButton.heightAnchor.constraint(equalToConstant: 50),
            watchNextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ]
        
        NSLayoutConstraint.activate(watchNextButtonControlsConstraints)
    }
    
    func setupSkip85Button() {
        skip85Button = UIButton(type: .system)
        skip85Button.setTitle("Skip 85s", for: .normal)
        skip85Button.setImage(UIImage(systemName: "goforward"), for: .normal)
        skip85Button.tintColor = .black
        skip85Button.backgroundColor = .white
        skip85Button.layer.cornerRadius = 25
        skip85Button.setTitleColor(.black, for: .normal)
        skip85Button.alpha = 0.8
        skip85Button.addTarget(self, action: #selector(skip85Tapped), for: .touchUpInside)

        controlsContainerView.addSubview(skip85Button)
        skip85Button.translatesAutoresizingMaskIntoConstraints = false

        if UIDevice.current.userInterfaceIdiom == .pad {
            NSLayoutConstraint.activate([
                skip85Button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
                skip85Button.bottomAnchor.constraint(equalTo: watchNextButton.bottomAnchor),
                skip85Button.heightAnchor.constraint(equalTo: watchNextButton.heightAnchor),
                skip85Button.widthAnchor.constraint(equalTo: watchNextButton.widthAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                skip85Button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
                skip85Button.bottomAnchor.constraint(equalTo: watchNextButton.bottomAnchor),
                skip85Button.heightAnchor.constraint(equalTo: watchNextButton.heightAnchor),
                skip85Button.widthAnchor.constraint(equalTo: watchNextButton.widthAnchor)
            ])
        }
    }

    
    func updateSubtitleLabelAppearance() {
        subtitleLabel.font = UIFont.systemFont(ofSize: CGFloat(subtitleFontSize))
        subtitleLabel.textColor = subtitleUIColor()
        subtitleLabel.backgroundColor = subtitleBackgroundEnabled ? UIColor.black.withAlphaComponent(0.6) : .clear
        subtitleLabel.layer.cornerRadius = 5
        subtitleLabel.clipsToBounds = true
        subtitleLabel.layer.shadowColor = UIColor.black.cgColor
        subtitleLabel.layer.shadowRadius = CGFloat(subtitleShadowRadius)
        subtitleLabel.layer.shadowOpacity = 1.0
        subtitleLabel.layer.shadowOffset = CGSize.zero
    }
    
    func subtitleUIColor() -> UIColor {
        switch subtitleForegroundColor {
        case "white": return .white
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        case "blue": return .blue
        case "red": return .red
        default: return .white
        }
    }
    
    func addTimeObserver() {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let currentItem = self.player.currentItem,
                  currentItem.duration.seconds.isFinite else { return }
            self.currentTimeVal = time.seconds
            self.duration = currentItem.duration.seconds
            
            if !self.isSliderEditing {
                self.sliderViewModel.sliderValue = self.currentTimeVal
            }
            
            UserDefaults.standard.set(self.currentTimeVal, forKey: "lastPlayedTime_\(self.fullUrl)")
            UserDefaults.standard.set(self.duration, forKey: "totalTime_\(self.fullUrl)")
            
            if let currentCue = self.subtitlesLoader.cues.first(where: { self.currentTimeVal >= $0.startTime && self.currentTimeVal <= $0.endTime }) {
                self.subtitleLabel.text = currentCue.text.strippedHTML
            } else {
                self.subtitleLabel.text = ""
            }
            
            if (self.duration - self.currentTimeVal) <= (self.duration * 0.10)
                && self.currentTimeVal != self.duration
                && self.showWatchNextButton
                && self.duration != 0 {
                
                if UserDefaults.standard.bool(forKey: "hideNextButton") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.watchNextButton.isHidden = true
                    }
                } else {
                    self.watchNextButton.isHidden = false
                }
            } else {
                self.watchNextButton.isHidden = true
            }
            
            DispatchQueue.main.async {
                self.sliderHostingController?.rootView = MusicProgressSlider(
                    value: Binding(get: { self.sliderViewModel.sliderValue },
                                   set: { self.sliderViewModel.sliderValue = $0 }),
                    inRange: 0...(self.duration > 0 ? self.duration : 1.0),
                    activeFillColor: .white,
                    fillColor: .white.opacity(0.5),
                    emptyColor: .white.opacity(0.3),
                    height: 30,
                    onEditingChanged: { editing in
                        self.isSliderEditing = editing
                        if !editing {
                            self.player.seek(to: CMTime(seconds: self.sliderViewModel.sliderValue, preferredTimescale: 600))
                        }
                    }
                )
            }
        }
    }
    
    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTimeVal = self.player.currentTime().seconds
        }
    }
    
    @objc func toggleControls() {
        isControlsVisible.toggle()
        
        UIView.animate(withDuration: 0.2) {
            self.controlsContainerView.alpha = self.isControlsVisible ? 1 : 0
            
            self.skip85Button.alpha = self.isControlsVisible ? 0.8 : 0
            
            if self.isControlsVisible {
                NSLayoutConstraint.deactivate(self.watchNextButtonNormalConstraints)
                NSLayoutConstraint.activate(self.watchNextButtonControlsConstraints)
                self.watchNextButton.alpha = 1.0
            } else {
                NSLayoutConstraint.deactivate(self.watchNextButtonControlsConstraints)
                NSLayoutConstraint.activate(self.watchNextButtonNormalConstraints)
                self.watchNextButton.alpha = 0.8
            }
            
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func seekBackward() {
        currentTimeVal = max(currentTimeVal - 10, 0)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
    }
    
    @objc func seekForward() {
        currentTimeVal = min(currentTimeVal + 10, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
    }
    
    @objc func togglePlayPause() {
        if isPlaying {
            player.pause()
            playPauseButton.image = UIImage(systemName: "play.fill")
        } else {
            player.play()
            playPauseButton.image = UIImage(systemName: "pause.fill")
        }
        isPlaying.toggle()
    }
    
    @objc func sliderEditingEnded() {
        let newTime = sliderViewModel.sliderValue
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    @objc func dismissTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func watchNextTapped() {
        player.pause()
        dismiss(animated: true) { [weak self] in
            self?.onWatchNext()
        }
    }
    
    @objc func skip85Tapped() {
        currentTimeVal = min(currentTimeVal + 85, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
    }
    
    func speedChangerMenu() -> UIMenu {
        let speeds: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        let playbackSpeedActions = speeds.map { speed in
            UIAction(title: String(format: "%.2f", speed)) { _ in
                self.player.rate = Float(speed)
                if self.player.timeControlStatus != .playing {
                    self.player.pause()
                }
            }
        }
        return UIMenu(title: "Playback Speed", children: playbackSpeedActions)
    }
    
    func buildOptionsMenu() -> UIMenu {
        var menuElements: [UIMenuElement] = []
        
        if let subURL = subtitlesURL, !subURL.isEmpty {
            let foregroundActions = [
                UIAction(title: "White") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "white" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Yellow") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "yellow" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Green") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "green" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Blue") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "blue" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Red") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "red" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Purple") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "purple" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                }
            ]
            let colorMenu = UIMenu(title: "Subtitle Color", children: foregroundActions)
            
            let fontSizeActions = [
                UIAction(title: "16") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 16 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "18") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 18 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "20") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 20 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "22") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 22 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "24") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 24 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Custom") { _ in self.presentCustomFontAlert() }
            ]
            let fontSizeMenu = UIMenu(title: "Font Size", children: fontSizeActions)
            
            let shadowActions = [
                UIAction(title: "None") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 0 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Low") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 1 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Medium") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 3 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "High") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 6 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                }
            ]
            let shadowMenu = UIMenu(title: "Shadow Intensity", children: shadowActions)
            
            let backgroundActions = [
                UIAction(title: "Toggle") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.backgroundEnabled.toggle() }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                }
            ]
            let backgroundMenu = UIMenu(title: "Background", children: backgroundActions)
            
            let paddingActions = [
                UIAction(title: "10p") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = 10 }
                    self.loadSubtitleSettings()
                },
                UIAction(title: "20p") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = 20 }
                    self.loadSubtitleSettings()
                },
                UIAction(title: "30p") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = 30 }
                    self.loadSubtitleSettings()
                },
                UIAction(title: "Custom") { _ in self.presentCustomPaddingAlert() }
            ]
            let paddingMenu = UIMenu(title: "Bottom Padding", children: paddingActions)
            
            let subtitleOptionsMenu = UIMenu(title: "Subtitle Options", children: [colorMenu, fontSizeMenu, shadowMenu, backgroundMenu, paddingMenu])
            
            menuElements = [subtitleOptionsMenu]
        }
        
        return UIMenu(title: "", children: menuElements)
    }
    
    func presentCustomPaddingAlert() {
        let alert = UIAlertController(title: "Enter Custom Padding", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Padding Value"
            textField.keyboardType = .numberPad
            textField.text = String(Int(self.subtitleBottomPadding))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text, let intValue = Int(text) {
                let newSize = CGFloat(intValue)
                SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = newSize }
                self.loadSubtitleSettings()
            }
        }))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func presentCustomFontAlert() {
        let alert = UIAlertController(title: "Enter Custom Font Size", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Font Size"
            textField.keyboardType = .numberPad
            textField.text = String(Int(self.subtitleFontSize))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text, let newSize = Double(text) {
                SubtitleSettingsManager.shared.update { settings in settings.fontSize = newSize }
                self.loadSubtitleSettings()
                self.updateSubtitleLabelAppearance()
            }
        }))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func loadSubtitleSettings() {
        let settings = SubtitleSettingsManager.shared.settings
        self.subtitleForegroundColor = settings.foregroundColor
        self.subtitleFontSize = settings.fontSize
        self.subtitleShadowRadius = settings.shadowRadius
        self.subtitleBackgroundEnabled = settings.backgroundEnabled
        self.subtitleBottomPadding = settings.bottomPadding
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UserDefaults.standard.bool(forKey: "alwaysLandscape") {
            return .landscape
        } else {
            return .all
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try audioSession.setActive(true)
            
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            Logger.shared.log("Failed to set up AVAudioSession: \(error)")
        }
    }
}

// yes? Like the plural of the famous american rapper ye? -IBHRAD
// low taper fade the meme is massive -cranci
// cranci still doesnt have a job -seiike
// guys watch Clannad already - ibro
