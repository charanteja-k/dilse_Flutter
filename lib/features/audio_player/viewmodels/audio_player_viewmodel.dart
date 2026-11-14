import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/datasources/local/queue_manager.dart';
import '../../../data/datasources/local/soloud_audio_driver.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

/// ViewModel managing audio playback state, queue traversal, and SoLoud driver interaction.
/// Follows AGENTS.md Invariant 1 (Zero singletons, injected via Provider) and
/// Invariant 3 (Strict MVVM, zero widget references, lifecycle cancellations).
class AudioPlayerViewModel extends ChangeNotifier {
  final SoLoudAudioDriver audioDriver;
  final QueueManager queueManager;
  final AudioRepository audioRepository;

  late final StreamSubscription<PlaybackState> _stateSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;

  PlaybackState _playbackState = PlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isAutoQueueLoading = false;

  AudioPlayerViewModel({
    required this.audioDriver,
    required this.queueManager,
    required this.audioRepository,
  }) {
    _stateSub = audioDriver.stateStream.listen(_onStateChanged);
    _positionSub = audioDriver.positionStream.listen(_onPositionChanged);
    _durationSub = audioDriver.durationStream.listen(_onDurationChanged);
  }

  PlaybackState get playbackState => _playbackState;
  Duration get position => _position;
  Duration get duration => _duration;
  SongModel? get currentSong => queueManager.currentSong;
  List<SongModel> get queue => queueManager.currentQueue;
  bool get isPlaying => _playbackState == PlaybackState.playing;
  bool get isBuffering => _playbackState == PlaybackState.buffering;
  bool get isShuffled => queueManager.isShuffled;
  RepeatMode get repeatMode => queueManager.repeatMode;

  void _onStateChanged(PlaybackState state) {
    _playbackState = state;
    if (state == PlaybackState.completed) {
      skipNext();
    }
    notifyListeners();
  }

  void _onPositionChanged(Duration pos) {
    _position = pos;
    notifyListeners();
  }

  void _onDurationChanged(Duration dur) {
    _duration = dur;
    notifyListeners();
  }

  Future<void> playSong(SongModel song) async {
    queueManager.setQueue([song], initialIndex: 0);
    await _startPlayback(song);

    // Concurrently trigger Google InnerTube radio queue generation
    _triggerBackgroundRadio(song);
  }

  Future<void> playFromQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    queueManager.setQueue(songs, initialIndex: initialIndex);
    final song = queueManager.currentSong;
    if (song != null) {
      await _startPlayback(song);
    }
  }

  Future<void> _startPlayback(SongModel song) async {
    await audioDriver.playSong(song);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await audioDriver.pause();
    } else if (_playbackState == PlaybackState.paused) {
      await audioDriver.resume();
    } else if (currentSong != null) {
      await _startPlayback(currentSong!);
    }
  }

  Future<void> seek(Duration position) async {
    await audioDriver.seek(position);
  }

  Future<void> skipNext() async {
    final nextSong = queueManager.skipToNext();
    if (nextSong != null) {
      await _startPlayback(nextSong);
    } else {
      await audioDriver.stop();
    }
  }

  Future<void> skipPrevious() async {
    final prevSong = queueManager.skipToPrevious();
    if (prevSong != null) {
      await _startPlayback(prevSong);
    }
  }

  void toggleShuffle() {
    queueManager.toggleShuffle();
    notifyListeners();
  }

  void toggleRepeatMode() {
    queueManager.toggleRepeatMode();
    notifyListeners();
  }

  Future<void> _triggerBackgroundRadio(SongModel seedSong) async {
    if (_isAutoQueueLoading) return;
    _isAutoQueueLoading = true;
    try {
      final radioTracks = await audioRepository.generateAlgorithmicQueue(
        seedSong: seedSong,
        limit: 15,
      );
      if (radioTracks.length > 1) {
        final upcoming = radioTracks.sublist(1);
        queueManager.addTracks(upcoming);
        notifyListeners();
      }
    } catch (_) {} finally {
      _isAutoQueueLoading = false;
    }
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    audioDriver.dispose();
    super.dispose();
  }
}
