# React Native & Flutter — Tích hợp VideoSDK

VideoSDK hiện là **native core** (Android ExoPlayer + iOS AVPlayer).  
React Native / Flutter **không dùng trực tiếp** được — cần lớp **bridge** (native module + native view).

```text
JS/Dart  →  Bridge (Method/Event + Platform View)  →  VideoSDK native
```

Trong repo:

```text
bridges/
├── react-native/   # Skeleton RN package
└── flutter/        # Skeleton Flutter plugin
```

---

## 11. Kiến trúc chung

| Việc | Android | iOS |
|---|---|---|
| Hiển thị video | `PlayerView` (Media3) qua Platform View | `AVPlayerLayer` / `VideoPlayerView` qua Platform View |
| Điều khiển | Method channel / Native Module | Method channel / Native Module |
| Event (progress, ready…) | Event Emitter / EventChannel | Event Emitter / EventChannel |

**Khuyến nghị:** keep UI chrome (YouTube controls) ở JS/Flutter; native chỉ lo playback.  
Nếu muốn reuse UI native (`ControlledVideoPlayerView`, mini player…), bọc luôn native view lớn hơn — nặng hơn khi sync state với RN/Flutter.

---

## 12. React Native

### 12.1. Cách tích hợp (overview)

1. Tạo/local link package `react-native-videosdk` (folder `bridges/react-native`).
2. Android: phụ thuộc module `:videosdk`.
3. iOS: SPM/local path tới `ios/VideoSDK`.
4. App RN dùng `<VideoSdkView />` + `NativeModules.VideoSdkPlayer`.

### 12.2. Cài vào app React Native

Trong app RN (`package.json`):

```json
{
  "dependencies": {
    "react-native-videosdk": "file:../SDK/bridges/react-native"
  }
}
```

Hoặc:

```bash
npm install ../SDK/bridges/react-native
# / yarn add ../SDK/bridges/react-native
cd ios && pod install
```

#### Android (`android/settings.gradle`)

```gradle
include ':videosdk'
project(':videosdk').projectDir = new File(rootProject.projectDir, '../../SDK/android/videosdk')
```

Đường dẫn chỉnh theo vị trí app của bạn.

`android/app/build.gradle` — autolinking thường đủ; đảm bảo package native được register (template skeleton đã có `VideoSdkPackage`).

#### iOS (`ios/Podfile`)

Với RN autolinking, thêm local SPM/framework:

Cách đơn giản (CocoaPods + path sources): chỉnh `bridges/react-native/ios` để compile kèm sources, **hoặc** trong Xcode workspace:

**File → Add Package Dependencies → Add Local →**  
`/Users/lpbsmobiledev/Desktop/SDK/ios/VideoSDK`

Rồi link `VideoSDK` vào target `Pods-...` / app + RN native module target.

> Skeleton hiện compile bridge iOS bằng cách import `VideoSDK` — bạn cần add local package vào Xcode workspace của app.

### 12.3. API JS (mục tiêu)

```tsx
import React, { useRef } from 'react';
import { View, Button } from 'react-native';
import { VideoSdkView, VideoSdkPlayer } from 'react-native-videosdk';

export function PlayerScreen() {
  const viewRef = useRef(null);

  return (
    <View style={{ flex: 1, backgroundColor: '#000' }}>
      <VideoSdkView
        ref={viewRef}
        style={{ width: '100%', aspectRatio: 16 / 9 }}
        onPlayerEvent={(e) => {
          console.log(e.nativeEvent); // { type: 'progress', positionMs, durationMs }
        }}
      />
      <Button
        title="Load & Play"
        onPress={async () => {
          await VideoSdkPlayer.setPlaylist([
            {
              id: '1',
              url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
              title: 'Demo',
            },
          ]);
          await VideoSdkPlayer.play();
        }}
      />
      <Button title="Pause" onPress={() => VideoSdkPlayer.pause()} />
      <Button title="Next" onPress={() => VideoSdkPlayer.next()} />
      <Button title="Seek +10s" onPress={() => VideoSdkPlayer.seekTo(10_000)} />
    </View>
  );
}
```

### 12.4. Method map (JS → Native)

| JS | Android / iOS native |
|---|---|
| `setPlaylist(items)` | `VideoPlayer.setPlaylist` |
| `play` / `pause` / `togglePlayPause` | tương ứng |
| `next` / `previous` | tương ứng |
| `seekTo(ms)` | Android ms / iOS seconds (`ms/1000`) |
| `setQuality({ height, label })` | `setQuality` |
| `setSubtitle(track\|null)` | `setSubtitle` |
| `setPlaybackRate(rate)` | `setPlaybackRate` |
| `setAutoplay(bool)` / `setLoop(bool)` | flags |
| events | `ready`, `progress`, `playingChanged`, `ended`, `error`, … |

