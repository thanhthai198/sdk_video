package com.videosdk.flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.videosdk.player.PlayerEvent
import com.videosdk.player.VideoItem
import com.videosdk.player.VideoPlayer

class VideosdkPlayerPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var player: VideoPlayer? = null
    private var events: EventChannel.EventSink? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    companion object {
        var sharedPlayer: VideoPlayer? = null
        var pendingView: VideosdkPlayerView? = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        channel = MethodChannel(binding.binaryMessenger, "videosdk_player")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "videosdk_player_events")
        eventChannel.setStreamHandler(this)

        binding.platformViewRegistry.registerViewFactory(
            "videosdk_player_view",
            VideosdkPlayerViewFactory(),
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val context = flutterPluginBinding?.applicationContext
            ?: return result.error("no_context", null, null)

        val engine = player ?: VideoPlayer(context).also { created ->
            created.addListener { emit(it) }
            player = created
            sharedPlayer = created
            pendingView?.attach(created)
        }

        when (call.method) {
            "setPlaylist" -> {
                val args = call.arguments as Map<*, *>
                val items = (args["items"] as List<*>).mapNotNull { raw ->
                    val map = raw as? Map<*, *> ?: return@mapNotNull null
                    VideoItem(
                        id = map["id"] as? String ?: return@mapNotNull null,
                        url = map["url"] as? String ?: return@mapNotNull null,
                        title = map["title"] as? String ?: "",
                    )
                }
                val startIndex = (args["startIndex"] as? Number)?.toInt() ?: 0
                engine.setPlaylist(items, startIndex)
                pendingView?.attach(engine)
                result.success(null)
            }
            "play" -> { engine.play(); result.success(null) }
            "pause" -> { engine.pause(); result.success(null) }
            "togglePlayPause" -> { engine.togglePlayPause(); result.success(null) }
            "next" -> { engine.next(); result.success(null) }
            "previous" -> { engine.previous(); result.success(null) }
            "seekTo" -> {
                val ms = ((call.arguments as Map<*, *>)["positionMs"] as Number).toLong()
                engine.seekTo(ms)
                result.success(null)
            }
            "setPlaybackRate" -> {
                val rate = ((call.arguments as Map<*, *>)["rate"] as Number).toFloat()
                engine.setPlaybackRate(rate)
                result.success(null)
            }
            "setAutoplay" -> {
                engine.isAutoplayEnabled = (call.arguments as Map<*, *>)["enabled"] as Boolean
                result.success(null)
            }
            "setLoop" -> {
                engine.isLoopEnabled = (call.arguments as Map<*, *>)["enabled"] as Boolean
                result.success(null)
            }
            "release" -> {
                engine.release()
                player = null
                sharedPlayer = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun emit(event: PlayerEvent) {
        val map = HashMap<String, Any?>()
        when (event) {
            PlayerEvent.Ready -> map["type"] = "ready"
            is PlayerEvent.Progress -> {
                map["type"] = "progress"
                map["positionMs"] = event.positionMs
                map["durationMs"] = event.durationMs
            }
            is PlayerEvent.PlayingChanged -> {
                map["type"] = "playingChanged"
                map["isPlaying"] = event.isPlaying
            }
            PlayerEvent.Ended -> map["type"] = "ended"
            is PlayerEvent.Error -> {
                map["type"] = "error"
                map["message"] = event.message
            }
            else -> map["type"] = "other"
        }
        events?.success(map)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        player?.release()
        player = null
        sharedPlayer = null
    }
}
