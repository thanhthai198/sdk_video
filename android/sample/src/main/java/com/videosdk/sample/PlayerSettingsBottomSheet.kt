package com.videosdk.sample

import android.graphics.Typeface
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.switchmaterial.SwitchMaterial
import com.videosdk.player.QualityOption
import com.videosdk.player.SubtitleTrack
import com.videosdk.player.VideoPlayer
import kotlin.math.abs

class PlayerSettingsBottomSheet(
    private val activity: MainActivity,
    private val player: VideoPlayer,
) {
    private enum class Page { ROOT, QUALITY, SPEED, CAPTIONS }

    private val speeds = listOf(0.25f, 0.5f, 0.75f, 1f, 1.25f, 1.5f, 1.75f, 2f)

    fun show() {
        val dialog = BottomSheetDialog(activity)
        val view = LayoutInflater.from(activity).inflate(R.layout.bottom_sheet_settings, null)
        dialog.setContentView(view)

        val title = view.findViewById<TextView>(R.id.settingsTitle)
        val back = view.findViewById<ImageButton>(R.id.settingsBackButton)
        val close = view.findViewById<ImageButton>(R.id.settingsCloseButton)
        val rootPage = view.findViewById<LinearLayout>(R.id.settingsRootPage)
        val detailList = view.findViewById<RecyclerView>(R.id.settingsDetailList)
        val qualityValue = view.findViewById<TextView>(R.id.qualityValue)
        val speedValue = view.findViewById<TextView>(R.id.speedValue)
        val captionsValue = view.findViewById<TextView>(R.id.captionsValue)
        val loopSwitch = view.findViewById<SwitchMaterial>(R.id.loopSwitch)

        detailList.layoutManager = LinearLayoutManager(activity)

        fun bindRoot() {
            qualityValue.text = player.currentQuality().label
            speedValue.text = speedLabel(player.playbackRate())
            captionsValue.text = player.selectedSubtitle()?.label ?: "Tắt"
            loopSwitch.isChecked = player.isLoopEnabled
        }

        fun showPage(page: Page) {
            val isRoot = page == Page.ROOT
            rootPage.isVisible = isRoot
            detailList.isVisible = !isRoot
            back.visibility = if (isRoot) View.INVISIBLE else View.VISIBLE
            title.text = when (page) {
                Page.ROOT -> "Cài đặt"
                Page.QUALITY -> "Chất lượng"
                Page.SPEED -> "Tốc độ phát"
                Page.CAPTIONS -> "Phụ đề"
            }

            if (isRoot) {
                bindRoot()
                return
            }

            val options = when (page) {
                Page.QUALITY -> player.availableQualities().ifEmpty { listOf(QualityOption.AUTO) }.map {
                    OptionItem(
                        title = it.label,
                        subtitle = if (it.height <= 0) "Khuyến nghị" else null,
                        selected = it == player.currentQuality(),
                        onClick = {
                            player.setQuality(it)
                            dialog.dismiss()
                        },
                    )
                }
                Page.SPEED -> speeds.map { rate ->
                    OptionItem(
                        title = speedLabel(rate),
                        subtitle = null,
                        selected = abs(player.playbackRate() - rate) < 0.001f,
                        onClick = {
                            player.setPlaybackRate(rate)
                            dialog.dismiss()
                        },
                    )
                }
                Page.CAPTIONS -> {
                    val tracks = listOf<SubtitleTrack?>(null) + player.availableSubtitles()
                    tracks.map { track ->
                        OptionItem(
                            title = track?.label ?: "Tắt",
                            subtitle = track?.language?.uppercase(),
                            selected = player.selectedSubtitle()?.id == track?.id,
                            onClick = {
                                player.setSubtitle(track)
                                dialog.dismiss()
                            },
                        )
                    }
                }
                Page.ROOT -> emptyList()
            }
            detailList.adapter = OptionsAdapter(options)
        }

        view.findViewById<View>(R.id.rowQuality).setOnClickListener { showPage(Page.QUALITY) }
        view.findViewById<View>(R.id.rowSpeed).setOnClickListener { showPage(Page.SPEED) }
        view.findViewById<View>(R.id.rowCaptions).setOnClickListener { showPage(Page.CAPTIONS) }
        loopSwitch.setOnCheckedChangeListener { _, checked ->
            player.isLoopEnabled = checked
        }
        back.setOnClickListener { showPage(Page.ROOT) }
        close.setOnClickListener { dialog.dismiss() }

        showPage(Page.ROOT)
        dialog.show()
    }

    private fun speedLabel(rate: Float): String {
        if (abs(rate - 1f) < 0.001f) return "Bình thường"
        return if (rate == rate.toInt().toFloat()) "${rate.toInt()}x" else "${rate}x"
    }

    private data class OptionItem(
        val title: String,
        val subtitle: String?,
        val selected: Boolean,
        val onClick: () -> Unit,
    )

    private class OptionsAdapter(
        private val items: List<OptionItem>,
    ) : RecyclerView.Adapter<OptionsAdapter.VH>() {
        class VH(view: View) : RecyclerView.ViewHolder(view) {
            val title: TextView = view.findViewById(R.id.optionTitle)
            val subtitle: TextView = view.findViewById(R.id.optionSubtitle)
            val check: ImageView = view.findViewById(R.id.optionCheck)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_settings_option, parent, false)
            return VH(view)
        }

        override fun getItemCount(): Int = items.size

        override fun onBindViewHolder(holder: VH, position: Int) {
            val item = items[position]
            holder.title.text = item.title
            holder.title.setTypeface(null, if (item.selected) Typeface.BOLD else Typeface.NORMAL)
            if (item.subtitle.isNullOrBlank()) {
                holder.subtitle.isVisible = false
            } else {
                holder.subtitle.isVisible = true
                holder.subtitle.text = item.subtitle
            }
            holder.check.isVisible = item.selected
            holder.itemView.setOnClickListener { item.onClick() }
        }
    }
}
