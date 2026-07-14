# Example apps
#
# - VideoSdkRN/       React Native + react-native-videosdk
# - VideoSdkFlutter/  Flutter + videosdk_player
#
# See docs/CROSS_PLATFORM.md for architecture notes.

## React Native

```bash
cd examples/VideoSdkRN
npm install
cd ios && bundle exec pod install && cd ..
# Android
npm run android
# iOS
npm run ios
```

## Flutter

```bash
cd examples/VideoSdkFlutter
flutter pub get
cd ios && pod install && cd ..
flutter run
```

Android module `:videosdk` is included via `settings.gradle` / `settings.gradle.kts`.  
iOS links local CocoaPods pod `VideoSDK` from `ios/VideoSDK`.
