import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI surface bound to `VideoPlayer`.
public struct VideoPlayerView: UIViewRepresentable {
    public let player: AVPlayer

    public init(player: VideoPlayer) {
        self.player = player.player
    }

    public init(player: AVPlayer) {
        self.player = player
    }

    public func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    public func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

public final class PlayerUIView: UIView {
    public override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
