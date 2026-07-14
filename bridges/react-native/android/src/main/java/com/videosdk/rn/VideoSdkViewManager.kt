package com.videosdk.rn

import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext

class VideoSdkViewManager(
    private val reactContext: ReactApplicationContext,
) : SimpleViewManager<PlayerView>() {

    override fun getName(): String = "VideoSdkView"

    override fun createViewInstance(reactContext: ThemedReactContext): PlayerView {
        val view = PlayerView(reactContext)
        view.useController = false
        // Attach shared engine when ready
        VideoSdkPlayerModule.sharedPlayer?.attach(view)
            ?: run {
                // Player module may create engine later; sample apps should call setPlaylist after mount.
            }
        // Keep latest surface for late attach
        pendingView = view
        VideoSdkPlayerModule.sharedPlayer?.let { it.attach(view) }
        return view
    }

    override fun onDropViewInstance(view: PlayerView) {
        VideoSdkPlayerModule.sharedPlayer?.detach(view)
        if (pendingView === view) pendingView = null
        super.onDropViewInstance(view)
    }

    companion object {
        @JvmStatic
        var pendingView: PlayerView? = null
    }
}
