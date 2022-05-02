//
//  DNPlayerView.swift
//  DNPlayerView
//
//  Created by Duy Nguyen on 5/01/2022.
//  Copyright © 2022 Duy Nguyen. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

public protocol DNPlayerViewDelegate: AnyObject {
    func playerView(_ playerView: DNPlayerView, didUpdate playbackTime: Double)
    func playerView(_ playerView: DNPlayerView, didUpdate status: DNPlayerStatus)
    func playerView(_ playerView: DNPlayerView, currentPlayerMode: DNPlayerMode)
}

public extension DNPlayerViewDelegate {
    func playerView(_ playerView: DNPlayerView, didUpdate playbackTime: Double) {}
    func playerView(_ playerView: DNPlayerView, didUpdate status: DNPlayerStatus) {}
    func playerView(_ playerView: DNPlayerView, currentPlayerMode: DNPlayerMode) {}
}

public class DNPlayerView: UIView {
    // MARK: - IBOUTLETS
    @IBOutlet weak var vPlayerContainer: UIView!
    @IBOutlet weak var vPlayerControlContainer: UIView!
    @IBOutlet weak var btnSeekPrev: UIButton!
    @IBOutlet weak var btnPlayPause: UIButton!
    @IBOutlet weak var btnSeekNext: UIButton!
    @IBOutlet weak var vPrev: UIView!
    @IBOutlet weak var vNext: UIView!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var lbTimePlayed: UILabel!
    @IBOutlet weak var lbTotalTime: UILabel!
    @IBOutlet weak var slProgress: UISlider!
    @IBOutlet weak var btnFullscreen: UIButton!
    @IBOutlet weak var vBottomBottomConstraint: NSLayoutConstraint!
    
    // MARK: - VARIABLES
    public weak var delegate: DNPlayerViewDelegate?
    public var player: AVPlayer? {
        get { return playerLayer.player }
        set { playerLayer.player = newValue }
    }
        
    public var playerLayer: AVPlayerLayer {
        let avPlayerLayer = layer as! AVPlayerLayer
        avPlayerLayer.videoGravity = .resizeAspect
        return avPlayerLayer
    }
    public var videoURL: URL!
    public var isPlaying: Bool {
        return player != nil && player?.rate != 0
    }
    
    public var currentPlayerStatus: AVPlayerItem.Status = .unknown {
        didSet {
            delegate?.playerView(self, didUpdate: DNPlayerStatus(rawValue: currentPlayerStatus.rawValue))
        }
    }
    
    private var asset: AVAsset!
    private var playerItemContext = 0
    private var timeObserverToken: Any?
    // Keep the reference and use it to observe the loading status.
    private var playerItem: AVPlayerItem?
    private var hideControlTimer: Timer?
    private var isSeekInProgress = false {
        didSet {
            if isSeekInProgress {
                playerPlaybackState = .loading
            } else {
                playerPlaybackState = isPlaying ? .playing : .paused
            }
        }
    }
    private var chaseTime = CMTime.zero
    private var currentPlayerMode: DNPlayerMode = .portrait {
        didSet {
            didChangePlayerMode()
        }
    }
    private var playerPlaybackState = DNPlayerPlaybackState.paused {
        didSet {
            handlePlayerPlaybackState(playerPlaybackState)
        }
    }
    private var keyWindow: UIWindow? {
        if #available(iOS 13, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    private var initialFrame = CGRect.zero
    private let maximizeIcon = ImageProvider.image(named: "icMaximize")!
    private let minimizeIcon = ImageProvider.image(named: "icMinimize")!
    private let replayIcon = ImageProvider.image(named: "icReplay")!
    private let pauseIcon = ImageProvider.image(named: "icPause")!
    private let playIcon = ImageProvider.image(named: "icPlay")!
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        removeBoundaryTimeObserver()
        cancelHideControlTimer()
    }
    
