import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/data/repositories/audio_repository.dart';
import 'package:dilse/features/search/viewmodels/search_viewmodel.dart';
import 'package:dilse/features/audio_player/viewmodels/audio_player_viewmodel.dart';
import 'package:dilse/data/datasources/local/queue_manager.dart';
import 'package:dilse/data/datasources/local/soloud_audio_driver.dart';

class HeadlessAudioDriver implements SoLoudAudioDriver {
  final _stateCtrl = StreamController<PlaybackState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration>.broadcast();

  PlaybackState _state = PlaybackState.idle;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  SongModel? _activeSong;

  SongModel? get activeSong => _activeSong;

  @override
  PlaybackState get currentState => _state;
  @override
  Duration get currentPosition => _pos;
  @override
  Duration get currentDuration => _dur;

  @override
  Stream<PlaybackState> get stateStream => _stateCtrl.stream;
  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration> get durationStream => _durCtrl.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playSong(SongModel song) async {
    _activeSong = song;
    _dur = song.duration > Duration.zero ? song.duration : const Duration(minutes: 3, seconds: 30);
    _durCtrl.add(_dur);
    _pos = Duration.zero;
    _posCtrl.add(_pos);
    _state = PlaybackState.playing;
    _stateCtrl.add(_state);
  }

  @override
  Future<void> pause() async {
    _state = PlaybackState.paused;
    _stateCtrl.add(_state);
  }

  @override
  Future<void> resume() async {
    _state = PlaybackState.playing;
    _stateCtrl.add(_state);
  }

  @override
  Future<void> stop() async {
    _state = PlaybackState.idle;
    _stateCtrl.add(_state);
  }

  @override
  Future<void> seek(Duration position) async {
    _pos = position;
    _posCtrl.add(_pos);
  }

  @override
  void dispose() {
    _stateCtrl.close();
    _posCtrl.close();
    _durCtrl.close();
  }
}

class MockAudioRepo implements AudioRepository {
  final List<SongModel> mockSearchResults;
  final List<SongModel> mockRadioTracks;

  MockAudioRepo({
    required this.mockSearchResults,
    required this.mockRadioTracks,
  });

  @override
  Future<List<SongModel>> searchSongs(String query, {int limit = 20, int page = 1}) async {
    return mockSearchResults
        .where((s) =>
            s.title.toLowerCase().contains(query.toLowerCase()) ||
            s.artist.toLowerCase().contains(query.toLowerCase()))
        .take(limit)
        .toList();
  }

  @override
  Future<SongModel?> resolveSingleTrack(String title, {String? artist}) async {
    return mockSearchResults.firstWhere(
      (s) => s.title.toLowerCase().contains(title.toLowerCase()),
      orElse: () => mockSearchResults.first,
    );
  }

  @override
  Future<List<SongModel>> getRecommendations({String query = 'telugu', int limit = 15}) async {
    return mockRadioTracks.take(limit).toList();
  }

  @override
  Future<List<SongModel>> generateAlgorithmicQueue({
    required SongModel seedSong,
    int limit = 50,
  }) async {
    return mockRadioTracks.take(limit).toList();
  }

  @override
  Future<({String? plainLyrics, String? syncedLyrics})> fetchLyrics({
    required String title,
    String? artist,
    Duration? duration,
    String? videoId,
  }) async {
    return (plainLyrics: null, syncedLyrics: null);
  }
}

