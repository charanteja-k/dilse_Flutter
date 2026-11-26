import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/local/audio_handler.dart';
import '../../../data/datasources/local/queue_manager.dart';
import '../../../data/datasources/local/soloud_audio_driver.dart';
import '../../../data/datasources/local/storage_datasource.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';
import '../../../core/services/queue_calibrator.dart';

export '../../../data/datasources/local/queue_manager.dart' show RepeatMode;
export '../../../core/services/queue_calibrator.dart' show QueueMode, QueueTrackBadge;

enum ArtworkStyle { card, vinyl }

/// ViewModel managing audio playback state, queue traversal, lyrics, equalizer, and driver interaction.
/// Follows AGENTS.md Invariant 1 (Zero singletons, injected via Provider) and
/// Invariant 3 (Strict MVVM, zero widget references, lifecycle cancellations).
class AudioPlayerViewModel extends ChangeNotifier {
  final SoLoudAudioDriver audioDriver;
  final QueueManager queueManager;
  final AudioRepository audioRepository;
  final StorageDatasource? storageDatasource;

  late final StreamSubscription<PlaybackState> _stateSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  StreamSubscription<List<SongModel>>? _likedSub;

  PlaybackState _playbackState = PlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isAutoQueueLoading = false;
  bool get isAutoQueueLoading => _isAutoQueueLoading;

