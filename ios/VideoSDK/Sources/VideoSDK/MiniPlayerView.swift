import SwiftUI

/// Floating mini-player chrome (rounded card, play + close, tap to expand).
public struct MiniPlayerView: View {
    @ObservedObject var player: VideoPlayer
    public var badgeText: String
    public var onExpand: () -> Void
    public var onClose: () -> Void

    public init(
        player: VideoPlayer,
        badgeText: String = "",
        onExpand: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.player = player
        self.badgeText = badgeText
        self.onExpand = onExpand
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            VideoPlayerView(player: player)
                .allowsHitTesting(false)

            // Soft gradient for text readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.55),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Text(player.currentItem?.title ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                Spacer()

                HStack {
                    miniCircleButton(systemName: player.isPlaying ? "pause.fill" : "play.fill") {
                        player.togglePlayPause()
                    }

                    Spacer()

                    miniCircleButton(systemName: "xmark") {
                        onClose()
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                if !badgeText.isEmpty {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                } else {
                    Color.clear.frame(height: 8)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            onExpand()
        }
    }

    private func miniCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
        .buttonStyle(.plain)
    }
}
