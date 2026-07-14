# Hướng dẫn build & tích hợp VideoSDK

Tài liệu này hướng dẫn **đóng gói** VideoSDK và **tích hợp** vào app Android / iOS khác.

| Nền tảng | Artifact phân phối | Cách tích hợp phổ biến |
|---|---|---|
| **Android** | `.aar` (+ dependency Media3) | Module local / Maven / file AAR |
| **iOS** | Swift Package / XCFramework | SPM local / SPM Git / XCFramework |

> Sample UI (YouTube controls, settings sheet, mini player) nằm ở **sample app**.  
> Module library chính: `android/videosdk` và `ios/VideoSDK`.

---

## 1. Cấu trúc cần biết

```text
SDK/
├── android/
│   └── videosdk/          ← Library Android (com.videosdk.player)
├── ios/
│   └── VideoSDK/          ← Swift Package (import VideoSDK)
└── docs/ — (bạn đang đọc INTEGRATION.md ở root)
```

---

## 2. Android — Build SDK

### 2.1. Yêu cầu

- JDK **17**
- Android SDK (compileSdk **35**)
- Đường dẫn SDK trong `android/local.properties`:

```properties
sdk.dir=/Users/<you>/Library/Android/sdk
```

### 2.2. Build AAR (release)

```bash
cd /Users/lpbsmobiledev/Desktop/SDK/android
./gradlew :videosdk:assembleRelease
```

File output:

```text
android/videosdk/build/outputs/aar/videosdk-release.aar
```

Debug AAR (nếu cần):

```bash
./gradlew :videosdk:assembleDebug
# → android/videosdk/build/outputs/aar/videosdk-debug.aar
```

### 2.3. Publish lên Maven Local (khuyến nghị khi test nhiều app)

Thêm tạm vào `android/videosdk/build.gradle.kts` (nếu chưa có):

```kotlin
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

android {
    // ... giữ nguyên config hiện tại
    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
                groupId = "com.videosdk"
                artifactId = "player"
                version = "1.0.0"
            }
        }
        repositories {
            mavenLocal()
        }
    }
}
```

Rồi chạy:

```bash
cd /Users/lpbsmobiledev/Desktop/SDK/android
./gradlew :videosdk:publishReleasePublicationToMavenLocalRepository
```

Artifact sẽ nằm trong `~/.m2/repository/com/videosdk/player/1.0.0/`.

---

## 3. Android — Tích hợp vào project khác

Chọn **một** trong các cách dưới đây.

### Cách A — Module source (nhanh nhất khi cùng monorepo)

Trong app đích, `settings.gradle.kts`:

```kotlin
include(":videosdk")
project(":videosdk").projectDir =
    File("/Users/lpbsmobiledev/Desktop/SDK/android/videosdk")
```

`app/build.gradle.kts`:

```kotlin
dependencies {
    implementation(project(":videosdk"))
}
```

### Cách B — Maven Local

`settings.gradle.kts` (hoặc `dependencyResolutionManagement`):

```kotlin
repositories {
    google()
    mavenCentral()
    mavenLocal()
}
```

`app/build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.videosdk:player:1.0.0")
}
```

> Library đang dùng `api(...)` với Media3 → app **không cần** khai báo lại Media3 cho ExoPlayer trừ khi dùng thêm API Media3 khác.

### Cách C — File AAR thủ công

1. Copy `videosdk-release.aar` vào app, ví dụ `app/libs/`.
2. `app/build.gradle.kts`:

```kotlin
dependencies {
    implementation(files("libs/videosdk-release.aar"))

    // Bắt buộc khi dùng AAR thuần (transitive deps không đi kèm trừ khi publish Maven)
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.5.1")
    implementation("androidx.media3:media3-exoplayer-dash:1.5.1")
    implementation("androidx.media3:media3-ui:1.5.1")
    implementation("androidx.media3:media3-session:1.5.1")
    implementation("androidx.core:core-ktx:1.15.0")
}
```

**Lưu ý:** Cách A/B tốt hơn cách C vì giữ được transitive dependencies.

### Android — Code tích hợp tối thiểu

`AndroidManifest.xml` (app):

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Layout:

```xml
<androidx.media3.ui.PlayerView
    android:id="@+id/playerView"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    app:use_controller="false" />
```

Kotlin:

