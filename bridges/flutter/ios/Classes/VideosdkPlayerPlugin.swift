import Flutter
import UIKit
import AVFoundation
import VideoSDK

public class VideosdkPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static var sharedPlayer: VideoPlayer?
  static var pendingView: VideosdkPlatformView?

  private var eventSink: FlutterEventSink?
  private var player: VideoPlayer?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VideosdkPlayerPlugin()
    let channel = FlutterMethodChannel(name: "videosdk_player", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler(instance.handle)

    let events = FlutterEventChannel(name: "videosdk_player_events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)

    registrar.register(VideosdkPlatformViewFactory(), withId: "videosdk_player_view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let engine = self.ensurePlayer()
      switch call.method {
      case "setPlaylist":
        guard let args = call.arguments as? [String: Any],
              let rawItems = args["items"] as? [[String: Any]] else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        let items: [VideoItem] = rawItems.compactMap { dict in
          guard let id = dict["id"] as? String,
                let urlString = dict["url"] as? String,
                let url = URL(string: urlString) else { return nil }
          return VideoItem(id: id, url: url, title: dict["title"] as? String ?? "")
        }
        let startIndex = args["startIndex"] as? Int ?? 0
        engine.setPlaylist(items, startIndex: startIndex)
        Self.pendingView?.attach(player: engine)
        result(nil)
      case "play":
        engine.play(); result(nil)
      case "pause":
        engine.pause(); result(nil)
      case "togglePlayPause":
        engine.togglePlayPause(); result(nil)
      case "next":
        engine.next(); result(nil)
      case "previous":
        engine.previous(); result(nil)
      case "seekTo":
        let ms = (call.arguments as? [String: Any])?["positionMs"] as? Double ?? 0
        engine.seek(to: ms / 1000.0); result(nil)
      case "setPlaybackRate":
        let rate = (call.arguments as? [String: Any])?["rate"] as? Float ?? 1
        engine.setPlaybackRate(rate); result(nil)
      case "setAutoplay":
        engine.isAutoplayEnabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? true
        result(nil)
      case "setLoop":
        engine.isLoopEnabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        result(nil)
      case "release":
        Self.sharedPlayer = nil
        self.player = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func ensurePlayer() -> VideoPlayer {
    if let player { return player }
    let created = VideoPlayer()
    created.eventHandler = { [weak self] event in
      self?.emit(event)
    }
    player = created
    Self.sharedPlayer = created
    Self.pendingView?.attach(player: created)
    return created
  }

  private func emit(_ event: PlayerEvent) {
    var body: [String: Any] = [:]
    switch event {
    case .ready: body["type"] = "ready"
    case .progress(let position, let duration):
      body["type"] = "progress"
      body["positionMs"] = position * 1000
      body["durationMs"] = duration * 1000
    case .playingChanged(let playing):
      body["type"] = "playingChanged"
      body["isPlaying"] = playing
    case .ended: body["type"] = "ended"
    case .error(let message):
      body["type"] = "error"
      body["message"] = message
    default:
      body["type"] = "other"
    }
    eventSink?(body)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

class VideosdkPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    VideosdkPlatformView(frame: frame)
  }
}

class VideosdkPlatformView: NSObject, FlutterPlatformView {
  private let view: UIView
  private let playerLayer = AVPlayerLayer()

  init(frame: CGRect) {
    view = UIView(frame: frame)
    view.backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
    view.layer.addSublayer(playerLayer)
    super.init()
    VideosdkPlayerPlugin.pendingView = self
    if let player = VideosdkPlayerPlugin.sharedPlayer {
      attach(player: player)
    }
  }

  func attach(player: VideoPlayer) {
    playerLayer.player = player.player
  }

  func view() -> UIView {
    playerLayer.frame = view.bounds
    return view
  }
}
