import { NativeModules, requireNativeComponent, NativeEventEmitter, type ViewProps } from 'react-native';

export type VideoSdkItem = {
  id: string;
  url: string;
  title?: string;
  subtitleTracks?: Array<{
    id: string;
    language: string;
    label: string;
    url?: string;
  }>;
};

export type VideoSdkPlayerEvent = {
  type: string;
  [key: string]: unknown;
};

type VideoSdkNativeModule = {
  setPlaylist(items: VideoSdkItem[], startIndex?: number): Promise<void>;
  play(): Promise<void>;
  pause(): Promise<void>;
  togglePlayPause(): Promise<void>;
  next(): Promise<void>;
  previous(): Promise<void>;
  seekTo(positionMs: number): Promise<void>;
  setPlaybackRate(rate: number): Promise<void>;
  setAutoplay(enabled: boolean): Promise<void>;
  setLoop(enabled: boolean): Promise<void>;
  setQuality(option: { height: number; label: string }): Promise<void>;
  setSubtitle(track: {
    id: string;
    language: string;
    label: string;
    url?: string;
  } | null): Promise<void>;
  release(): Promise<void>;
};

const LINKING_ERROR =
  "react-native-videosdk: native module not linked. Rebuild the app after installing the package.";

const NativePlayer: VideoSdkNativeModule = NativeModules.VideoSdkPlayer
  ? NativeModules.VideoSdkPlayer
  : new Proxy(
      {} as VideoSdkNativeModule,
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      },
    );

export const VideoSdkPlayer = NativePlayer;

type NativeViewProps = ViewProps & {
  onPlayerEvent?: (event: { nativeEvent: VideoSdkPlayerEvent }) => void;
};

export const VideoSdkView =
  requireNativeComponent<NativeViewProps>('VideoSdkView');

/** Subscribe to player events from the native module. */
export function subscribeVideoSdkEvents(
  listener: (event: VideoSdkPlayerEvent) => void,
) {
  const emitter = new NativeEventEmitter(NativeModules.VideoSdkPlayer);
  return emitter.addListener('VideoSdkPlayerEvent', listener);
}
