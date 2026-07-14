# Flutter plugin bridge for VideoSDK

Skeleton plugin — xem hướng dẫn đầy đủ:

- [docs/CROSS_PLATFORM.md](../../docs/CROSS_PLATFORM.md)
- [INTEGRATION.md](../../INTEGRATION.md)

## Cài nhanh

```yaml
# pubspec.yaml (app)
dependencies:
  videosdk_player:
    path: /Users/lpbsmobiledev/Desktop/SDK/bridges/flutter
```

```bash
flutter pub get
```

Android `settings.gradle` — include native core:

```gradle
include ':videosdk'
project(':videosdk').projectDir = new File(rootProject.projectDir, '../../SDK/android/videosdk')
```

iOS: `platform :ios, '15.0'` + Add Local Package `SDK/ios/VideoSDK`.
