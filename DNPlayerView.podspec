Pod::Spec.new do |s|
  s.name          = "DNPlayerView"
  s.version       = "0.0.1"
  s.summary       = "Video Player View using AVKit and AVFoundation"
  s.description   = "Video Player View using AVKit and AVFoundation, including example app"
  s.homepage      = "https://github.com/nannymcphee"
  s.license       = "MIT"
  s.author        = "DuyNguyen"
  s.platform      = :ios, "9.0"
  s.swift_version = "4.2"
  s.source        = {
    :git => "https://github.com/nannymcphee/DNPlayerView.git",
    :tag => "#{s.version}"
  }
  s.source_files        = "DNPlayerView/**/*.{h,m,swift}"
  s.public_header_files = "DNPlayerView/**/*.h"
end