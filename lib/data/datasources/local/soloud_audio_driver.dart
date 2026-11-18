import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../../models/song_model.dart';
import 'audio_handler.dart';

enum PlaybackState { idle, buffering, playing, paused, completed, error }

/// Clean, context-injectable Audio Engine Driver.
///
/// Follows AGENTS.md:
/// - Invariant 1: Zero singletons in app code. Injected via Provider.
/// - Invariant 3: Tripartite separation. Exposes reactive streams.
/// - Section 3: Powered by just_audio with native Android & Web compatibility.
abstract class SoLoudAudioDriver {
  Future<void> initialize();
  Future<void> playSong(SongModel song);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  void dispose();

  Stream<PlaybackState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  PlaybackState get currentState;
  Duration get currentPosition;
  Duration get currentDuration;
}

/// High-performance audio driver powered by just_audio & Android ExoPlayer.
/// Natively supports 320kbps AAC MP4 container streams from JioSaavn without decoding stalls.
class JustAudioDriverImpl implements SoLoudAudioDriver {
  final ja.AudioPlayer _player;
  final DilSeAudioHandler? _audioHandler;
  late final StreamSubscription _playerStateSub;
  late final StreamSubscription _positionSub;
  late final StreamSubscription _durationSub;

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  PlaybackState _currentState = PlaybackState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

  JustAudioDriverImpl({ja.AudioPlayer? player, DilSeAudioHandler? audioHandler})
    : _player = player ?? audioHandler?.player ?? ja.AudioPlayer(),
      _audioHandler = audioHandler {
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.loading ||
          state.processingState == ja.ProcessingState.buffering) {
        _setState(PlaybackState.buffering);
      } else if (state.processingState == ja.ProcessingState.completed) {
        _setState(PlaybackState.completed);
      } else if (state.playing) {
        _setState(PlaybackState.playing);
      } else if (state.processingState == ja.ProcessingState.ready) {
        _setState(PlaybackState.paused);
      } else if (state.processingState == ja.ProcessingState.idle) {
        _setState(PlaybackState.idle);
      }
    });

    _positionSub = _player.positionStream.listen((pos) {
      _currentPosition = pos;
      if (!_positionController.isClosed) {
        _positionController.add(pos);
      }
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _currentDuration = dur;
        if (!_durationController.isClosed) {
          _durationController.add(dur);
        }
      }
    });
  }

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;
  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration> get durationStream => _durationController.stream;
  @override
  PlaybackState get currentState => _currentState;
  @override
  Duration get currentPosition => _currentPosition;
  @override
  Duration get currentDuration => _currentDuration;

  void _setState(PlaybackState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playSong(SongModel song) async {
    try {
      _setState(PlaybackState.buffering);
      debugPrint('[AudioDriver] Playing song: ${song.title} - ${song.artist}');
      debugPrint('[AudioDriver] Stream URL: ${song.streamUrl}');

      // Immediately set the media item and notify loading
      // so Android foreground service displays notification with track title and artwork
      _audioHandler?.updateMediaForSong(song);
      _audioHandler?.notifyLoading(isLoading: true);

      await _player.setUrl(song.streamUrl);
      _currentDuration = _player.duration ?? song.duration;
      if (!_durationController.isClosed) {
        _durationController.add(_currentDuration);
      }

      await _player.play();
      _audioHandler?.notifyLoading(isLoading: false);
      debugPrint('[AudioDriver] Playback started successfully!');
    } catch (e, stack) {
      debugPrint('[AudioDriver] Error playing song: $e\n$stack');
      _setState(PlaybackState.error);
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() async {
    await _player.stop();
    _currentPosition = Duration.zero;
    _setState(PlaybackState.idle);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _playerStateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    _audioHandler?.disposeHandler();
    _player.dispose();
  }
}

/// Backward compatibility alias
typedef SoLoudAudioDriverImpl = JustAudioDriverImpl;