```kotlin
import com.videosdk.player.VideoItem
import com.videosdk.player.VideoPlayer

val player = VideoPlayer(this)
player.attach(binding.playerView)
player.setPlaylist(
    listOf(
        VideoItem(
            id = "1",
            url = "https://example.com/stream.m3u8",
            title = "Demo",
        )
    )
)
player.play()

// Controls cơ bản
player.pause()
player.next()
player.previous()
player.seekTo(30_000)
player.setQuality(/* QualityOption */)
player.setSubtitle(/* SubtitleTrack? */)
player.setPlaybackRate(1.25f)
player.isAutoplayEnabled = true
player.isLoopEnabled = false

override fun onDestroy() {
    player.release()
    super.onDestroy()
}
```

UI YouTube (control bar / settings / mini player) hiện ở **sample**. App tích hợp tự dựng UI bằng API trên, hoặc copy/tham khảo layout từ `android/sample`.

---

## 4. iOS — Build SDK

### 4.1. Phân phối bằng Swift Package (khuyến nghị)

Package đã sẵn:

```text
/Users/lpbsmobiledev/Desktop/SDK/ios/VideoSDK/Package.swift
```

Không cần “build AAR-equivalent” nếu dùng SPM — Xcode resolve & compile package khi app build.

Kiểm tra package:

```bash
cd /Users/lpbsmobiledev/Desktop/SDK/ios/VideoSDK
xcodebuild -scheme VideoSDK -destination 'generic/platform=iOS Simulator' build
```

### 4.2. Build XCFramework (nếu app không dùng SPM)

```bash
cd /Users/lpbsmobiledev/Desktop/SDK/ios/VideoSDK

# 1) Archive iOS device
xcodebuild archive \
  -scheme VideoSDK \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/VideoSDK-iOS.xcarchive \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 2) Archive simulator
xcodebuild archive \
  -scheme VideoSDK \
  -destination 'generic/platform=iOS Simulator' \
  -archivePath /tmp/VideoSDK-sim.xcarchive \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES
```

Với pure SwiftPM target, Xcode đôi khi không tạo scheme archive như framework classic. Thực tế dễ nhất:

1. Mở `Package.swift` bằng Xcode  
2. Product → Create Archive (nếu có)  
**hoặc** giữ SPM local/Git (cách 4.1) — đây là path chính thức hiện tại của repo.

Nếu cần XCFramework ổn định lâu dài, nên thêm target `.binaryTarget` / convert sang framework project riêng trong phase tiếp theo.

### 4.3. Publish Git (cho team)

Đưa folder `ios/VideoSDK` lên Git (tag `v1.0.0`). App khác add package bằng URL:

```text
https://github.com/<org>/<repo>.git
```

Path package: root chứa `Package.swift` (hoặc chỉ định path trong monorepo nếu dùng sparse).

---

## 5. iOS — Tích hợp vào project khác

### Cách A — SPM Local (dev)

1. Xcode → app project  
2. **File → Add Package Dependencies… → Add Local…**  
3. Chọn folder:

```text
/Users/lpbsmobiledev/Desktop/SDK/ios/VideoSDK
```

4. Add library **VideoSDK** vào target app.

### Cách B — SPM Git

```text
File → Add Package Dependencies…
→ Enter package URL + version/tag
→ Add to target
```

### Cách C — Copy sources (không khuyến nghị)

Chỉ dùng khi không dùng được SPM: copy `Sources/VideoSDK` vào app target.

### iOS — Code tích hợp tối thiểu

```swift
import SwiftUI
import VideoSDK

struct PlayerScreen: View {
    @StateObject private var player = VideoPlayer()

    var body: some View {
        ControlledVideoPlayerView(
            player: player,
            onSubtitlesTap: { /* mở sheet phụ đề / settings */ },
            onSettingsTap: { /* show PlayerSettingsSheet */ },
            onCastTap: { },
            onMinimizeTap: { /* bật MiniPlayerView */ },
            onFullscreenTap: { }
        )
        .aspectRatio(16/9, contentMode: .fit)
        .onAppear {
            player.setPlaylist([
                VideoItem(
                    id: "1",
                    url: URL(string: "https://example.com/stream.m3u8")!,
                    title: "Demo"
                )
            ])
            player.play()
        }
    }
}
```

Chỉ cần engine, không UI:

```swift
let player = VideoPlayer()
player.setPlaylist([...])
player.play()
player.pause()
player.next()
player.previous()
player.seek(to: 30)
player.setQuality(.auto)
player.setSubtitle(nil)
player.setPlaybackRate(1.25)
player.isAutoplayEnabled = true
player.isLoopEnabled = false
```

