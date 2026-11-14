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
  StreamSubscription<Duration?>? _durationSub;

  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  DilSeAudioHandler({ja.AudioPlayer? player})
      : _player = player ?? ja.AudioPlayer() {
    _initStreams();
  }

  ja.AudioPlayer get player => _player;

  void _initStreams() {
    _playbackEventSub = _player.playbackEventStream.listen(
      (ja.PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(
          playbackState.value.copyWith(
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
            },
            androidCompactActionIndices: const [0, 1, 3],
            processingState: const {
              ja.ProcessingState.idle: AudioProcessingState.idle,
              ja.ProcessingState.loading: AudioProcessingState.loading,
              ja.ProcessingState.buffering: AudioProcessingState.buffering,
              ja.ProcessingState.ready: AudioProcessingState.ready,
              ja.ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState]!,
            playing: playing,
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            speed: _player.speed,
            queueIndex: event.currentIndex,
          ),
        );
      },
    );

    _durationSub = _player.durationStream.listen(
      (Duration? duration) {
        if (mediaItem.value != null && duration != null) {
          mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        }
      },
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
        duration: song.duration,
        artUri: song.thumbnailUrl.isNotEmpty ? Uri.tryParse(song.thumbnailUrl) : null,
      ),
    );
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
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

  @override
  Future<void> onTaskRemoved() async {
    if (!_player.playing) {
      await stop();
    }
    await super.onTaskRemoved();
  }

  Future<void> disposeHandler() async {
    await _playbackEventSub?.cancel();
    await _durationSub?.cancel();
  }
}
