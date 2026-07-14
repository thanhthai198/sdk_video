#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'videosdk_player'
  s.version          = '0.1.0'
  s.summary          = 'Flutter bridge for VideoSDK'
  s.description      = 'Platform view + method channel wrapping VideoSDK'
  s.homepage         = 'https://example.com/videosdk'
  s.license          = { :type => 'UNLICENSED' }
  s.author           = { 'VideoSDK' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'VideoSDK'
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
end

