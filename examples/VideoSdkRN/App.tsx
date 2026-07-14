/**
 * Sample React Native app integrating react-native-videosdk.
 * @format
 */

import React, { useEffect, useState } from 'react';
import {
  Button,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  VideoSdkPlayer,
  VideoSdkView,
  subscribeVideoSdkEvents,
  type VideoSdkPlayerEvent,
} from 'react-native-videosdk';

const DEMO_URL = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

function App() {
  const [lastEvent, setLastEvent] = useState<string>('—');

  useEffect(() => {
    const sub = subscribeVideoSdkEvents((event: VideoSdkPlayerEvent) => {
      if (event.type === 'progress') {
        return;
      }
      setLastEvent(JSON.stringify(event));
    });
    return () => {
      sub.remove();
      VideoSdkPlayer.release().catch(() => undefined);
    };
  }, []);

  const loadAndPlay = async () => {
    await VideoSdkPlayer.setPlaylist(
      [
        {
          id: '1',
          url: DEMO_URL,
          title: 'Mux Demo HLS',
        },
      ],
      0,
    );
    await VideoSdkPlayer.play();
  };

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle="light-content" />
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>VideoSDK · React Native</Text>
        <VideoSdkView style={styles.player} />
        <View style={styles.row}>
          <Button title="Load & Play" onPress={loadAndPlay} />
          <Button title="Pause" onPress={() => VideoSdkPlayer.pause()} />
        </View>
        <View style={styles.row}>
          <Button title="Next" onPress={() => VideoSdkPlayer.next()} />
          <Button
            title="Seek +10s"
            onPress={() => VideoSdkPlayer.seekTo(10_000)}
          />
        </View>
        <Text style={styles.eventLabel}>Last event</Text>
        <Text style={styles.event}>{lastEvent}</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: '#000',
  },
  container: {
    padding: 16,
    gap: 12,
  },
  title: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '600',
    marginBottom: 8,
  },
  player: {
    width: '100%',
    aspectRatio: 16 / 9,
    backgroundColor: '#111',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    gap: 8,
  },
  eventLabel: {
    color: '#aaa',
    marginTop: 8,
  },
  event: {
    color: '#8fd19e',
    fontFamily: 'Courier',
    fontSize: 12,
  },
});

export default App;
