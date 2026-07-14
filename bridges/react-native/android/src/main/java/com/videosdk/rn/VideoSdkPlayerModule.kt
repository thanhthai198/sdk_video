package com.videosdk.rn

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.videosdk.player.PlayerEvent
import com.videosdk.player.QualityOption
import com.videosdk.player.SubtitleTrack
import com.videosdk.player.VideoItem
import com.videosdk.player.VideoPlayer

class VideoSdkPlayerModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {

    companion object {
        @JvmStatic
        var sharedPlayer: VideoPlayer? = null
    }

    override fun getName(): String = "VideoSdkPlayer"

    private fun player(): VideoPlayer {
        val existing = sharedPlayer
        if (existing != null) return existing
        val created = VideoPlayer(reactContext).also { p ->
            p.addListener { event -> emit(event) }
            sharedPlayer = p
        }
        return created
    }

    @ReactMethod
    fun setPlaylist(items: ReadableArray, startIndex: Int, promise: Promise) {
        try {
            val list = mutableListOf<VideoItem>()
            for (i in 0 until items.size()) {
                val map = items.getMap(i) ?: continue
                list += map.toVideoItem()
            }
            player().setPlaylist(list, startIndex)
            VideoSdkViewManager.pendingView?.let { player().attach(it) }
            promise.resolve(null)
        } catch (t: Throwable) {
            promise.reject("playlist_error", t)
        }
    }

    @ReactMethod fun play(promise: Promise) = run(promise) { player().play() }
    @ReactMethod fun pause(promise: Promise) = run(promise) { player().pause() }
    @ReactMethod fun togglePlayPause(promise: Promise) = run(promise) { player().togglePlayPause() }
    @ReactMethod fun next(promise: Promise) = run(promise) { player().next() }
    @ReactMethod fun previous(promise: Promise) = run(promise) { player().previous() }

    @ReactMethod
    fun seekTo(positionMs: Double, promise: Promise) = run(promise) {
        player().seekTo(positionMs.toLong())
    }

    @ReactMethod
    fun setPlaybackRate(rate: Double, promise: Promise) = run(promise) {
        player().setPlaybackRate(rate.toFloat())
    }

    @ReactMethod
    fun setAutoplay(enabled: Boolean, promise: Promise) = run(promise) {
        player().isAutoplayEnabled = enabled
    }

    @ReactMethod
    fun setLoop(enabled: Boolean, promise: Promise) = run(promise) {
        player().isLoopEnabled = enabled
    }

    @ReactMethod
    fun setQuality(option: ReadableMap, promise: Promise) = run(promise) {
        player().setQuality(
            QualityOption(
                height = option.getInt("height"),
                label = option.getString("label") ?: "${option.getInt("height")}p",
            ),
        )
    }

    @ReactMethod
    fun setSubtitle(track: ReadableMap?, promise: Promise) = run(promise) {
        if (track == null) {
            player().setSubtitle(null)
        } else {
            player().setSubtitle(
                SubtitleTrack(
                    id = track.getString("id") ?: "",
                    language = track.getString("language") ?: "und",
                    label = track.getString("label") ?: "",
                    url = track.getString("url"),
                ),
            )
        }
    }

    @ReactMethod
    fun release(promise: Promise) = run(promise) {
        sharedPlayer?.release()
        sharedPlayer = null
    }

    @ReactMethod
    fun addListener(eventName: String) {
        // Required for NativeEventEmitter
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        // Required for NativeEventEmitter
    }

    private fun run(promise: Promise, block: () -> Unit) {
        try {
            block()
            promise.resolve(null)
        } catch (t: Throwable) {
            promise.reject("videosdk_error", t)
        }
    }

    private fun emit(event: PlayerEvent) {
        val map: WritableMap = Arguments.createMap()
        when (event) {
            PlayerEvent.Ready -> map.putString("type", "ready")
            is PlayerEvent.Progress -> {
                map.putString("type", "progress")
                map.putDouble("positionMs", event.positionMs.toDouble())
                map.putDouble("durationMs", event.durationMs.toDouble())
            }
            is PlayerEvent.PlayingChanged -> {
                map.putString("type", "playingChanged")
                map.putBoolean("isPlaying", event.isPlaying)
            }
            is PlayerEvent.Error -> {
                map.putString("type", "error")
                map.putString("message", event.message)
            }
            PlayerEvent.Ended -> map.putString("type", "ended")
            is PlayerEvent.QualityChanged -> {
                map.putString("type", "qualityChanged")
                map.putString("label", event.option.label)
            }
            is PlayerEvent.SubtitleChanged -> {
                map.putString("type", "subtitleChanged")
                map.putString("label", event.track?.label)
            }
            is PlayerEvent.MediaItemTransition -> {
                map.putString("type", "mediaItemTransition")
                map.putString("id", event.item?.id)
                map.putString("title", event.item?.title)
            }
        }
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("VideoSdkPlayerEvent", map)
    }

    private fun ReadableMap.toVideoItem(): VideoItem {
        val subs = mutableListOf<SubtitleTrack>()
        if (hasKey("subtitleTracks")) {
            val arr = getArray("subtitleTracks")
            if (arr != null) {
                for (i in 0 until arr.size()) {
                    val s = arr.getMap(i) ?: continue
                    subs += SubtitleTrack(
                        id = s.getString("id") ?: "",
                        language = s.getString("language") ?: "und",
                        label = s.getString("label") ?: "",
                        url = s.getString("url"),
                    )
                }
            }
        }
        return VideoItem(
            id = getString("id") ?: "",
            url = getString("url") ?: "",
            title = getString("title") ?: "",
            subtitleTracks = subs,
        )
    }
}
