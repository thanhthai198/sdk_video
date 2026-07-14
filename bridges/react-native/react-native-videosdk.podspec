require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = 'react-native-videosdk'
  s.version      = package['version']
  s.summary      = package['description']
  s.license      = package['license']
  s.homepage     = 'https://example.com/videosdk'
  s.authors      = { 'VideoSDK' => 'dev@example.com' }
  s.platforms    = { :ios => '15.1' }
  s.source       = { :path => '.' }
  s.source_files = 'ios/**/*.{h,m,mm,swift}'
  s.swift_version = '5.0'
  s.dependency 'React-Core'
  s.dependency 'VideoSDK'
end
