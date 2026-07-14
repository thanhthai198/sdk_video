import 'package:flutter/material.dart';
import 'package:videosdk_player/videosdk_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoSdkFlutterApp());
}

class VideoSdkFlutterApp extends StatelessWidget {
  const VideoSdkFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoSDK Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PlayerPage(),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final controller = VideoSdkController();
  String lastEvent = '—';

  @override
  void initState() {
    super.initState();
    controller.events.listen((event) {
      if (event['type'] == 'progress') return;
      setState(() => lastEvent = '$event');
    });
  }

  Future<void> _loadAndPlay() async {
    await controller.setPlaylist([
      const VideoSdkItem(
        id: '1',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        title: 'Mux Demo HLS',
      ),
    ]);
    await controller.play();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'VideoSDK · Flutter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Color(0xFF111111),
                child: VideoSdkView(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loadAndPlay,
                  child: const Text('Load & Play'),
                ),
                ElevatedButton(
                  onPressed: controller.pause,
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: controller.next,
                  child: const Text('Next'),
                ),
                ElevatedButton(
                  onPressed: () => controller.seekTo(10000),
                  child: const Text('+10s'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Last event', style: TextStyle(color: Colors.white54)),
            Text(
              lastEvent,
              style: const TextStyle(
                color: Color(0xFF8FD19E),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
