package com.videosdk.player

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.PlayerView

/**
 * Thin wrapper around Media3 ExoPlayer for basic playback controls.
 *
 * Supports play/pause, next, seek, quality selection, and subtitles.
 */
class VideoPlayer(
    context: Context,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val trackSelector = DefaultTrackSelector(appContext)
    private val listeners = linkedSetOf<(PlayerEvent) -> Unit>()

    private val exoPlayer: ExoPlayer = ExoPlayer.Builder(appContext)
        .setTrackSelector(trackSelector)
        .build()
        .also { player ->
            player.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_READY -> emit(PlayerEvent.Ready)
                        Player.STATE_ENDED -> {
                            emit(PlayerEvent.Ended)
                            when {
                                isLoopEnabled -> {
                                    exoPlayer.seekTo(0)
                                    play()
                                }
                                isAutoplayEnabled && exoPlayer.hasNextMediaItem() -> {
                                    exoPlayer.seekToNextMediaItem()
                                    play()
                                }
                            }
                        }
                    }
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    emit(PlayerEvent.PlayingChanged(isPlaying))
                }

                override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                    val id = mediaItem?.mediaId
                    val item = playlist.firstOrNull { it.id == id }
                    emit(PlayerEvent.MediaItemTransition(item))
                }

                override fun onPlayerError(error: PlaybackException) {
                    emit(PlayerEvent.Error(error.message ?: "Playback error", error))
                }

                override fun onTracksChanged(tracks: Tracks) {
                    // Quality / subtitle lists can be refreshed by host via getters.
                }
            })
        }

    private var playlist: List<VideoItem> = emptyList()
    private var currentQuality: QualityOption = QualityOption.AUTO
    private var selectedSubtitle: SubtitleTrack? = null
    private var progressRunnable: Runnable? = null
    var isAutoplayEnabled: Boolean = true
    var isLoopEnabled: Boolean = false
    private var playbackRate: Float = 1f

    fun currentQuality(): QualityOption = currentQuality

    fun selectedSubtitle(): SubtitleTrack? = selectedSubtitle

    fun attach(playerView: PlayerView) {
        playerView.player = exoPlayer
        playerView.useController = false
    }

    fun detach(playerView: PlayerView) {
        if (playerView.player === exoPlayer) {
            playerView.player = null
        }
    }

    fun addListener(listener: (PlayerEvent) -> Unit) {
        listeners += listener
    }

    fun removeListener(listener: (PlayerEvent) -> Unit) {
        listeners -= listener
    }

    fun setPlaylist(items: List<VideoItem>, startIndex: Int = 0) {
        require(items.isNotEmpty()) { "Playlist must not be empty" }
        playlist = items
        val mediaItems = items.map { it.toMediaItem() }
        exoPlayer.setMediaItems(mediaItems, startIndex.coerceIn(0, items.lastIndex), 0L)
        exoPlayer.prepare()
        startProgressTicker()
    }

    fun play() {
        exoPlayer.playWhenReady = true
        exoPlayer.play()
    }

    fun pause() {
        exoPlayer.pause()
    }

    fun togglePlayPause() {
        if (exoPlayer.isPlaying) pause() else play()
    }

    fun next() {
        if (exoPlayer.hasNextMediaItem()) {
            exoPlayer.seekToNextMediaItem()
            play()
        }
    }

    fun previous() {
        if (exoPlayer.hasPreviousMediaItem()) {
            exoPlayer.seekToPreviousMediaItem()
            play()
        }
    }

    fun seekTo(positionMs: Long) {
        exoPlayer.seekTo(positionMs.coerceAtLeast(0L))
    }

    fun setMuted(muted: Boolean) {
        exoPlayer.volume = if (muted) 0f else 1f
    }

    fun isMuted(): Boolean = exoPlayer.volume == 0f

    fun toggleMute() {
        setMuted(!isMuted())
    }

    fun setPlaybackRate(rate: Float) {
        playbackRate = rate
        exoPlayer.setPlaybackSpeed(rate)
    }

    fun playbackRate(): Float = playbackRate

    fun bufferedFraction(): Float {
        val duration = exoPlayer.duration
        if (duration <= 0) return 0f
        val buffered = exoPlayer.bufferedPosition.coerceAtLeast(0L)
        return (buffered.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
    }

    fun setQuality(option: QualityOption) {
        currentQuality = option
        val parameters = trackSelector.buildUponParameters()
        if (option.height <= 0) {
            parameters.clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            parameters.setForceHighestSupportedBitrate(false)
            parameters.setMaxVideoSize(Int.MAX_VALUE, Int.MAX_VALUE)
        } else {
            parameters.setMaxVideoSize(Int.MAX_VALUE, option.height)
            parameters.setForceHighestSupportedBitrate(true)
        }
        trackSelector.setParameters(parameters)
        emit(PlayerEvent.QualityChanged(option))
    }

    fun availableQualities(): List<QualityOption> {
        val heights = linkedSetOf<Int>()
        val tracks = exoPlayer.currentTracks
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_VIDEO) continue
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                if (format.height > 0) heights += format.height
            }
        }
        return listOf(QualityOption.AUTO) + heights.sortedDescending().map {
            QualityOption(height = it, label = "${it}p")
        }
    }

    fun availableSubtitles(): List<SubtitleTrack> {
        val result = mutableListOf<SubtitleTrack>()
        val tracks = exoPlayer.currentTracks
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_TEXT) continue
            for (i in 0 until group.length) {
                if (!group.isTrackSupported(i)) continue
                val format = group.getTrackFormat(i)
                val lang = format.language ?: "und"
                result += SubtitleTrack(
                    id = "$lang-$i",
                    language = lang,
                    label = format.label ?: lang.uppercase(),
                )
            }
        }
        // Also include externally supplied subtitle metadata for the current item.
        currentItem()?.subtitleTracks?.forEach { external ->
            if (result.none { it.language.equals(external.language, ignoreCase = true) }) {
                result += external
            }
        }
        return result
    }

    fun setSubtitle(track: SubtitleTrack?) {
        selectedSubtitle = track
        val builder = trackSelector.buildUponParameters()
            .clearOverridesOfType(C.TRACK_TYPE_TEXT)

        if (track == null) {
            builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            trackSelector.setParameters(builder)
            emit(PlayerEvent.SubtitleChanged(null))
            return
        }

        builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
        val tracks = exoPlayer.currentTracks
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_TEXT) continue
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val lang = format.language ?: "und"
                if (lang.equals(track.language, ignoreCase = true) ||
                    "${lang}-$i" == track.id
                ) {
                    builder.addOverride(TrackSelectionOverride(group.mediaTrackGroup, i))
                    trackSelector.setParameters(builder)
                    emit(PlayerEvent.SubtitleChanged(track))
                    return
                }
            }
        }

        trackSelector.setParameters(builder)
        emit(PlayerEvent.SubtitleChanged(track))
    }

    fun currentItem(): VideoItem? {
        val id = exoPlayer.currentMediaItem?.mediaId ?: return null
        return playlist.firstOrNull { it.id == id }
    }

    fun currentPositionMs(): Long = exoPlayer.currentPosition

    fun durationMs(): Long = exoPlayer.duration.coerceAtLeast(0L)

    fun isPlaying(): Boolean = exoPlayer.isPlaying

    fun release() {
        stopProgressTicker()
        listeners.clear()
        exoPlayer.release()
    }

    private fun VideoItem.toMediaItem(): MediaItem {
        val builder = MediaItem.Builder()
            .setMediaId(id)
            .setUri(url)
            .setMediaMetadata(
                androidx.media3.common.MediaMetadata.Builder()
                    .setTitle(title)
                    .build(),
            )

        if (subtitleTracks.isNotEmpty()) {
            val subtitleConfigs = subtitleTracks.mapNotNull { track ->
                val subtitleUrl = track.url ?: return@mapNotNull null
                MediaItem.SubtitleConfiguration.Builder(android.net.Uri.parse(subtitleUrl))
                    .setMimeType(guessSubtitleMime(subtitleUrl))
                    .setLanguage(track.language)
                    .setLabel(track.label)
                    .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                    .build()
            }
            builder.setSubtitleConfigurations(subtitleConfigs)
        }

        return builder.build()
    }

    private fun guessSubtitleMime(url: String): String {
        return when {
            url.endsWith(".vtt", ignoreCase = true) -> MimeTypes.TEXT_VTT
            url.endsWith(".srt", ignoreCase = true) -> MimeTypes.APPLICATION_SUBRIP
            else -> MimeTypes.TEXT_VTT
        }
    }

    private fun startProgressTicker() {
        stopProgressTicker()
        val runnable = object : Runnable {
            override fun run() {
                emit(
                    PlayerEvent.Progress(
                        positionMs = exoPlayer.currentPosition,
                        durationMs = exoPlayer.duration.coerceAtLeast(0L),
                    ),
                )
                mainHandler.postDelayed(this, 500L)
            }
        }
        progressRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun stopProgressTicker() {
        progressRunnable?.let { mainHandler.removeCallbacks(it) }
        progressRunnable = null
    }

    private fun emit(event: PlayerEvent) {
        listeners.toList().forEach { it(event) }
    }
}