UI có sẵn trong package:

| Component | Mục đích |
|---|---|
| `VideoPlayerView` | Surface AVPlayer |
| `PlayerControlsOverlay` / `ControlledVideoPlayerView` | Control YouTube mobile |
| `PlayerSettingsSheet` | Bottom sheet Cài đặt |
| `MiniPlayerView` | Mini player thu nhỏ |

`Info.plist` app: cho phép mạng (ATS) nếu stream HTTP:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

(Với production nên chỉ mở exception domain cần thiết.)

---

## 6. Checklist trước khi ship SDK cho team khác

### Android
- [ ] `./gradlew :videosdk:assembleRelease` thành công  
- [ ] Version `groupId:artifactId:version` đã chốt  
- [ ] ProGuard consumer rules đủ (`consumer-rules.pro`)  
- [ ] minSdk app ≥ **24**  
- [ ] Internet permission có trong app host  

### iOS
- [ ] Package resolve trên Xcode 15+  
- [ ] Deployment target app ≥ **iOS 15**  
- [ ] Đã test simulator + device  
- [ ] Stream HLS thật chạy được  

### Chung
- [ ] Tài liệu URL demo / format hỗ trợ (ưu tiên **HLS/DASH**)  
- [ ] Không commit `local.properties`, keystore, secrets  

---

## 7. Versioning đề xuất

Dùng [SemVer](https://semver.org/):

| Thay đổi | Version |
|---|---|
| Fix bug, không đổi API | `1.0.x` |
| Thêm API tương thích ngược | `1.x.0` |
| Đổi / xoá API public | `x.0.0` |

Tag Git đồng bộ: `v1.0.0`.

---

## 8. Troubleshooting nhanh

| Triệu chứng | Cách xử lý |
|---|---|
| Android: `SDK location not found` | Tạo `android/local.properties` với `sdk.dir=...` |
| Android AAR black screen | Quên attach `PlayerView` hoặc thiếu Internet |
| Android AAR thiếu class Media3 | Dùng Maven/module thay vì AAR thuần, hoặc thêm deps Media3 tay |
| iOS package không hiện | Add Local đúng folder có `Package.swift` |
| iOS không phát HTTP | Cấu hình ATS / dùng HTTPS |
| Seek/quality không đổi | Đợi `Ready`; quality phụ thuộc variant HLS |

---

## 9. API surface tóm tắt

### Android (`com.videosdk.player`)

- `VideoPlayer(context)`
- `attach(PlayerView)` / `detach(PlayerView)` / `release()`
- `setPlaylist(items)` · `play()` · `pause()` · `togglePlayPause()`
- `next()` · `previous()` · `seekTo(ms)`
- `setQuality` · `availableQualities`
- `setSubtitle` · `availableSubtitles`
- `setPlaybackRate` · `isAutoplayEnabled` · `isLoopEnabled`
- `addListener { PlayerEvent -> }`

### iOS (`import VideoSDK`)

- `VideoPlayer` (`ObservableObject`)
- API tương đương Android + SwiftUI helpers ở mục 5

---

## 10. Bước tiếp theo (tuỳ chọn)

Khi cần phân phối chuẩn production:

1. **Android:** publish Maven (GitHub Packages / Nexus) thay vì chỉ `mavenLocal`  
2. **iOS:** repo Git riêng cho package + tags  
3. Thêm CI: build AAR + `xcodebuild` trên PR  
4. Xuất XCFramework nếu khách hàng chỉ nhận binary  

Hiện tại path ổn định nhất:

- Android → **module / mavenLocal**  
- iOS → **SPM local / SPM Git**

---

## React Native & Flutter

Tích hợp cross-platform qua bridge native:

| Framework | Package skeleton | Tài liệu |
|---|---|---|
| **React Native** | `bridges/react-native` | [docs/CROSS_PLATFORM.md](./docs/CROSS_PLATFORM.md) §12 |
| **Flutter** | `bridges/flutter` | [docs/CROSS_PLATFORM.md](./docs/CROSS_PLATFORM.md) §13 |

Tóm tắt: JS/Dart → Method channel + Platform View → VideoSDK (ExoPlayer / AVPlayer).

Chi tiết cài đặt, API mẫu, checklist: **[docs/CROSS_PLATFORM.md](./docs/CROSS_PLATFORM.md)**.
