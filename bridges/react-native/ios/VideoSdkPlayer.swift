import Foundation
import AVFoundation
import VideoSDK

@objc(VideoSdkPlayer)
class VideoSdkPlayer: RCTEventEmitter {
  static var shared: VideoPlayer?
  static var pendingLayerHost: VideoSdkView?

  override static func requiresMainQueueSetup() -> Bool { true }
  override func supportedEvents() -> [String]! { ["VideoSdkPlayerEvent"] }

  private func player() -> VideoPlayer {
    if let shared = Self.shared { return shared }
    let created = VideoPlayer()
    created.eventHandler = { [weak self] event in
      self?.emit(event: event)
    }
    Self.shared = created
    if let host = Self.pendingLayerHost {
      host.attach(player: created)
    }
    return created
  }

  @objc func setPlaylist(_ items: NSArray, startIndex: NSNumber, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      do {
        let mapped: [VideoItem] = items.compactMap { raw in
          guard let dict = raw as? [String: Any],
                let id = dict["id"] as? String,
                let urlString = dict["url"] as? String,
                let url = URL(string: urlString) else { return nil }
          return VideoItem(id: id, url: url, title: dict["title"] as? String ?? "")
        }
        self.player().setPlaylist(mapped, startIndex: startIndex.intValue)
        resolver(nil)
      } catch {
        rejecter("playlist_error", error.localizedDescription, error)
      }
    }
  }

  @objc func play(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { self.player().play(); resolver(nil) }
  }

  @objc func pause(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { self.player().pause(); resolver(nil) }
  }

  @objc func togglePlayPause(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { self.player().togglePlayPause(); resolver(nil) }
  }

  @objc func next(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { self.player().next(); resolver(nil) }
  }

  @objc func previous(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async { self.player().previous(); resolver(nil) }
  }

  @objc func seekTo(_ positionMs: NSNumber, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      self.player().seek(to: positionMs.doubleValue / 1000.0)
      resolver(nil)
    }
  }

  @objc func setPlaybackRate(_ rate: NSNumber, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      self.player().setPlaybackRate(rate.floatValue)
      resolver(nil)
    }
  }

  @objc func setAutoplay(_ enabled: Bool, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      self.player().isAutoplayEnabled = enabled
      resolver(nil)
    }
  }

  @objc func setLoop(_ enabled: Bool, resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      self.player().isLoopEnabled = enabled
      resolver(nil)
    }
  }

  @objc func release(_ resolver: RCTPromiseResolveBlock, rejecter: RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      Self.shared = nil
      resolver(nil)
    }
  }

  private func emit(event: PlayerEvent) {
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
    case .qualityChanged(let option):
      body["type"] = "qualityChanged"
      body["label"] = option.label
    case .subtitleChanged(let track):
      body["type"] = "subtitleChanged"
      body["label"] = track?.label
    case .mediaItemTransition(let item):
      body["type"] = "mediaItemTransition"
      body["id"] = item?.id
      body["title"] = item?.title
    }
    sendEvent(withName: "VideoSdkPlayerEvent", body: body)
  }
}