  ArtworkStyle _artworkStyle = ArtworkStyle.card;
  QueueMode _queueMode = QueueMode.blend;
  final Map<String, QueueTrackBadge> _trackBadges = {};
  List<SongModel> _lastRawCandidates = [];
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
    this.storageDatasource,
    DilSeAudioHandler? audioHandler,
  }) {
    _stateSub = audioDriver.stateStream.listen(_onStateChanged);
    _positionSub = audioDriver.positionStream.listen(_onPositionChanged);
    _durationSub = audioDriver.durationStream.listen(_onDurationChanged);
    if (storageDatasource != null) {
      _likedSub = storageDatasource!.likedSongsStream.listen((songs) {
        _likedSongIds.clear();
        _likedSongIds.addAll(songs.map((s) => s.id));
        notifyListeners();
      });
    }
    _loadLikedSongs();
    if (audioHandler != null) {
      audioHandler.onSkipToNext = skipNext;
      audioHandler.onSkipToPrevious = skipPrevious;
      audioHandler.onPlay = () async {
        if (_playbackState == PlaybackState.paused) {
          await audioDriver.resume();
        } else if (_playbackState == PlaybackState.playing) {
          // Already playing
        } else if (currentSong != null) {
          await _startPlayback(currentSong!);
        } else {
          await audioDriver.resume();
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
  QueueMode get queueMode => _queueMode;
  QueueTrackBadge getTrackBadge(String songId) =>
      _trackBadges[songId] ?? QueueTrackBadge.discovery;

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

  int _autoQueueRequestId = 0;

  Future<void> playSong(SongModel song) async {
    final requestId = ++_autoQueueRequestId;
    queueManager.setQueue([song], initialIndex: 0);

    // Concurrently trigger Google InnerTube radio queue generation immediately
    _triggerBackgroundRadio(song, requestId);

    await _startPlayback(song);
  }

  Future<void> playFromQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    queueManager.setQueue(songs, initialIndex: initialIndex);
    final song = queueManager.currentSong;
    if (song != null) {
      await _startPlayback(song);
    }
  }

  Future<void> _startPlayback(SongModel song) async {
    SongModel playableSong = song;
    if (playableSong.streamUrl.isEmpty) {
      final resolved = await audioRepository.resolveSingleTrack(
        playableSong.title,
        artist: playableSong.artist,
      );
      if (resolved != null && resolved.streamUrl.isNotEmpty) {
        playableSong = playableSong.copyWith(
          streamUrl: resolved.streamUrl,
          album: resolved.album.isNotEmpty ? resolved.album : playableSong.album,
          thumbnailUrl: resolved.thumbnailUrl.isNotEmpty ? resolved.thumbnailUrl : playableSong.thumbnailUrl,
          duration: resolved.duration > Duration.zero ? resolved.duration : playableSong.duration,
        );
        queueManager.updateSong(playableSong);
      } else {
        // Fallback to top studio search match
        final searchResults = await audioRepository.searchSongs(
          '${playableSong.title} ${playableSong.artist}'.trim(),
          limit: 1,
        );
        if (searchResults.isNotEmpty && searchResults.first.streamUrl.isNotEmpty) {
          final topMatch = searchResults.first;
          playableSong = playableSong.copyWith(
            streamUrl: topMatch.streamUrl,
            album: topMatch.album.isNotEmpty ? topMatch.album : playableSong.album,
            thumbnailUrl: topMatch.thumbnailUrl.isNotEmpty ? topMatch.thumbnailUrl : playableSong.thumbnailUrl,
            duration: topMatch.duration > Duration.zero ? topMatch.duration : playableSong.duration,
          );
          queueManager.updateSong(playableSong);
        }
      }
    }

    await audioDriver.playSong(playableSong);
    notifyListeners();
    fetchLyricsForCurrentSong();

    _prewarmNextTrack();
  }

  void _prewarmNextTrack() {
    final nextIdx = queueManager.currentIndex + 1;
    if (nextIdx < queueManager.currentQueue.length) {
      final nextSong = queueManager.currentQueue[nextIdx];
      if (nextSong.streamUrl.isEmpty) {
        audioRepository.resolveSingleTrack(
          nextSong.title,
          artist: nextSong.artist,
        ).then((resolved) {
          if (resolved != null && resolved.streamUrl.isNotEmpty) {
            final updated = nextSong.copyWith(
              streamUrl: resolved.streamUrl,
              album: resolved.album.isNotEmpty ? resolved.album : nextSong.album,
              thumbnailUrl: resolved.thumbnailUrl.isNotEmpty ? resolved.thumbnailUrl : nextSong.thumbnailUrl,
              duration: resolved.duration > Duration.zero ? resolved.duration : nextSong.duration,
            );
            queueManager.updateSong(updated);
          }
        }).catchError((_) {});
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying || _playbackState == PlaybackState.buffering) {
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

  /// Sets the queue calibration mode and recalibrates upcoming tracks smoothly.
  void setQueueMode(QueueMode mode) {
    if (_queueMode == mode) return;
    _queueMode = mode;
    _recalibrateUpcomingQueue();
    notifyListeners();
  }

  /// Cycles to the next queue calibration mode:
  /// blend -> discover -> familiar -> singleLanguage -> blend
  QueueMode cycleQueueMode() {
    final next = switch (_queueMode) {
      QueueMode.blend => QueueMode.discover,
      QueueMode.discover => QueueMode.familiar,
      QueueMode.familiar => QueueMode.singleLanguage,
      QueueMode.singleLanguage => QueueMode.blend,
    };
    setQueueMode(next);
    return next;
  }

  /// Clears upcoming tracks in the queue while preserving the active song.
  void clearUpcomingQueue() {
    queueManager.clearUpcoming();
    _lastRawCandidates.clear();
    _trackBadges.clear();
    notifyListeners();
  }

  Future<void> _recalibrateUpcomingQueue() async {
    final activeSong = queueManager.currentSong;
    if (activeSong == null || _lastRawCandidates.isEmpty) return;

    final calibrator = const QueueCalibrator();
    final likedSongs = storageDatasource != null
        ? await storageDatasource!.getLikedSongs()
        : <SongModel>[];
    final historySongs = storageDatasource != null
        ? await storageDatasource!.getListeningHistory()
        : <SongModel>[];

    final calibrated = calibrator.calibrate(
      seedSong: activeSong,
      rawCandidates: _lastRawCandidates,
      mode: _queueMode,
      userLikedSongs: likedSongs,
      userHistory: historySongs,
    );

    _trackBadges.clear();
    final newUpcoming = <SongModel>[];
    for (final item in calibrated) {
      newUpcoming.add(item.song);
      _trackBadges[item.song.id] = item.badge;
    }
    queueManager.replaceUpcoming(newUpcoming);
  }

  Future<void> toggleLike(SongModel song) async {
    if (storageDatasource != null) {
      final isNowLiked = await storageDatasource!.toggleLike(song);
      if (isNowLiked) {
        _likedSongIds.add(song.id);
      } else {
        _likedSongIds.remove(song.id);
      }
    } else {
      if (_likedSongIds.contains(song.id)) {
        _likedSongIds.remove(song.id);
      } else {
        _likedSongIds.add(song.id);
      }
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dilse_liked_song_ids', _likedSongIds.toList());
    } catch (_) {}
  }

  Future<void> _loadLikedSongs() async {
    try {
      if (storageDatasource != null) {
        final songs = await storageDatasource!.getLikedSongs();
        _likedSongIds.clear();
        _likedSongIds.addAll(songs.map((s) => s.id));
      }
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dilse_liked_song_ids');
      if (list != null) {
        _likedSongIds.addAll(list);
      }
      notifyListeners();
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

  Future<void> _triggerBackgroundRadio(SongModel seedSong, int requestId) async {
    _isAutoQueueLoading = true;
    notifyListeners();

    try {
      final radioTracks = await audioRepository.generateAlgorithmicQueue(
        seedSong: seedSong,
        limit: 50,
      );

      // Verify that this request is still the active one (user hasn't selected another song)
      if (requestId != _autoQueueRequestId || _isDisposed) {
        return;
      }

      // Verify that the currently active song in the player still matches this seed
      final activeSong = queueManager.currentSong;
      if (activeSong == null ||
          (activeSong.id != seedSong.id && activeSong.title != seedSong.title)) {
        return;
      }

      if (radioTracks.length > 1) {
        _lastRawCandidates = radioTracks.sublist(1);
        final calibrator = const QueueCalibrator();
        final likedSongs = storageDatasource != null
            ? await storageDatasource!.getLikedSongs()
            : <SongModel>[];
        final historySongs = storageDatasource != null
            ? await storageDatasource!.getListeningHistory()
            : <SongModel>[];

        final calibrated = calibrator.calibrate(
          seedSong: seedSong,
          rawCandidates: _lastRawCandidates,
          mode: _queueMode,
          userLikedSongs: likedSongs,
          userHistory: historySongs,
        );

        _trackBadges.clear();
        final upcoming = <SongModel>[];
        for (final item in calibrated) {
          upcoming.add(item.song);
          _trackBadges[item.song.id] = item.badge;
        }
        queueManager.addTracks(upcoming);
        notifyListeners();
      }
    } catch (_) {} finally {
      if (requestId == _autoQueueRequestId) {
        _isAutoQueueLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _likedSub?.cancel();
    audioDriver.dispose();
    super.dispose();
  }
}