    // MARK: - OVERRIDES
    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        setUpView()
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
                self.currentPlayerStatus = .unknown
            }
            self.currentPlayerStatus = status
            self.loadingActivityIndicator.stopAnimating()
            // Switch over status value
            switch status {
            case .readyToPlay:
                print(".readyToPlay")
                player?.play()
                playerPlaybackState = .playing
            case .failed:
                print(".failed")
            case .unknown:
                print(".unknown")
            @unknown default:
                print("@unknown default")
            }
        }
        
        if keyPath == #keyPath(AVPlayerItem.duration) {
            if let duration = player?.currentItem?.duration {
                let seconds = CMTimeGetSeconds(duration)
                let secondsText = Int(seconds) % 60
                let minutesText = String(format: "%02d", Int(seconds) / 60)
                lbTotalTime.text = "\(minutesText):\(secondsText)"
            }
        }
        
        if keyPath == "currentItem.loadedTimeRanges" {
            if let duration = player?.currentItem?.asset.duration {
                let seconds = CMTimeGetSeconds(duration)
                let secondsText = Int(seconds) % 60
                let minutesText = String(format: "%02d", Int(seconds) / 60)
                lbTotalTime.text = "\(minutesText):\(secondsText)"
            }
        }
    }
    
    
    // MARK: - ACTIONS
    @IBAction private func didTapOnButtonPlayPause(_ sender: UIButton) {
        if sender.tag == 0 {
            self.handlePlayPauseVideo()
        } else if sender.tag == 1 {
            self.replayVideo()
        }
    }
    
    @IBAction private func didTapOnButtonFullscreen(_ sender: UIButton) {
        let mode: DNPlayerMode = sender.isSelected ? .portrait : .landscape
        changePlayerMode(to: mode)
    }
    
    @IBAction private func didTapOnButtonSeekNext(_ sender: UIButton) {
        if let currentTime = self.playerItem?.currentTime() {
            sender.doRotateAnimation(duration: 0.2, rotateAngle: CGFloat(Double.pi / 4))
            let currentSeconds = CMTimeGetSeconds(currentTime)
            let value = currentSeconds.advanced(by: 10)
            let newChaseTime = CMTime(value: Int64(value), timescale: 1)
            self.stopPlayingAndSeekSmoothlyToTime(newChaseTime: newChaseTime)
        }
    }
    
    @IBAction private func didTapOnButtonSeekPrev(_ sender: UIButton) {
        if let currentTime = self.playerItem?.currentTime(), currentTime > CMTime(value: 10, timescale: 1) {
            sender.doRotateAnimation(rotateAngle: -CGFloat(Double.pi / 4))
            let currentSeconds = CMTimeGetSeconds(currentTime)
            let value = currentSeconds.advanced(by: -10)
            let newChaseTime = CMTime(value: Int64(value), timescale: 1)
            self.stopPlayingAndSeekSmoothlyToTime(newChaseTime: newChaseTime)
        }
    }
    
    @IBAction private func progressSliderValueChanged(_ sender: UISlider) {
        cancelHideControlTimer()
        
        if let duration = playerItem?.duration {
            let totalSeconds = CMTimeGetSeconds(duration)
            let value = Float64(sender.value) * totalSeconds
            let newChaseTime = CMTime(value: Int64(value), timescale: 1)
            self.stopPlayingAndSeekSmoothlyToTime(newChaseTime: newChaseTime)
        }
        
        if sender.value == 0 {
            self.animatePlayPauseButtonImage(isPlaying: false)
            self.btnPlayPause.tag = 0
        } else if sender.value == 100 {
            self.btnPlayPause.tag = 1
            self.animatePlayPauseButtonImage(newImage: self.replayIcon)
        }
    }
    
    // MARK: - PUBLIC FUNCTIONS
    public static func instance(frame: CGRect, delegate: DNPlayerViewDelegate? = nil) -> DNPlayerView {
        let nib = UINib(nibName: "DNPlayerView", bundle: Bundle(for: self))
        guard let videoPlayerView = nib.instantiate(withOwner: nil, options: nil).first as? DNPlayerView else {
            return DNPlayerView(frame: frame)
        }
        videoPlayerView.delegate = delegate
        videoPlayerView.initialFrame = frame
        return videoPlayerView
    }
    
    public func play(with url: URL) {
        setUpAsset(with: url) { [weak self] (asset: AVAsset) in
            self?.setUpPlayerItem(with: asset)
            self?.videoURL = url
        }
    }
    
    public func pause() {
        player?.pause()
        playerPlaybackState = .paused
    }
    
    public func resume() {
        player?.play()
        playerPlaybackState = .playing
        setUpHideControlTimer()
    }
    
    public func replayVideo() {
        stopPlayingAndSeekSmoothlyToTime(newChaseTime: CMTime.zero)
    }
    
    public func showLoading() {
        self.loadingActivityIndicator.startAnimating()
    }
    
    public func hideLoading() {
        self.loadingActivityIndicator.stopAnimating()
    }
    
    public func changePlayerMode(to mode: DNPlayerMode) {
        currentPlayerMode = mode
    }
    
    // MARK: - PRIVATE FUNCTIONS
    private func setUpView() {
        playerPlaybackState = .loading
        vPlayerContainer.addTapGestureRecognizer { [weak self] in
            guard let self = self else { return }
            self.animatePlayerControlContainerView(isHidden: false)
            if self.isPlaying == true {
                self.setUpHideControlTimer()
            }
        }
        
        self.vPlayerControlContainer.alpha = 0
        self.vPlayerControlContainer.addTapGestureRecognizer { [weak self] in
            guard let self = self else { return }
            self.animatePlayerControlContainerView(isHidden: true)
        }
        
        if let thumbImage = makeCircleImageWith(size: CGSize(width: 16, height: 16), backgroundColor: .red) {
            slProgress.setThumbImage(thumbImage, for: .normal)
            slProgress.setThumbImage(thumbImage, for: .selected)
        }
        
        btnFullscreen.setImage(maximizeIcon, for: .normal)
        btnFullscreen.setImage(minimizeIcon, for: .selected)
    }
    
    private func setUpHideControlTimer() {
        cancelHideControlTimer()
        
        hideControlTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { [weak self] timer in
            guard let self = self else { return }
            self.animatePlayerControlContainerView(isHidden: true)
        })
    }
    
    private func cancelHideControlTimer() {
        if hideControlTimer != nil {
            hideControlTimer?.invalidate()
            hideControlTimer = nil
        }
    }
    
    private func setUpAsset(with url: URL, completion: ((_ asset: AVAsset) -> Void)?) {
        asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            var error: NSError? = nil
            let status = self.asset.statusOfValue(forKey: "playable", error: &error)
            switch status {
            case .loaded:
                completion?(self.asset)
            case .failed:
                print(".failed")
            case .cancelled:
                print(".cancelled")
            default:
                print("default")
            }
        }
    }
    
    private func setUpPlayerItem(with asset: AVAsset) {
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        
        let duration = asset.duration
        let durationText = duration.durationFormatted()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.player = AVPlayer(playerItem: self.playerItem!)
            self.playerLayer.player = self.player
            self.addPeriodicTimeObserver()
            self.lbTotalTime.text = durationText
        }
    }
    
    private func addPeriodicTimeObserver() {
        // Notify every half second
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)
        
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            // update player transport UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lbTimePlayed.text = "\(time.durationFormatted())"
                self.btnSeekPrev.isEnabled = CMTimeGetSeconds(time) > 10
                
                if let duration = self.playerItem?.duration {
                    let durationSeconds = CMTimeGetSeconds(duration)
                    let timePlayedSeconds = CMTimeGetSeconds(time)
                    self.slProgress.value = Float(timePlayedSeconds / durationSeconds)
                    
                    if CMTimeCompare(duration, time) == 0 {
                        if !self.isSeekInProgress {
                            self.playerPlaybackState = .finished
                        }
                    } else {
                        self.btnPlayPause.tag = 0
                    }
                }
            }
            self.delegate?.playerView(self, didUpdate: time.seconds)
        }
    }
    
    private func removeBoundaryTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func handlePlayerPlaybackState(_ state: DNPlayerPlaybackState) {
        switch state {
        case .loading:
            self.cancelHideControlTimer()
            self.btnSeekNext.isEnabled = true
            self.btnPlayPause.tag = 0
            self.loadingActivityIndicator.startAnimating()
            self.btnPlayPause.isHidden = true
        case .playing:
            self.btnSeekNext.isEnabled = true
            self.btnPlayPause.tag = 0
            self.btnPlayPause.isHidden = false
            self.loadingActivityIndicator.stopAnimating()
            self.animatePlayPauseButtonImage(newImage: pauseIcon)
        case .paused:
            self.btnSeekNext.isEnabled = true
            self.btnPlayPause.tag = 0
            self.btnPlayPause.isHidden = false
            self.loadingActivityIndicator.stopAnimating()
            self.animatePlayPauseButtonImage(newImage: playIcon)
        case .finished:
            if self.vPlayerControlContainer.isHidden || self.vPlayerControlContainer.alpha == 0 {
                self.animatePlayerControlContainerView(isHidden: false)
            }
            self.btnSeekNext.isEnabled = false
            self.btnPlayPause.tag = 1
            self.btnPlayPause.isHidden = false
            self.loadingActivityIndicator.stopAnimating()
            self.animatePlayPauseButtonImage(newImage: replayIcon)
        }
    }
    
    private func handlePlayPauseVideo() {
        if self.isPlaying {
            self.pause()
            self.cancelHideControlTimer()
        } else {
            self.resume()
            self.setUpHideControlTimer()
        }
    }
    
    private func didChangePlayerMode() {
        guard playerPlaybackState != .loading else { return }
        delegate?.playerView(self, currentPlayerMode: currentPlayerMode)
        btnFullscreen.isSelected.toggle()
        
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(rotationAngle: self.currentPlayerMode.angle)
            let height = self.currentPlayerMode == .portrait ? self.initialFrame.height : UIScreen.main.bounds.size.height
            let topSpace = self.currentPlayerMode == .portrait ? self.initialFrame.origin.y : 0
            self.frame.origin = CGPoint(x: 0, y:  topSpace)
            self.frame.size = CGSize(width: UIScreen.main.bounds.size.width, height: height)
            self.vBottomBottomConstraint.constant = self.currentPlayerMode == .portrait ? 0 : 20
        })
    }
    
    private func stopPlayingAndSeekSmoothlyToTime(newChaseTime: CMTime) {
        player?.pause()
        
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            chaseTime = newChaseTime;
            
            if !isSeekInProgress {
                trySeekToChaseTime()
            }
        }
    }
    
    private func trySeekToChaseTime() {
        if currentPlayerStatus == .unknown {
            // wait until item becomes ready (KVO player.currentItem.status)
        } else if currentPlayerStatus == .readyToPlay {
            actuallySeekToTime()
        }
    }
    
    private func actuallySeekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        player?.seek(to: seekTimeInProgress, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { [weak self] (isFinished) in
            guard let self = self else { return }
            if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                self.resume()
                self.setUpHideControlTimer()
                self.isSeekInProgress = false
            } else {
                self.trySeekToChaseTime()
            }
        })
    }
}

