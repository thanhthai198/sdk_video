# React Native bridge for VideoSDK

Skeleton package — xem hướng dẫn đầy đủ:

- [docs/CROSS_PLATFORM.md](../../docs/CROSS_PLATFORM.md)
- [INTEGRATION.md](../../INTEGRATION.md)

## Cài nhanh

```bash
# trong app React Native
npm install /Users/lpbsmobiledev/Desktop/SDK/bridges/react-native
cd ios && pod install
```

Android `settings.gradle` — include native core:

```gradle
include ':videosdk'
project(':videosdk').projectDir = new File(rootProject.projectDir, '../../SDK/android/videosdk')
```

iOS: Add Local Package `SDK/ios/VideoSDK` trong Xcode workspace.
