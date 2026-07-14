import 'dart:async';

import 'package:flutter/services.dart';

import 'videosdk_models.dart';

class VideoSdkController {
  static const _method = MethodChannel('videosdk_player');
  static const _events = EventChannel('videosdk_player_events');

  StreamSubscription? _sub;
  final _controller = StreamController<Map<dynamic, dynamic>>.broadcast();

  Stream<Map<dynamic, dynamic>> get events => _controller.stream;

  VideoSdkController() {
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _controller.add(event);
      }
    });
  }

  Future<void> setPlaylist(List<VideoSdkItem> items, {int startIndex = 0}) {
    return _method.invokeMethod('setPlaylist', {
      'items': items.map((e) => e.toMap()).toList(),
      'startIndex': startIndex,
    });
  }

  Future<void> play() => _method.invokeMethod('play');
  Future<void> pause() => _method.invokeMethod('pause');
  Future<void> togglePlayPause() => _method.invokeMethod('togglePlayPause');
  Future<void> next() => _method.invokeMethod('next');
  Future<void> previous() => _method.invokeMethod('previous');
  Future<void> seekTo(int positionMs) =>
      _method.invokeMethod('seekTo', {'positionMs': positionMs});
  Future<void> setPlaybackRate(double rate) =>
      _method.invokeMethod('setPlaybackRate', {'rate': rate});
  Future<void> setAutoplay(bool enabled) =>
      _method.invokeMethod('setAutoplay', {'enabled': enabled});
  Future<void> setLoop(bool enabled) =>
      _method.invokeMethod('setLoop', {'enabled': enabled});
  Future<void> release() => _method.invokeMethod('release');

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
    await release();
  }
}
