//
//  DNPlayerStatus.swift
//  DNPlayerView
//
//  Created by Duy Nguyen on 01/05/2022.
//

import Foundation

public enum DNPlayerStatus: Int {
    case unknown = 0
    case readyToPlay
    case failed
    
    public init(rawValue: Int) {
        switch rawValue {
        case 1:  self = .readyToPlay
        case 2:  self = .failed
        default: self = .unknown
        }
    }
}
