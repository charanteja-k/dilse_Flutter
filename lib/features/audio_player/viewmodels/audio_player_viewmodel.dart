import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/local/audio_handler.dart';
import '../../../data/datasources/local/queue_manager.dart';
import '../../../data/datasources/local/soloud_audio_driver.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

export '../../../data/datasources/local/queue_manager.dart' show RepeatMode;

enum ArtworkStyle { card, vinyl }

/// ViewModel managing audio playback state, queue traversal, lyrics, equalizer, and driver interaction.
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

  ArtworkStyle _artworkStyle = ArtworkStyle.card;
  final Set<String> _likedSongIds = {};

  String? _currentLyricsPlain;
  String? _currentLyricsSynced;
  bool _isLoadingLyrics = false;
  String? _lyricsSongId;

  static const List<String> equalizerPresets = [
    'Flat',
    'Bass Boost',
    'Vocal Clarity',
    'Electronic',
    'Rock',
    'Pop',
    'Hip-Hop',
    'Acoustic',
    'Classical',
  ];

  static const Map<String, List<double>> presetGains = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [7.0, 4.5, 0.5, 0.0, -1.0],
    'Vocal Clarity': [-2.0, 1.0, 5.5, 4.0, 2.0],
    'Electronic': [6.0, 3.5, 0.0, 2.5, 4.5],
    'Rock': [4.5, 2.0, -1.5, 3.0, 5.0],
    'Pop': [-1.0, 2.0, 4.5, 2.0, -1.0],
    'Hip-Hop': [7.0, 5.0, -1.0, 1.5, 2.5],
    'Acoustic': [3.5, 2.0, 2.5, 3.5, 3.0],
    'Classical': [4.0, 2.5, -1.0, 2.5, 4.0],
  };

  String _activeEqualizerPreset = 'Flat';
  List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0];

  AudioPlayerViewModel({
    required this.audioDriver,
    required this.queueManager,
    required this.audioRepository,
    DilSeAudioHandler? audioHandler,
  }) {
    _stateSub = audioDriver.stateStream.listen(_onStateChanged);
    _positionSub = audioDriver.positionStream.listen(_onPositionChanged);
    _durationSub = audioDriver.durationStream.listen(_onDurationChanged);
    _loadLikedSongs();
    if (audioHandler != null) {
      audioHandler.onSkipToNext = skipNext;
      audioHandler.onSkipToPrevious = skipPrevious;
      audioHandler.onPlay = () async {
        if (_playbackState == PlaybackState.paused) {
          await audioDriver.resume();
        } else if (currentSong != null) {
          await _startPlayback(currentSong!);
        }
      };
      audioHandler.onPause = () async {
        await audioDriver.pause();
      };
      audioHandler.onTogglePlayPause = togglePlayPause;
      audioHandler.onSeek = seek;
    }
  }

  PlaybackState get playbackState => _playbackState;
  Duration get position => _position;
  Duration get duration => _duration;
  SongModel? get currentSong => queueManager.currentSong;
  List<SongModel> get queue => queueManager.currentQueue;
  int get currentIndex => queueManager.currentIndex;
  bool get isPlaying => _playbackState == PlaybackState.playing;
  bool get isBuffering => _playbackState == PlaybackState.buffering;
  bool get isShuffled => queueManager.isShuffled;
  RepeatMode get repeatMode => queueManager.repeatMode;

  ArtworkStyle get artworkStyle => _artworkStyle;
  Set<String> get likedSongIds => Set.unmodifiable(_likedSongIds);
  bool isLiked(String songId) => _likedSongIds.contains(songId);

  String? get currentLyricsPlain => _currentLyricsPlain;
  String? get currentLyricsSynced => _currentLyricsSynced;
  bool get isLoadingLyrics => _isLoadingLyrics;

  String get activeEqualizerPreset => _activeEqualizerPreset;
  List<double> get equalizerBands => List.unmodifiable(_equalizerBands);

  Stream<Duration> get positionStream => audioDriver.positionStream;
  Stream<Duration> get durationStream => audioDriver.durationStream;

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
    fetchLyricsForCurrentSong();
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

  Future<void> seek(Duration targetPosition) async {
    await audioDriver.seek(targetPosition);
  }

  Future<void> seekRelative(Duration delta) async {
    if (_duration == Duration.zero) return;
    final current = _position;
    final target = current + delta;
    final clamped = target.isNegative
        ? Duration.zero
        : (target > _duration ? _duration : target);
    await seek(clamped);
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

  Future<void> skipToIndex(int index) async {
    final song = queueManager.skipToIndex(index);
    if (song != null) {
      await _startPlayback(song);
    }
  }

  void removeQueueTrack(int index) {
    queueManager.removeAt(index);
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    queueManager.reorder(oldIndex, newIndex);
    notifyListeners();
  }

  void toggleShuffle() {
    queueManager.toggleShuffle();
    notifyListeners();
  }

  void toggleRepeatMode() {
    queueManager.toggleRepeatMode();
    notifyListeners();
  }

  void toggleArtworkStyle() {
    _artworkStyle = _artworkStyle == ArtworkStyle.card
        ? ArtworkStyle.vinyl
        : ArtworkStyle.card;
    notifyListeners();
  }

  Future<void> toggleLike(SongModel song) async {
    if (_likedSongIds.contains(song.id)) {
      _likedSongIds.remove(song.id);
    } else {
      _likedSongIds.add(song.id);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dilse_liked_song_ids', _likedSongIds.toList());
    } catch (_) {}
  }

  Future<void> _loadLikedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dilse_liked_song_ids');
      if (list != null) {
        _likedSongIds.addAll(list);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchLyricsForCurrentSong() async {
    final song = currentSong;
    if (song == null) return;
    if (_lyricsSongId == song.id &&
        (_currentLyricsPlain != null || _currentLyricsSynced != null)) {
      return;
    }

    _lyricsSongId = song.id;
    _isLoadingLyrics = true;
    notifyListeners();

    try {
      final res = await audioRepository.fetchLyrics(
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        videoId: song.id,
      );
      if (_lyricsSongId == song.id) {
        _currentLyricsPlain = res.plainLyrics;
        _currentLyricsSynced = res.syncedLyrics;
      }
    } catch (_) {
      if (_lyricsSongId == song.id) {
        _currentLyricsPlain = null;
        _currentLyricsSynced = null;
      }
    } finally {
      if (_lyricsSongId == song.id) {
        _isLoadingLyrics = false;
        notifyListeners();
      }
    }
  }

  void setEqualizerPreset(String preset) {
    if (presetGains.containsKey(preset)) {
      _activeEqualizerPreset = preset;
      _equalizerBands = List<double>.from(presetGains[preset]!);
      notifyListeners();
    }
  }

  void setEqualizerBand(int bandIndex, double gain) {
    if (bandIndex >= 0 && bandIndex < _equalizerBands.length) {
      _equalizerBands[bandIndex] = gain;
      _activeEqualizerPreset = 'Custom';
      notifyListeners();
    }
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
