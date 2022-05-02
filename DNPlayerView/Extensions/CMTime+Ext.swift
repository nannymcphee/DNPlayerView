//
//  CMTime+Ext.swift
//  DNPlayerView
//
//  Created by Duy Nguyen on 01/05/2022.
//

import CoreMedia

extension CMTime {
    func durationFormatted() -> String {
        let seconds = CMTimeGetSeconds(self)
        let secondsText = String(format: "%02d", Int(seconds) % 60)
        let minutesText = String(format: "%02d", Int(seconds) / 60)
        return "\(minutesText):\(secondsText)"
    }
}
