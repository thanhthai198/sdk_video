import SwiftUI
import VideoSDK

@main
struct SampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @StateObject private var player = VideoPlayer()
    @State private var showSettings = false
    @State private var isFullscreen = false
    @State private var isMiniplayer = false
    @State private var toast: String?

    private let playlist: [VideoItem] = [
        VideoItem(
            id: "big-buck-bunny",
            url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
            title: "Big Buck Bunny (HLS)",
            subtitleTracks: [
                SubtitleTrack(id: "en", language: "en", label: "English"),
            ]
        ),
        VideoItem(
            id: "sintel",
            url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!,
            title: "Sintel (HLS)"
        ),
    ]

    private var playlistBadge: String {
        "\(playlist.count) video"
    }

    var body: some View {
        ZStack {
            // Fake app background behind mini player
            backgroundContent
                .opacity(isMiniplayer ? 1 : 0)
                .allowsHitTesting(isMiniplayer)

            if isFullscreen {
                playerSurface(isFullscreenMode: true)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else if !isMiniplayer {
                VStack(spacing: 0) {
                    playerSurface(isFullscreenMode: false)
                        .aspectRatio(16 / 9, contentMode: .fit)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.currentItem?.title ?? "VideoSDK Sample")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Chevron xuống → thu nhỏ. Nhấn mini player → phóng to.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
                .transition(.opacity)
            }

            if isMiniplayer {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniPlayerView(
                            player: player,
                            badgeText: playlistBadge,
                            onExpand: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    isMiniplayer = false
                                }
                            },
                            onClose: {
                                player.pause()
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isMiniplayer = false
                                }
                                // Close = dismiss mini + stay on browse background
                            }
                        )
                        .frame(width: 210)
                        .padding(.trailing, 14)
                        .padding(.bottom, 18)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            if showSettings {
                PlayerSettingsSheet(player: player, isPresented: $showSettings)
                    .zIndex(20)
            }

            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.opacity)
                    .zIndex(30)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isMiniplayer)
        .onAppear {
            player.setPlaylist(playlist)
            player.play()
        }
        .statusBarHidden(isFullscreen)
    }

    private var backgroundContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Danh sách xem")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 56)

                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 88)
                        .overlay(
                            HStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 120, height: 68)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Video gợi ý \(index + 1)")
                                        .foregroundStyle(.white)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Nhấn mini player để phóng to")
                                        .foregroundStyle(.white.opacity(0.5))
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 140)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func playerSurface(isFullscreenMode: Bool) -> some View {
        ControlledVideoPlayerView(
            player: player,
            onSubtitlesTap: { showSettings = true },
            onSettingsTap: { showSettings = true },
            onCastTap: { showToast("Cast chưa cấu hình trong sample") },
            onMinimizeTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    if isFullscreenMode {
                        isFullscreen = false
                        isMiniplayer = true
                    } else {
                        isMiniplayer = true
                    }
                }
            },
            onFullscreenTap: {
                withAnimation {
                    if isFullscreenMode {
                        isFullscreen = false
                    } else {
                        isMiniplayer = false
                        isFullscreen = true
                    }
                }
            }
        )
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation { toast = nil }
            }
        }
    }
}