### 12.5. New Architecture (Fabric) — ghi chú

Skeleton dùng **Paper** (Classic ViewManager).  
Khi migrate Fabric: tạo `VideoSdkView` ComponentDescriptor + shadow node; giữ cùng JS API.

### 12.6. Expo

- **Expo Dev Client / prebuild** (không dùng Expo Go thuần) vì cần native code.
- Config plugin (tuỳ chọn) để inject `:videosdk` path + iOS SPM.

---

## 13. Flutter

### 13.1. Cách tích hợp (overview)

1. Dùng plugin `bridges/flutter` (package name `videosdk_player`).
2. Android: `settings.gradle` include `:videosdk`.
3. iOS: Pod / SPM link `VideoSDK`.
4. Flutter UI: `AndroidView` / `UiKitView` (`viewType: videosdk_player_view`) + `MethodChannel('videosdk_player')`.

### 13.2. Cài vào app Flutter

`pubspec.yaml` của app:

```yaml
dependencies:
  videosdk_player:
    path: ../SDK/bridges/flutter
```

```bash
flutter pub get
```

#### Android

`android/settings.gradle` (hoặc `settings.gradle.kts`):

```gradle
include ':videosdk'
project(':videosdk').projectDir = new File(rootProject.projectDir, '../../SDK/android/videosdk')
```

Plugin skeleton đã `implementation project(':videosdk')` trong `android/build.gradle`.

#### iOS

Trong `ios/Podfile` của app (sau `flutter pub get`):

```ruby
# Đảm bảo iOS 15+
platform :ios, '15.0'
```

Mở `ios/Runner.xcworkspace` → Add Local Package `SDK/ios/VideoSDK` → link vào target **Runner** và/hoặc pod plugin.

### 13.3. API Dart (mục tiêu)

```dart
import 'package:flutter/material.dart';
import 'package:videosdk_player/videosdk_player.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final controller = VideoSdkController();

  @override
  void initState() {
    super.initState();
    controller.events.listen((event) {
      debugPrint('player event: $event');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoSdkView(),
          ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await controller.setPlaylist([
                    VideoSdkItem(
                      id: '1',
                      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                      title: 'Demo',
                    ),
                  ]);
                  await controller.play();
                },
                child: const Text('Play'),
              ),
              ElevatedButton(onPressed: controller.pause, child: const Text('Pause')),
              ElevatedButton(onPressed: controller.next, child: const Text('Next')),
              ElevatedButton(
                onPressed: () => controller.seekTo(10000),
                child: const Text('+10s'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

### 13.4. Channel contract

**MethodChannel:** `videosdk_player`  
**EventChannel:** `videosdk_player_events`  
**Platform viewType:** `videosdk_player_view`

Methods: `setPlaylist`, `play`, `pause`, `togglePlayPause`, `next`, `previous`, `seekTo`, `setQuality`, `setSubtitle`, `setPlaybackRate`, `setAutoplay`, `setLoop`, `release`.

---

## 14. So sánh lựa chọn

| Tiêu chí | React Native | Flutter |
|---|---|---|
| View | `requireNativeComponent` / Fabric | `AndroidView` / `UiKitView` |
| Control | TurboModule / NativeModule | MethodChannel |
| Event | NativeEventEmitter | EventChannel |
| Rebuild native | `pod install` / Gradle sync | `flutter clean && flutter run` |
| Hot reload UI | RN JS OK; native bridge đổi → rebuild | Dart OK; native đổi → rebuild |

---

## 15. Checklist RN / Flutter

- [ ] `videosdk` Android module resolve được từ app host  
- [ ] iOS 15+, `VideoSDK` package linked  
- [ ] INTERNET permission (Android)  
- [ ] ATS / HTTPS streams (iOS)  
- [ ] Platform View tạo **sau** engine init; gọi `setPlaylist` sau khi view sẵn sàng  
- [ ] `release()` / `dispose()` khi thoát màn hình (tránh leak ExoPlayer)  
- [ ] Không dùng Expo Go / Flutter web cho bridge native này  

---

## 16. Roadmap hoàn thiện bridge

Skeleton trong `bridges/` là **điểm bắt đầu**. Việc tiếp theo:

1. Hoàn thiện wire `PlayerView` ↔ RN/Flutter platform view (attach khi view created)  
2. Map đủ event `PlayerEvent` → JS/Dart  
3. Example apps: `bridges/react-native/example`, `bridges/flutter/example`  
4. CI build Android + iOS cho cả 2 bridge  
5. (Tuỳ chọn) publish npm (`react-native-videosdk`) + pub.dev (`videosdk_player`)

Khi bridge ổn định, app chỉ cần dependency JS/Dart — **không** đụng native VideoSDK trực tiếp nữa.