void main() {
  test('SearchViewModel queries repository and populates results', () async {
    final sampleSongs = [
      const SongModel(
        id: 's1',
        title: 'Samajavaragamana',
        artist: 'Sid Sriram',
        album: 'Ala Vaikunthapurramuloo',
        streamUrl: 'https://cdn.dilse.app/audio/s1.m4a',
        thumbnailUrl: 'https://cdn.dilse.app/img/s1.jpg',
        duration: Duration(seconds: 215),
      ),
      const SongModel(
        id: 's2',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        streamUrl: 'https://cdn.dilse.app/audio/s2.m4a',
        thumbnailUrl: 'https://cdn.dilse.app/img/s2.jpg',
        duration: Duration(seconds: 268),
      ),
    ];

    final mockRepo = MockAudioRepo(
      mockSearchResults: sampleSongs,
      mockRadioTracks: List.generate(
        50,
        (i) => SongModel(
          id: 'ml_$i',
          title: 'Google ML Mix Track $i',
          artist: 'Mix Artist',
          album: 'Mix Album',
          streamUrl: 'https://cdn.dilse.app/audio/ml_$i.m4a',
          thumbnailUrl: 'https://cdn.dilse.app/img/ml_$i.jpg',
          duration: const Duration(seconds: 200),
        ),
      ),
    );

    final searchVm = SearchViewModel(audioRepository: mockRepo);
    expect(searchVm.query, isEmpty);
    expect(searchVm.searchResults, isEmpty);
    expect(searchVm.recentSearches, contains('Samajavaragamana'));

    // Execute search
    await searchVm.search('Samajavaragamana');

    expect(searchVm.searchResults.length, 1);
    expect(searchVm.searchResults.first.title, 'Samajavaragamana');
    expect(searchVm.hasResults, isTrue);

    searchVm.clearSearch();
    expect(searchVm.query, isEmpty);
    expect(searchVm.searchResults, isEmpty);
  });

  test('Tapping individual song from Search triggers playSong and 50-song Google ML automix queue', () async {
    const tappedSong = SongModel(
      id: 'target_seed',
      title: 'Chuttamalle',
      artist: 'Shilpa Rao',
      album: 'Devara',
      streamUrl: 'https://cdn.dilse.app/audio/target_seed.m4a',
      thumbnailUrl: 'https://cdn.dilse.app/img/target_seed.jpg',
      duration: Duration(seconds: 220),
    );

    final ml50Songs = List.generate(
      50,
      (i) => SongModel(
        id: 'ml_radio_$i',
        title: 'Automix Recommendation $i',
        artist: 'Automix Artist $i',
        album: 'Automix Album $i',
        streamUrl: 'https://cdn.dilse.app/audio/ml_radio_$i.m4a',
        thumbnailUrl: 'https://cdn.dilse.app/img/ml_radio_$i.jpg',
        duration: const Duration(seconds: 210),
      ),
    );

    final mockRepo = MockAudioRepo(
      mockSearchResults: [tappedSong],
      mockRadioTracks: ml50Songs,
    );

    final queueManager = QueueManager();
    final fakeDriver = HeadlessAudioDriver();

    final playerVm = AudioPlayerViewModel(
      audioDriver: fakeDriver,
      queueManager: queueManager,
      audioRepository: mockRepo,
    );

    // Initial state
    expect(playerVm.currentSong, isNull);
    expect(queueManager.currentQueue, isEmpty);

    // User taps on the search result song
    await playerVm.playSong(tappedSong);

    // 1. Playback starts immediately on target song
    expect(fakeDriver.activeSong?.id, tappedSong.id);
    expect(playerVm.currentSong?.title, 'Chuttamalle');

    // 2. Allow background Google ML InnerTube queue generation to complete
    await Future.delayed(const Duration(milliseconds: 150));

    // 3. Queue manager now has 50 songs (the seed song + upcoming Google ML recommendations)
    expect(queueManager.currentQueue.length, 50);
    expect(queueManager.currentQueue.first.id, tappedSong.id);
    expect(queueManager.currentQueue[1].title, 'Automix Recommendation 1');
    expect(queueManager.currentQueue[49].title, 'Automix Recommendation 49');

    // 4. Test skipping to next track from the generated queue
    await playerVm.skipNext();
    expect(playerVm.currentSong?.title, 'Automix Recommendation 1');
    expect(queueManager.currentIndex, 1);

    fakeDriver.dispose();
  });
}
