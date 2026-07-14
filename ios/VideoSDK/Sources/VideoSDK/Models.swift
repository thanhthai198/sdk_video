import Foundation

public struct VideoItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let title: String
    public let subtitleTracks: [SubtitleTrack]

    public init(
        id: String,
        url: URL,
        title: String = "",
        subtitleTracks: [SubtitleTrack] = []
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.subtitleTracks = subtitleTracks
    }
}

public struct SubtitleTrack: Identifiable, Equatable, Sendable {
    public let id: String
    public let language: String
    public let label: String
    public let url: URL?

    public init(id: String, language: String, label: String, url: URL? = nil) {
        self.id = id
        self.language = language
        self.label = label
        self.url = url
    }
}

public struct QualityOption: Equatable, Sendable, Hashable {
    public let height: Int
    public let label: String

    public static let auto = QualityOption(height: -1, label: "Auto")

    public init(height: Int, label: String) {
        self.height = height
        self.label = label
    }
}

public enum PlayerEvent: Sendable {
    case ready
    case progress(position: TimeInterval, duration: TimeInterval)
    case playingChanged(Bool)
    case qualityChanged(QualityOption)
    case subtitleChanged(SubtitleTrack?)
    case mediaItemTransition(VideoItem?)
    case error(String)
    case ended
}
