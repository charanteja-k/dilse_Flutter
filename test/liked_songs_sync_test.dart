import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/data/datasources/local/storage_datasource.dart';
import 'package:dilse/data/datasources/local/queue_manager.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/data/repositories/audio_repository.dart';
import 'package:dilse/data/datasources/local/soloud_audio_driver.dart';
import 'package:dilse/features/audio_player/viewmodels/audio_player_viewmodel.dart';
import 'package:dilse/features/library/viewmodels/library_viewmodel.dart';

class MockStorageDatasource implements StorageDatasource {
  List<SongModel> _liked = [];
  final _likedController = StreamController<List<SongModel>>.broadcast();

  @override
  Stream<List<SongModel>> get likedSongsStream => _likedController.stream;

  @override
  Future<List<SongModel>> getLikedSongs() async => List.from(_liked);

  @override
  Future<void> saveLikedSongs(List<SongModel> songs) async {
    _liked = List.from(songs);
    _likedController.add(List.unmodifiable(_liked));
  }

  @override
  Future<bool> toggleLike(SongModel song) async {
    final idx = _liked.indexWhere((s) => s.id == song.id);
    final exists = idx != -1;
    if (exists) {
      _liked.removeAt(idx);
    } else {
      _liked.insert(0, song);
    }
    await saveLikedSongs(_liked);
    return !exists;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioDriver implements SoLoudAudioDriver {
  @override
  Stream<PlaybackState> get stateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration> get durationStream => const Stream.empty();
  @override
  Duration get currentPosition => Duration.zero;
  @override
  Duration get currentDuration => Duration.zero;
  @override
  PlaybackState get currentState => PlaybackState.idle;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioRepo implements AudioRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const sampleSong = SongModel(
    id: 'devara_chuttamalle',
    title: 'Chuttamalle',
    artist: 'Anirudh Ravichander, Shilpa Rao',
    album: 'Devara Part 1',
    streamUrl: 'https://cdn.dilse.app/chuttamalle.m4a',
    thumbnailUrl: 'https://cdn.dilse.app/chuttamalle.jpg',
    duration: Duration(seconds: 222),
  );

  test('Cross-ViewModel Liked Synchronization: Player heart adds to Library Liked Songs in real time', () async {
    final storage = MockStorageDatasource();
    final queueManager = QueueManager();

    final playerVm = AudioPlayerViewModel(
      audioDriver: FakeAudioDriver(),
      queueManager: queueManager,
      audioRepository: FakeAudioRepo(),
      storageDatasource: storage,
    );

    final libraryVm = LibraryViewModel(storageDatasource: storage);
    await libraryVm.loadLibrary();

    // Initial state: Library Liked Songs is empty
    expect(libraryVm.likedSongs, isEmpty);
    expect(playerVm.isLiked(sampleSong.id), isFalse);

    // 1. User taps heart button in Player screen
    await playerVm.toggleLike(sampleSong);

    // Pump stream events
    await Future.delayed(const Duration(milliseconds: 10));

    // Player heart is active
    expect(playerVm.isLiked(sampleSong.id), isTrue);

    // 2. Library Liked section immediately contains the song with full metadata!
    expect(libraryVm.likedSongs.length, 1);
    expect(libraryVm.likedSongs.first.id, equals(sampleSong.id));
    expect(libraryVm.likedSongs.first.title, equals('Chuttamalle'));
    expect(libraryVm.likedSongs.first.artist, equals('Anirudh Ravichander, Shilpa Rao'));

    // 3. User unlikes song from Library screen
    await libraryVm.toggleLike(sampleSong);
    await Future.delayed(const Duration(milliseconds: 10));

    // Library is empty
    expect(libraryVm.likedSongs, isEmpty);

    // Player heart is also updated to unliked
    expect(playerVm.isLiked(sampleSong.id), isFalse);

    playerVm.dispose();
    libraryVm.dispose();
  });

  test('AudioPlayerViewModel cycleQueueMode smoothly cycles through all 4 QueueModes', () {
    final storage = MockStorageDatasource();
    final queueManager = QueueManager();

    final playerVm = AudioPlayerViewModel(
      audioDriver: FakeAudioDriver(),
      queueManager: queueManager,
      audioRepository: FakeAudioRepo(),
      storageDatasource: storage,
    );

    // Initial default is blend
    expect(playerVm.queueMode, equals(QueueMode.blend));

    // 1st cycle -> discover
    expect(playerVm.cycleQueueMode(), equals(QueueMode.discover));
    expect(playerVm.queueMode, equals(QueueMode.discover));

    // 2nd cycle -> familiar
    expect(playerVm.cycleQueueMode(), equals(QueueMode.familiar));
    expect(playerVm.queueMode, equals(QueueMode.familiar));

    // 3rd cycle -> singleLanguage
    expect(playerVm.cycleQueueMode(), equals(QueueMode.singleLanguage));
    expect(playerVm.queueMode, equals(QueueMode.singleLanguage));

    // 4th cycle -> blend
    expect(playerVm.cycleQueueMode(), equals(QueueMode.blend));
    expect(playerVm.queueMode, equals(QueueMode.blend));

    playerVm.dispose();
  });
}
