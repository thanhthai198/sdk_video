import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class VideoSdkView extends StatelessWidget {
  const VideoSdkView({super.key});

  static const viewType = 'videosdk_player_view';

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const AndroidView(
          viewType: viewType,
          creationParamsCodec: StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
        return const UiKitView(
          viewType: viewType,
          creationParamsCodec: StandardMessageCodec(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
