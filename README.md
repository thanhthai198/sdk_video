# VideoSDK

SDK phát video theo **Phương án A (Core Native riêng / Wrapper)**:

| Nền tảng | Core player |
|---|---|
| Android | Media3 / ExoPlayer |
| iOS | AVPlayer / AVQueuePlayer |

Hỗ trợ: **play / pause**, **next**, **seek**, **chọn độ phân giải**, **phụ đề**.

Control bar mẫu kiểu **YouTube mobile**:
top (chevron, autoplay, cast, CC, settings) · center (prev / play / next) · bottom (time pill, progress đỏ, fullscreen).

Nhấn **Settings** mở bottom sheet **Cài đặt**: Chất lượng, Tốc độ phát, Phụ đề, Lặp video.

**Thu nhỏ** (chevron xuống): mini player góc bo, play + X, badge playlist. **Nhấn mini player** → phóng to lại.

## Cấu trúc

```text
SDK/
├── android/videosdk/      # Native Android library
├── ios/VideoSDK/          # Native iOS Swift Package
├── bridges/
│   ├── react-native/      # RN bridge skeleton
│   └── flutter/           # Flutter plugin skeleton
├── docs/CROSS_PLATFORM.md # Hướng dẫn RN + Flutter
├── INTEGRATION.md
└── README.md
```

**Muốn đóng gói / gắn vào app khác?** → đọc [INTEGRATION.md](./INTEGRATION.md).  
**React Native / Flutter?** → đọc [docs/CROSS_PLATFORM.md](./docs/CROSS_PLATFORM.md) (skeleton trong `bridges/`).

---

## Yêu cầu

### Android
- Android Studio Ladybug (2024.2+) hoặc mới hơn
- JDK 17
- Android SDK 35 (cài qua SDK Manager)

### iOS
- macOS + Xcode 15+
- (Tuỳ chọn) [XcodeGen](https://github.com/yonaskolb/XcodeGen) nếu muốn regenerate sample project:

```bash
brew install xcodegen
```

---

## Chạy Android sample

1. Mở folder `android` bằng Android Studio:

```bash
open -a "Android Studio" /Users/lpbsmobiledev/Desktop/SDK/android
```

2. Khi Android Studio hỏi, để nó tạo / dùng `local.properties` (đường dẫn SDK).  
   Nếu cần tạo tay:

```bash
echo "sdk.dir=$HOME/Library/Android/sdk" > /Users/lpbsmobiledev/Desktop/SDK/android/local.properties
```

3. Sync Gradle → chọn run configuration **sample** → Run trên emulator/máy thật.

### Chạy bằng terminal

```bash
cd /Users/lpbsmobiledev/Desktop/SDK/android
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties
./gradlew :sample:installDebug
adb shell am start -n com.videosdk.sample/.MainActivity
```

> Cần JDK 17 và `adb` trong PATH. Nếu máy chưa có Java, cài qua Android Studio (Embedded JDK) hoặc:

```bash
brew install --cask temurin@17
```

---

## Chạy iOS sample

Cách nhanh nhất — mở project đã generate sẵn:

```bash
open /Users/lpbsmobiledev/Desktop/SDK/ios/SampleApp/VideoSDKSample.xcodeproj
```

Trong Xcode: chọn simulator (ví dụ **iPhone 17**) → **Run** (⌘R).

Nếu cần regenerate từ `project.yml`:

```bash
cd /Users/lpbsmobiledev/Desktop/SDK/ios/SampleApp
xcodegen generate
open VideoSDKSample.xcodeproj
```

### Chỉ mở library (Swift Package)

```bash
open /Users/lpbsmobiledev/Desktop/SDK/ios/VideoSDK/Package.swift
```

---

## Dùng SDK trong app của bạn

### Android (Gradle)

```kotlin
// settings.gradle.kts
include(":videosdk")
project(":videosdk").projectDir = File("/Users/lpbsmobiledev/Desktop/SDK/android/videosdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":videosdk"))
}
```

```kotlin
val player = VideoPlayer(context)
player.attach(playerView)
player.setPlaylist(
    listOf(
        VideoItem(
            id = "1",
            url = "https://example.com/video.m3u8",
            title = "Demo",
        )
    )
)
player.play()
player.pause()
player.next()
player.seekTo(30_000)
player.setQuality(QualityOption(height = 720, label = "720p"))
player.setSubtitle(null) // tắt phụ đề
```

### iOS (Swift Package)

Trong Xcode: **File → Add Package Dependencies… → Add Local…**  
chọn folder `ios/VideoSDK`.

```swift
import VideoSDK

let player = VideoPlayer()
player.setPlaylist([
    VideoItem(
        id: "1",
        url: URL(string: "https://example.com/video.m3u8")!,
        title: "Demo"
    )
])
player.play()
player.pause()
player.next()
player.seek(to: 30)
player.setQuality(QualityOption(height: 720, label: "720p"))
player.setSubtitle(nil)
```

SwiftUI:

```swift
VideoPlayerView(player: player)
    .aspectRatio(16/9, contentMode: .fit)
```

---

## API nhanh

| Hành vi | Android | iOS |
|---|---|---|
| Play / Pause | `play()` / `pause()` / `togglePlayPause()` | giống |
| Next | `next()` | `next()` |
| Tua | `seekTo(ms)` | `seek(to:)` / `seekBy(_:)` |
| Độ phân giải | `setQuality(...)` | `setQuality(...)` |
| Phụ đề | `setSubtitle(...)` | `setSubtitle(...)` |
| Event | `addListener { }` | `eventHandler = { }` |

Sample dùng stream HLS công khai (Mux / Bitmovin demo) — cần mạng khi chạy.

---

## Ghi chú

- Đây là skeleton Phương án A: logic phát nằm native từng nền tảng, API giống nhau.
- Ưu tiên nguồn **HLS/DASH** để ABR + phụ đề ổn định hơn MP4 progressive.
- Chưa kèm DRM / casting / PiP — có thể mở rộng sau trên cùng wrapper.
