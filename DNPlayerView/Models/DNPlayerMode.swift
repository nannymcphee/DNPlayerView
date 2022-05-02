//
//  DNPlayerMode.swift
//  DNPlayerView
//
//  Created by Duy Nguyen on 01/05/2022.
//

import UIKit
import AVFoundation

public enum DNPlayerMode {
    case portrait
    case landscape
    
    public func change() -> DNPlayerMode {
        switch self {
        case .landscape:
            return .portrait
        default:
            return .landscape
        }
    }
    
    public var angle: CGFloat {
        switch self {
        case .landscape:
            return .pi / 2
        default:
            return .zero
        }
    }
    
    public var videoGravity: AVLayerVideoGravity {
        switch self {
        case .landscape:
            return .resizeAspect
        default:
            return .resize
        }
    }
}
