import SwiftUI

/// YouTube-style settings bottom sheet (quality / speed / captions / loop).
public struct PlayerSettingsSheet: View {
    public enum Page: Equatable {
        case root
        case quality
        case speed
        case captions
    }

    @ObservedObject var player: VideoPlayer
    @Binding var isPresented: Bool
    @State private var page: Page = .root

    private let speedOptions: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private let sheetBg = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let rowBg = Color.clear
    private let separator = Color.white.opacity(0.08)

    public init(player: VideoPlayer, isPresented: Binding<Bool>) {
        self.player = player
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                header
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                Divider().background(separator)

                Group {
                    switch page {
                    case .root:
                        rootList
                    case .quality:
                        qualityList
                    case .speed:
                        speedList
                    case .captions:
                        captionsList
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(sheetBg)
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.easeOut(duration: 0.22), value: isPresented)
        .animation(.easeInOut(duration: 0.18), value: page)
    }

    private var header: some View {
        HStack {
            if page != .root {
                Button {
                    page = .root
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var title: String {
        switch page {
        case .root: return "Cài đặt"
        case .quality: return "Chất lượng"
        case .speed: return "Tốc độ phát"
        case .captions: return "Phụ đề"
        }
    }

    private var rootList: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "rectangle.connected.to.line.below",
                title: "Chất lượng",
                value: player.currentQuality.label
            ) { page = .quality }

            settingsRow(
                icon: "gauge.medium",
                title: "Tốc độ phát",
                value: speedLabel(player.playbackRate)
            ) { page = .speed }

            settingsRow(
                icon: "captions.bubble",
                title: "Phụ đề",
                value: player.selectedSubtitle?.label ?? "Tắt"
            ) { page = .captions }

            HStack(spacing: 14) {
                Image(systemName: "repeat")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28)

                Text("Lặp video")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: $player.isLoopEnabled)
                    .labelsHidden()
                    .tint(.red)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private var qualityList: some View {
        VStack(spacing: 0) {
            ForEach(player.availableQualities(), id: \.self) { option in
                selectableRow(
                    title: option.label,
                    subtitle: option.height <= 0 ? "Khuyến nghị" : nil,
                    selected: player.currentQuality == option
                ) {
                    player.setQuality(option)
                    dismiss()
                }
            }
        }
    }

    private var speedList: some View {
        VStack(spacing: 0) {
            ForEach(speedOptions, id: \.self) { rate in
                selectableRow(
                    title: speedLabel(rate),
                    subtitle: nil,
                    selected: abs(player.playbackRate - rate) < 0.001
                ) {
                    player.setPlaybackRate(rate)
                    dismiss()
                }
            }
        }
    }

    private var captionsList: some View {
        VStack(spacing: 0) {
            selectableRow(
                title: "Tắt",
                subtitle: nil,
                selected: player.selectedSubtitle == nil
            ) {
                player.setSubtitle(nil)
                dismiss()
            }

            ForEach(player.availableSubtitles()) { track in
                selectableRow(
                    title: track.label,
                    subtitle: track.language.uppercased(),
                    selected: player.selectedSubtitle?.id == track.id
                ) {
                    player.setSubtitle(track)
                    dismiss()
                }
            }
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)

                Spacer()

                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(rowBg)
    }

    private func selectableRow(
        title: String,
        subtitle: String?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: selected ? .semibold : .regular))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func speedLabel(_ rate: Float) -> String {
        if abs(rate - 1) < 0.001 { return "Bình thường" }
        let value = (rate * 100).rounded() / 100
        if value == Float(Int(value)) {
            return "\(Int(value))x"
        }
        return String(format: "%.2gx", value)
    }

    private func dismiss() {
        page = .root
        isPresented = false
    }
}
