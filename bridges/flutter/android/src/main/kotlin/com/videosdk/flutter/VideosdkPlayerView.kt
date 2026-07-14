package com.videosdk.flutter

import android.content.Context
import android.view.View
import androidx.media3.ui.PlayerView
import com.videosdk.player.VideoPlayer
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VideosdkPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return VideosdkPlayerView(context)
    }
}

class VideosdkPlayerView(context: Context) : PlatformView {
    private val playerView = PlayerView(context).apply {
        useController = false
    }

    init {
        VideosdkPlayerPlugin.pendingView = this
        VideosdkPlayerPlugin.sharedPlayer?.let { attach(it) }
    }

    fun attach(player: VideoPlayer) {
        player.attach(playerView)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        VideosdkPlayerPlugin.sharedPlayer?.detach(playerView)
        if (VideosdkPlayerPlugin.pendingView === this) {
            VideosdkPlayerPlugin.pendingView = null
        }
    }
}
