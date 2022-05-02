//
//  VideoListVC.swift
//  SampleApp
//
//  Created by Duy Nguyen on 01/05/2022.
//

import UIKit
import DNPlayerView

class VideoListVC: UIViewController {
    // MARK: - IBOutlets
    
    // MARK: - Variables
    private var vVideoPlayer: DNPlayerView!
    
    // MARK: - Overrides
    override func viewDidLoad() {
        super.viewDidLoad()

        vVideoPlayer = DNPlayerView.instance(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 300), delegate: self)
        view.addSubview(vVideoPlayer)
        vVideoPlayer.play(with: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!)
    }
    
    // MARK: - IBActions
    

    // MARK: - Functions
    
}

// MARK: - Extensions
extension VideoListVC: DNPlayerViewDelegate {
    func playerView(_ playerView: DNPlayerView, didUpdate playbackTime: Double) {
        
    }
    
    func playerView(_ playerView: DNPlayerView, didUpdate status: DNPlayerStatus) {
        print("PlayerStatus: \(status)")
    }
    
    func playerView(_ playerView: DNPlayerView, currentPlayerMode: DNPlayerMode) {
        print("currentPlayerMode: \(currentPlayerMode)")
    }
}
