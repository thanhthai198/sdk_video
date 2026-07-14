import SwiftUI

/// YouTube mobile chrome:
/// top: chevron | autoplay · cast · CC · settings
/// center: previous · play · next
/// bottom: time pill · progress · fullscreen
public struct PlayerControlsOverlay: View {
    @ObservedObject var player: VideoPlayer

    public var onSubtitlesTap: () -> Void
    public var onSettingsTap: () -> Void
    public var onCastTap: () -> Void
    public var onMinimizeTap: () -> Void
    public var onFullscreenTap: () -> Void

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    private let accent = Color(red: 1, green: 0, blue: 0)

    public init(
        player: VideoPlayer,
        onSubtitlesTap: @escaping () -> Void = {},
        onSettingsTap: @escaping () -> Void = {},
        onCastTap: @escaping () -> Void = {},
        onMinimizeTap: @escaping () -> Void = {},
        onFullscreenTap: @escaping () -> Void = {}
    ) {
        self.player = player
        self.onSubtitlesTap = onSubtitlesTap
        self.onSettingsTap = onSettingsTap
        self.onCastTap = onCastTap
        self.onMinimizeTap = onMinimizeTap
        self.onFullscreenTap = onFullscreenTap
    }

    public var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }

            if controlsVisible {
                ZStack {
                    // Soft vignette so white icons stay readable
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.65),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        centerTransport
                        Spacer()
                        bottomBar
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: controlsVisible)
        .onAppear { scheduleHide() }
        .onChange(of: player.isPlaying) { _ in scheduleHide() }
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 4) {
            iconButton(systemName: "chevron.down", size: 18) {
                onMinimizeTap()
                bumpVisibility()
            }

            Spacer()

            Button {
                player.isAutoplayEnabled.toggle()
                bumpVisibility()
            } label: {
                AutoplayToggle(isOn: player.isAutoplayEnabled)
            }
            .buttonStyle(.plain)

            iconButton(systemName: "airplayvideo", size: 17) {
                onCastTap()
                bumpVisibility()
            }

            iconButton(systemName: "captions.bubble.fill", size: 17) {
                onSubtitlesTap()
                bumpVisibility()
            }

            iconButton(systemName: "gearshape", size: 17) {
                onSettingsTap()
                bumpVisibility()
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Center

    private var centerTransport: some View {
        HStack(spacing: 36) {
            transportButton(systemName: "backward.end.fill", size: 26) {
                player.previous()
                bumpVisibility()
            }

            Button {
                player.togglePlayPause()
                bumpVisibility()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)

            transportButton(systemName: "forward.end.fill", size: 26) {
                player.next()
                bumpVisibility()
            }
        }
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        VStack(spacing: 6) {
            progressBar

            HStack(alignment: .center) {
                Text(timeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))

                Spacer()

                iconButton(systemName: "arrow.up.left.and.arrow.down.right", size: 16) {
                    onFullscreenTap()
                    bumpVisibility()
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = isScrubbing ? scrubValue : progressFraction
            let buffered = player.bufferedFraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: 3)

                Capsule()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: max(0, width * buffered), height: 3)

                Capsule()
                    .fill(accent)
                    .frame(width: max(0, width * progress), height: 3)

                Circle()
                    .fill(accent)
                    .frame(width: isScrubbing ? 14 : 11, height: isScrubbing ? 14 : 11)
                    .offset(x: max(0, width * progress) - (isScrubbing ? 7 : 5.5))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        hideTask?.cancel()
                        scrubValue = min(max(value.location.x / max(width, 1), 0), 1)
                    }
                    .onEnded { value in
                        let fraction = min(max(value.location.x / max(width, 1), 0), 1)
                        player.seek(to: player.duration * fraction)
                        isScrubbing = false
                        scheduleHide()
                    }
            )
        }
        .frame(height: 18)
    }

    // MARK: - Helpers

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.position / player.duration, 0), 1)
    }

    private var timeLabel: String {
        let current = isScrubbing ? player.duration * scrubValue : player.position
        return "\(Self.formatTime(current)) / \(Self.formatTime(player.duration))"
    }

    private func iconButton(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func transportButton(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleControls() {
        controlsVisible.toggle()
        if controlsVisible {
            scheduleHide()
        } else {
            hideTask?.cancel()
        }
    }

    private func bumpVisibility() {
        controlsVisible = true
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard player.isPlaying else { return }
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, !isScrubbing else { return }
            await MainActor.run { controlsVisible = false }
        }
    }

    public static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

private struct AutoplayToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? Color.white.opacity(0.38) : Color.white.opacity(0.18))
                .frame(width: 34, height: 18)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.black)
                )
                .offset(x: isOn ? 8 : -8)
        }
        .animation(.easeInOut(duration: 0.15), value: isOn)
        .frame(width: 40, height: 36)
        .contentShape(Rectangle())
    }
}

/// Convenience container: video surface + YouTube mobile controls.
public struct ControlledVideoPlayerView: View {
    @ObservedObject var player: VideoPlayer
    public var onSubtitlesTap: () -> Void
    public var onSettingsTap: () -> Void
    public var onCastTap: () -> Void
    public var onMinimizeTap: () -> Void
    public var onFullscreenTap: () -> Void

    public init(
        player: VideoPlayer,
        onSubtitlesTap: @escaping () -> Void = {},
        onSettingsTap: @escaping () -> Void = {},
        onCastTap: @escaping () -> Void = {},
        onMinimizeTap: @escaping () -> Void = {},
        onFullscreenTap: @escaping () -> Void = {}
    ) {
        self.player = player
        self.onSubtitlesTap = onSubtitlesTap
        self.onSettingsTap = onSettingsTap
        self.onCastTap = onCastTap
        self.onMinimizeTap = onMinimizeTap
        self.onFullscreenTap = onFullscreenTap
    }

    public var body: some View {
        ZStack {
            VideoPlayerView(player: player)
            PlayerControlsOverlay(
                player: player,
                onSubtitlesTap: onSubtitlesTap,
                onSettingsTap: onSettingsTap,
                onCastTap: onCastTap,
                onMinimizeTap: onMinimizeTap,
                onFullscreenTap: onFullscreenTap
            )
        }
        .background(Color.black)
    }
}
