//
//  ImageProvider.swift
//  DNPlayerView
//
//  Created by Duy Nguyen on 01/05/2022.
//

import UIKit

final class ImageProvider: NSObject {
    public static func image(named: String) -> UIImage? {
        return UIImage(named: named, in: Bundle(for: self), with: nil)
    }
}