// MARK: - EXTENSIONS
extension DNPlayerView {
    // Animation functions
    private func animatePlayPauseButtonImage(isPlaying: Bool) {
        let image = isPlaying ? pauseIcon : playIcon
        UIView.transition(with: btnPlayPause, duration: 0.3, options: .transitionFlipFromRight, animations: { [weak self] in
            guard let self = self else { return }
            self.btnPlayPause.setImage(image, for: .normal)
        })
    }
    
    private func animatePlayerControlContainerView(isHidden: Bool) {
        if !isHidden {
            self.vPlayerControlContainer.isHidden = false
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            guard let self = self else { return }
            self.vPlayerControlContainer.alpha = isHidden ? 0 : 1
        }) { [weak self] (finished) in
            guard let self = self else { return }
            if finished && isHidden == true {
                self.vPlayerControlContainer.isHidden = true
            }
        }
    }
    
    private func animatePlayPauseButtonImage(newImage: UIImage) {
        UIView.transition(with: btnPlayPause, duration: 0.3, options: .transitionFlipFromRight, animations: { [weak self] in
            guard let self = self else { return }
            self.btnPlayPause.setImage(newImage, for: .normal)
        })
    }
    
    private func makeCircleImageWith(size: CGSize, backgroundColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(backgroundColor.cgColor)
        context?.setStrokeColor(UIColor.clear.cgColor)
        let bounds = CGRect(origin: .zero, size: size)
        context?.addEllipse(in: bounds)
        context?.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
