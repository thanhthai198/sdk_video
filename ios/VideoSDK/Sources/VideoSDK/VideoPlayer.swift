import AVFoundation
import Combine
import Foundation

/// Thin AVPlayer wrapper for basic playback controls.
@MainActor
public final class VideoPlayer: ObservableObject {
    public let player = AVQueuePlayer()

    @Published public private(set) var currentItem: VideoItem?
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentQuality: QualityOption = .auto
    @Published public private(set) var selectedSubtitle: SubtitleTrack?
    @Published public private(set) var position: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var bufferedFraction: Double = 0
    @Published public private(set) var isMuted = false
    @Published public var isAutoplayEnabled = true
    @Published public private(set) var playbackRate: Float = 1.0
    @Published public var isLoopEnabled = false

    public var eventHandler: ((PlayerEvent) -> Void)?

    private var playlist: [VideoItem] = []
    private var playerItems: [AVPlayerItem] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservers: [NSKeyValueObservation] = []

    public init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let rawDuration = self.player.currentItem?.duration.seconds ?? 0
            let position = time.seconds.isNaN ? 0 : time.seconds
            let safeDuration = rawDuration.isNaN || rawDuration.isInfinite ? 0 : rawDuration
            self.position = position
            self.duration = safeDuration
            self.bufferedFraction = self.computeBufferedFraction(duration: safeDuration)
            self.eventHandler?(.progress(position: position, duration: safeDuration))
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            Task { @MainActor in
                guard note.object as? AVPlayerItem === self.player.currentItem else { return }
                if self.isLoopEnabled {
                    self.seek(to: 0)
                    self.play()
                    return
                }
                self.isPlaying = false
                self.eventHandler?(.ended)
                if self.isAutoplayEnabled {
                    self.next()
                }
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    public func setPlaylist(_ items: [VideoItem], startIndex: Int = 0) {
        precondition(!items.isEmpty, "Playlist must not be empty")
        playlist = items
        player.removeAllItems()
        statusObservers.removeAll()

        playerItems = items.map { makePlayerItem(for: $0) }
        let start = min(max(startIndex, 0), playerItems.count - 1)
        for item in playerItems[start...] {
            player.insert(item, after: nil)
        }

        currentItem = items[start]
        eventHandler?(.mediaItemTransition(currentItem))
        observeCurrentItemStatus()
        applyPreferredPeakBitRate(for: currentQuality)
    }

    public func play() {
        player.rate = playbackRate
        player.play()
        isPlaying = true
        eventHandler?(.playingChanged(true))
    }

    public func pause() {
        player.pause()
        isPlaying = false
        eventHandler?(.playingChanged(false))
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    public func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    public func next() {
        guard let current = player.currentItem,
              let index = playerItems.firstIndex(of: current),
              index + 1 < playerItems.count else { return }

        player.advanceToNextItem()
        currentItem = playlist[index + 1]
        eventHandler?(.mediaItemTransition(currentItem))
        observeCurrentItemStatus()
        applyPreferredPeakBitRate(for: currentQuality)
        play()
    }

    public func previous() {
        guard let current = player.currentItem,
              let index = playerItems.firstIndex(of: current),
              index > 0 else {
            seek(to: 0)
            return
        }

        let targetIndex = index - 1
        player.removeAllItems()
        for item in playerItems[targetIndex...] {
            player.insert(item, after: nil)
        }
        currentItem = playlist[targetIndex]
        eventHandler?(.mediaItemTransition(currentItem))
        observeCurrentItemStatus()
        applyPreferredPeakBitRate(for: currentQuality)
        play()
    }

    public func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func seekBy(_ delta: TimeInterval) {
        let current = player.currentTime().seconds
        let safeCurrent = current.isNaN ? 0 : current
        seek(to: safeCurrent + delta)
    }

    public func setMuted(_ muted: Bool) {
        isMuted = muted
        player.isMuted = muted
    }

    public func toggleMute() {
        setMuted(!isMuted)
    }

    public func availableQualities() -> [QualityOption] {
        // HLS variants are chosen via preferredPeakBitRate; expose common presets.
        [
            .auto,
            QualityOption(height: 360, label: "360p"),
            QualityOption(height: 720, label: "720p"),
            QualityOption(height: 1080, label: "1080p"),
        ]
    }

    public func setQuality(_ option: QualityOption) {
        currentQuality = option
        applyPreferredPeakBitRate(for: option)
        eventHandler?(.qualityChanged(option))
    }

    public func availableSubtitles() -> [SubtitleTrack] {
        var result = currentItem?.subtitleTracks ?? []

        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else {
            return result
        }

        for option in group.options {
            let language = Self.languageCode(from: option.locale) ?? "und"
            let label = option.displayName
            if !result.contains(where: { $0.language.caseInsensitiveCompare(language) == .orderedSame }) {
                result.append(
                    SubtitleTrack(
                        id: language,
                        language: language,
                        label: label.isEmpty ? language.uppercased() : label
                    )
                )
            }
        }
        return result
    }

    public func setSubtitle(_ track: SubtitleTrack?) {
        selectedSubtitle = track
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else {
            eventHandler?(.subtitleChanged(track))
            return
        }

        if let track {
            let option = group.options.first {
                let language = Self.languageCode(from: $0.locale) ?? "und"
                return language.caseInsensitiveCompare(track.language) == .orderedSame
                    || $0.displayName == track.label
            }
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }

        eventHandler?(.subtitleChanged(track))
    }

    public func currentPosition() -> TimeInterval { position }

    public func currentDuration() -> TimeInterval { duration }

    private func makePlayerItem(for video: VideoItem) -> AVPlayerItem {
        let asset = AVURLAsset(url: video.url)
        let item = AVPlayerItem(asset: asset)

        // External WebVTT can be mixed in via AVMediaSelection later if needed.
        // For demo, embedded HLS subtitles + metadata tracks are enough.
        _ = video.subtitleTracks
        return item
    }

    private func applyPreferredPeakBitRate(for option: QualityOption) {
        // Approximate height → bitrate caps for HLS ABR guidance.
        let bitRate: Double
        switch option.height {
        case ...0:
            bitRate = 0 // Auto
        case ...360:
            bitRate = 800_000
        case ...720:
            bitRate = 2_500_000
        default:
            bitRate = 6_000_000
        }
        player.currentItem?.preferredPeakBitRate = bitRate
    }

    private func observeCurrentItemStatus() {
        statusObservers.removeAll()
        guard let item = player.currentItem else { return }

        let observer = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.eventHandler?(.ready)
                case .failed:
                    let message = item.error?.localizedDescription ?? "Playback error"
                    self.eventHandler?(.error(message))
                default:
                    break
                }
            }
        }
        statusObservers.append(observer)
    }

    private func computeBufferedFraction(duration: TimeInterval) -> Double {
        guard duration > 0,
              let range = player.currentItem?.loadedTimeRanges.last?.timeRangeValue
        else { return 0 }
        let end = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration)
        guard !end.isNaN, !end.isInfinite else { return 0 }
        return min(max(end / duration, 0), 1)
    }

    private static func languageCode(from locale: Locale?) -> String? {
        guard let locale else { return nil }
        if #available(iOS 16.0, *) {
            return locale.language.languageCode?.identifier
        }
        return locale.languageCode
    }
}
