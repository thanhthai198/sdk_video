Pod::Spec.new do |s|
  s.name             = 'VideoSDK'
  s.version          = '1.0.0'
  s.summary          = 'Native VideoSDK core (AVPlayer)'
  s.description      = 'AVPlayer-based video player library for iOS'
  s.homepage         = 'https://example.com/videosdk'
  s.license          = { :type => 'UNLICENSED' }
  s.author           = { 'VideoSDK' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Sources/VideoSDK/**/*.swift'
  s.platform         = :ios, '15.1'
  s.swift_version    = '5.0'
  s.frameworks       = 'AVFoundation', 'AVKit', 'UIKit'
end
