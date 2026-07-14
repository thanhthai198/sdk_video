import UIKit
import AVFoundation
import VideoSDK

@objc(VideoSdkViewManager)
class VideoSdkViewManager: RCTViewManager {
  override static func requiresMainQueueSetup() -> Bool { true }

  override func view() -> UIView! {
    let view = VideoSdkView()
    VideoSdkPlayer.pendingLayerHost = view
    if let player = VideoSdkPlayer.shared {
      view.attach(player: player)
    }
    return view
  }
}

final class VideoSdkView: UIView {
  private let playerLayer = AVPlayerLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
    layer.addSublayer(playerLayer)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer.frame = bounds
  }

  func attach(player: VideoPlayer) {
    playerLayer.player = player.player
  }
}
