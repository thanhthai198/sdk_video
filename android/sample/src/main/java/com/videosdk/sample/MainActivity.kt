package com.videosdk.sample

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.view.isVisible
import com.videosdk.player.PlayerEvent
import com.videosdk.player.SubtitleTrack
import com.videosdk.player.VideoItem
import com.videosdk.player.VideoPlayer
import com.videosdk.sample.databinding.ActivityMainBinding
import java.util.Locale
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var player: VideoPlayer

    private var isScrubbing = false
    private var isFullscreen = false
    private var isMiniplayer = false
    private var controlsVisible = true
    private val hideControlsRunnable = Runnable { hideControlsIfPlaying() }

    private val demoPlaylist = listOf(
        VideoItem(
            id = "big-buck-bunny",
            url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            title = "Big Buck Bunny (HLS)",
            subtitleTracks = listOf(
                SubtitleTrack(
                    id = "en",
                    language = "en",
                    label = "English",
                    url = "https://bitdash-a.akamaihd.net/content/sintel/subtitles/subtitles_en.vtt",
                ),
            ),
        ),
        VideoItem(
            id = "sintel",
            url = "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8",
            title = "Sintel (HLS)",
        ),
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val chrome = binding.playerChrome
        val mini = binding.miniPlayer

        player = VideoPlayer(this)
        player.attach(chrome.playerView)
        player.addListener(::onPlayerEvent)
        player.setPlaylist(demoPlaylist)

        mini.miniBadgeText.text = "${demoPlaylist.size} video"
        mini.miniTitleText.text = demoPlaylist.first().title

        chrome.playPauseButton.setOnClickListener {
            player.togglePlayPause()
            bumpControls()
        }
        chrome.previousButton.setOnClickListener {
            player.previous()
            bumpControls()
        }
        chrome.nextButton.setOnClickListener {
            player.next()
            bumpControls()
        }
        chrome.autoplayButton.setOnClickListener {
            player.isAutoplayEnabled = !player.isAutoplayEnabled
            updateAutoplayUI()
            bumpControls()
        }
        chrome.castButton.setOnClickListener {
            Toast.makeText(this, "Cast chưa cấu hình trong sample", Toast.LENGTH_SHORT).show()
            bumpControls()
        }
        chrome.subtitleButton.setOnClickListener {
            bumpControls()
            PlayerSettingsBottomSheet(this, player).show()
        }
        chrome.settingsButton.setOnClickListener {
            bumpControls()
            PlayerSettingsBottomSheet(this, player).show()
        }
        chrome.minimizeButton.setOnClickListener {
            enterMiniplayer()
        }
        chrome.fullscreenButton.setOnClickListener {
            toggleFullscreen()
            bumpControls()
        }
        chrome.playerContainer.setOnClickListener {
            if (controlsVisible) hideControls() else bumpControls()
        }

        // Mini player interactions
        mini.root.setOnClickListener { expandFromMiniplayer() }
        mini.miniPlayButton.setOnClickListener {
            player.togglePlayPause()
            updateMiniPlayIcon()
        }
        mini.miniCloseButton.setOnClickListener {
            player.pause()
            exitMiniplayer(keepBrowsing = true)
        }

        chrome.progressBar.setOnSeekBarChangeListener(
            object : android.widget.SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(
                    seekBar: android.widget.SeekBar?,
                    progress: Int,
                    fromUser: Boolean,
                ) {
                    if (!fromUser) return
                    val duration = player.durationMs()
                    if (duration > 0) {
                        val pos = duration * progress / 1000L
                        chrome.timeText.text = formatTimePair(pos, duration)
                    }
                }

                override fun onStartTrackingTouch(seekBar: android.widget.SeekBar?) {
                    isScrubbing = true
                    chrome.controlsOverlay.removeCallbacks(hideControlsRunnable)
                }

                override fun onStopTrackingTouch(seekBar: android.widget.SeekBar?) {
                    val duration = player.durationMs()
                    if (duration > 0) {
                        player.seekTo(duration * (seekBar?.progress ?: 0) / 1000L)
                    }
                    isScrubbing = false
                    bumpControls()
                }
            },
        )

        updateAutoplayUI()
        bumpControls()
        binding.miniPlayer.root.isVisible = false
    }

    private fun onPlayerEvent(event: PlayerEvent) {
        val chrome = binding.playerChrome
        when (event) {
            is PlayerEvent.Ready -> Unit
            is PlayerEvent.PlayingChanged -> {
                chrome.playPauseButton.setImageResource(
                    if (event.isPlaying) R.drawable.ic_pause else R.drawable.ic_play,
                )
                updateMiniPlayIcon()
                if (!isMiniplayer) {
                    if (event.isPlaying) bumpControls() else showControls()
                }
            }
            is PlayerEvent.Progress -> {
                if (!isScrubbing && !isMiniplayer) {
                    chrome.timeText.text = formatTimePair(event.positionMs, event.durationMs)
                    if (event.durationMs > 0) {
                        chrome.progressBar.progress =
                            ((event.positionMs * 1000L) / event.durationMs).toInt().coerceIn(0, 1000)
                        chrome.progressBar.secondaryProgress =
                            (player.bufferedFraction() * 1000f).toInt().coerceIn(0, 1000)
                    }
                }
            }
            is PlayerEvent.MediaItemTransition -> {
                val title = event.item?.title ?: "VideoSDK Sample"
                binding.titleText.text = title
                binding.miniPlayer.miniTitleText.text = title
            }
            is PlayerEvent.QualityChanged -> {
                Toast.makeText(this, "Quality: ${event.option.label}", Toast.LENGTH_SHORT).show()
            }
            is PlayerEvent.SubtitleChanged -> {
                Toast.makeText(
                    this,
                    "Subtitle: ${event.track?.label ?: "Off"}",
                    Toast.LENGTH_SHORT,
                ).show()
            }
            is PlayerEvent.Error -> {
                Toast.makeText(this, event.message, Toast.LENGTH_SHORT).show()
            }
            PlayerEvent.Ended -> Unit
        }
    }

    private fun updateMiniPlayIcon() {
        binding.miniPlayer.miniPlayButton.setImageResource(
            if (player.isPlaying()) R.drawable.ic_pause else R.drawable.ic_play,
        )
    }

    private fun updateAutoplayUI() {
        val chrome = binding.playerChrome
        chrome.autoplayTrack.setBackgroundResource(
            if (player.isAutoplayEnabled) R.drawable.autoplay_track_on else R.drawable.autoplay_track_off,
        )
        chrome.autoplayThumb.translationX =
            if (player.isAutoplayEnabled) dp(8).toFloat() else -dp(8).toFloat()
    }

    private fun enterMiniplayer() {
        isFullscreen = false
        isMiniplayer = true
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED

        player.detach(binding.playerChrome.playerView)
        player.attach(binding.miniPlayer.miniPlayerView)

        binding.playerChrome.root.isVisible = false
        binding.titleText.isVisible = false
        binding.statusText.isVisible = false
        binding.miniPlayer.root.isVisible = true
        updateMiniPlayIcon()
        binding.miniPlayer.miniTitleText.text = player.currentItem()?.title.orEmpty()
    }

    private fun expandFromMiniplayer() {
        exitMiniplayer(keepBrowsing = false)
    }

    private fun exitMiniplayer(keepBrowsing: Boolean) {
        isMiniplayer = false
        player.detach(binding.miniPlayer.miniPlayerView)
        player.attach(binding.playerChrome.playerView)

        binding.miniPlayer.root.isVisible = false
        binding.playerChrome.root.isVisible = true
        binding.titleText.isVisible = true
        binding.statusText.isVisible = true
        applyNormalOrFullscreenLayout()

        if (keepBrowsing) {
            // Already restored layout; video stays paused.
        } else {
            if (!player.isPlaying()) player.play()
            bumpControls()
        }
    }

    private fun toggleFullscreen() {
        if (isMiniplayer) {
            expandFromMiniplayer()
        }
        isFullscreen = !isFullscreen
        requestedOrientation = if (isFullscreen) {
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else {
            ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        binding.titleText.isVisible = !isFullscreen
        binding.statusText.isVisible = !isFullscreen
        applyNormalOrFullscreenLayout()
    }

    private fun applyNormalOrFullscreenLayout() {
        val params = binding.playerChrome.root.layoutParams as ConstraintLayout.LayoutParams
        if (isFullscreen) {
            params.dimensionRatio = null
            params.width = 0
            params.height = 0
            params.topToTop = ConstraintLayout.LayoutParams.PARENT_ID
            params.bottomToBottom = ConstraintLayout.LayoutParams.PARENT_ID
            params.startToStart = ConstraintLayout.LayoutParams.PARENT_ID
            params.endToEnd = ConstraintLayout.LayoutParams.PARENT_ID
            params.verticalBias = 0.5f
            params.setMargins(0, 0, 0, 0)
        } else {
            params.dimensionRatio = "16:9"
            params.width = 0
            params.height = 0
            params.topToTop = ConstraintLayout.LayoutParams.PARENT_ID
            params.bottomToBottom = ConstraintLayout.LayoutParams.UNSET
            params.startToStart = ConstraintLayout.LayoutParams.PARENT_ID
            params.endToEnd = ConstraintLayout.LayoutParams.PARENT_ID
            params.verticalBias = 0f
            params.setMargins(0, 0, 0, 0)
        }
        binding.playerChrome.root.layoutParams = params
    }

    private fun bumpControls() {
        if (isMiniplayer) return
        showControls()
        val overlay = binding.playerChrome.controlsOverlay
        overlay.removeCallbacks(hideControlsRunnable)
        if (player.isPlaying()) {
            overlay.postDelayed(hideControlsRunnable, 3000L)
        }
    }

    private fun showControls() {
        controlsVisible = true
        val overlay = binding.playerChrome.controlsOverlay
        overlay.isVisible = true
        overlay.animate().alpha(1f).setDuration(160).start()
    }

    private fun hideControls() {
        controlsVisible = false
        val overlay = binding.playerChrome.controlsOverlay
        overlay.animate().alpha(0f).setDuration(160).withEndAction {
            if (!controlsVisible) overlay.isVisible = false
        }.start()
    }

    private fun hideControlsIfPlaying() {
        if (player.isPlaying() && !isScrubbing && !isMiniplayer) hideControls()
    }

    private fun formatTimePair(positionMs: Long, durationMs: Long): String {
        return "${formatTime(positionMs)} / ${formatTime(durationMs)}"
    }

    private fun formatTime(ms: Long): String {
        val totalSeconds = TimeUnit.MILLISECONDS.toSeconds(ms.coerceAtLeast(0L))
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.US, "%d:%02d", minutes, seconds)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onStart() {
        super.onStart()
        if (!isMiniplayer || player.isPlaying()) {
            // Keep current playing state; resume only if previously playing was intended.
        }
        if (!isMiniplayer) player.play()
    }

    override fun onStop() {
        player.pause()
        super.onStop()
    }

    override fun onDestroy() {
        binding.playerChrome.controlsOverlay.removeCallbacks(hideControlsRunnable)
        player.release()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        when {
            isFullscreen -> toggleFullscreen()
            isMiniplayer -> expandFromMiniplayer()
            else -> super.onBackPressed()
        }
    }
}
