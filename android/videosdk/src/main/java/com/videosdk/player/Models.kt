package com.videosdk.player

/**
 * Public models shared by the Android VideoSDK surface.
 */
data class VideoItem(
    val id: String,
    val url: String,
    val title: String = "",
    val subtitleTracks: List<SubtitleTrack> = emptyList(),
)

data class SubtitleTrack(
    val id: String,
    val language: String,
    val label: String,
    val url: String? = null,
)

data class QualityOption(
    val height: Int,
    val label: String,
) {
    companion object {
        val AUTO = QualityOption(height = -1, label = "Auto")
    }
}

sealed class PlayerEvent {
    data object Ready : PlayerEvent()
    data class Progress(val positionMs: Long, val durationMs: Long) : PlayerEvent()
    data class PlayingChanged(val isPlaying: Boolean) : PlayerEvent()
    data class QualityChanged(val option: QualityOption) : PlayerEvent()
    data class SubtitleChanged(val track: SubtitleTrack?) : PlayerEvent()
    data class MediaItemTransition(val item: VideoItem?) : PlayerEvent()
    data class Error(val message: String, val cause: Throwable? = null) : PlayerEvent()
    data object Ended : PlayerEvent()
}
