import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../../models/song_model.dart';

/// AudioHandler implementation managing background media notification, lockscreen playback controls,
/// and hardware/Bluetooth media buttons.
///
/// Follows AGENTS.md:
/// - Invariant 1: No static singletons. Injected via Provider in main.dart.
/// - Invariant 3: Clean separation between Audio Driver, Handler, and ViewModel.
class DilSeAudioHandler extends BaseAudioHandler with SeekHandler {
  final ja.AudioPlayer _player;
  StreamSubscription<ja.PlaybackEvent>? _playbackEventSub;
  StreamSubscription<ja.PlayerState>? _playerStateSub;
  StreamSubscription<Duration?>? _durationSub;

  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onTogglePlayPause;
  Future<void> Function(Duration position)? onSeek;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  DilSeAudioHandler({ja.AudioPlayer? player})
      : _player = player ?? ja.AudioPlayer() {
    _initStreams();
  }

  ja.AudioPlayer get player => _player;

  void _broadcastPlaybackState({int? queueIndex}) {
    final playing = _player.playing;
    final processingState = _player.processingState;

    final AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ja.ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ja.ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ja.ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ja.ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ja.ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.fastForward,
          MediaAction.rewind,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: audioProcessingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex ?? playbackState.value.queueIndex,
      ),
    );
  }

  void _initStreams() {
    _playbackEventSub = _player.playbackEventStream.listen(
      (ja.PlaybackEvent event) {
        _broadcastPlaybackState(queueIndex: event.currentIndex);
      },
    );

    _playerStateSub = _player.playerStateStream.listen(
      (ja.PlayerState state) {
        _broadcastPlaybackState();
      },
    );

    _durationSub = _player.durationStream.listen(
      (Duration? duration) {
        if (mediaItem.value != null && duration != null && duration > Duration.zero) {
          mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        }
      },
    );
  }

  /// Proactively keeps Android Foreground Service alive during screen-off song transitions.
  void notifyLoading({bool isLoading = true}) {
    final playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing || isLoading) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.fastForward,
          MediaAction.rewind,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: isLoading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: playing || isLoading,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: playbackState.value.queueIndex,
      ),
    );
  }

  /// Updates current media item for lockscreen artwork, metadata, and duration.
  void updateMediaForSong(SongModel song) {
    mediaItem.add(
      MediaItem(
        id: song.id,
        album: song.album.isNotEmpty ? song.album : 'DilSe Music',
        title: song.title,
        artist: song.artist,
        duration: song.duration > Duration.zero ? song.duration : null,
        artUri: song.thumbnailUrl.isNotEmpty ? Uri.tryParse(song.thumbnailUrl) : null,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (onPlay != null) {
      await onPlay!();
    } else {
      await _player.play();
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    if (onPause != null) {
      await onPause!();
    } else {
      await _player.pause();
    }
    _broadcastPlaybackState();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (_player.playing) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (onSeek != null) {
      await onSeek!(position);
    } else {
      await _player.seek(position);
    }
  }

  @override
  Future<void> stop() async {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    // Dismiss ghost notification when swiped from recents if not playing
    if (!_player.playing) {
      await stop();
    }
    await super.onTaskRemoved();
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }

  @override
  Future<void> fastForward() async {
    final newPos = _player.position + const Duration(seconds: 10);
    await seek(newPos);
  }

  @override
  Future<void> rewind() async {
    final newPos = _player.position - const Duration(seconds: 10);
    await seek(newPos > Duration.zero ? newPos : Duration.zero);
  }

  @override
  Future<void> seekForward(bool begin) async {
    if (begin) await fastForward();
  }

  @override
  Future<void> seekBackward(bool begin) async {
    if (begin) await rewind();
  }

  Future<void> disposeHandler() async {
    await _playbackEventSub?.cancel();
    await _playerStateSub?.cancel();
    await _durationSub?.cancel();
  }
}
