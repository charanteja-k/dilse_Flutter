// ignore_for_file: avoid_print
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dilse/data/datasources/remote/cloudflare_edge_datasource.dart';
import 'package:dilse/data/repositories/audio_repository_impl.dart';
import 'package:dilse/data/datasources/local/queue_manager.dart';
import 'package:dilse/data/datasources/local/soloud_audio_driver.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/features/audio_player/viewmodels/audio_player_viewmodel.dart';

class MockAudioDriver implements SoLoudAudioDriver {
  final _stateCtrl = StreamController<PlaybackState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration>.broadcast();

  PlaybackState _state = PlaybackState.idle;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  SongModel? activeSong;

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
    activeSong = song;
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

void main() {
  SongModel createTestSong(String id, String title, String artist, {String album = 'Test Album'}) {
    return SongModel(
      id: id,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: 'https://i.ytimg.com/vi/test/hqdefault.jpg',
      streamUrl: '',
      duration: const Duration(minutes: 3, seconds: 30),
    );
  }

  group('Mobile Real-World Stress Test: Rapid Song Switching & Queue Generation', () {
    late http.Client client;
    late CloudflareEdgeDatasourceImpl datasource;
    late AudioRepositoryImpl repository;
    late QueueManager queueManager;
    late MockAudioDriver audioDriver;
    late AudioPlayerViewModel viewModel;

    setUp(() {
      client = http.Client();
      datasource = CloudflareEdgeDatasourceImpl(client: client);
      repository = AudioRepositoryImpl(remoteDatasource: datasource);
      queueManager = QueueManager();
      audioDriver = MockAudioDriver();
      viewModel = AudioPlayerViewModel(
        audioDriver: audioDriver,
        queueManager: queueManager,
        audioRepository: repository,
      );
    });

    tearDown(() {
      viewModel.dispose();
      client.close();
    });

    test('Test 1: Rapid 3-song switch within 300ms — Last song MUST generate full queue and not get dropped', () async {
      print('\n📱 [Mobile Test 1] Simulating user tapping Song 1, then Song 2, then Song 3 rapidly...');

      final s1 = createTestSong('s1', 'Kesariya', 'Arijit Singh', album: 'Brahmastra');
      final s2 = createTestSong('s2', 'Apna Bana Le', 'Arijit Singh', album: 'Bhediya');
      final s3 = createTestSong('s3', 'Channa Mereya', 'Pritam, Arijit Singh', album: 'Ae Dil Hai Mushkil');

      // Tap Song 1
      print('  User taps Song 1: "${s1.title}"');
      viewModel.playSong(s1);

      // 150ms later, user taps Song 2
      await Future.delayed(const Duration(milliseconds: 150));
      print('  User taps Song 2: "${s2.title}" (Song 1 fetch still inflight)');
      viewModel.playSong(s2);

      // 150ms later, user taps Song 3 and stays there
      await Future.delayed(const Duration(milliseconds: 150));
      print('  User taps Song 3: "${s3.title}" (Song 2 fetch still inflight)');
      viewModel.playSong(s3);

      expect(viewModel.currentSong?.title, equals(s3.title), reason: 'Active song must be Song 3');

      // Wait for Song 3 queue to finish loading
      print('  Waiting for Song 3 background queue generation to complete...');
      int attempts = 0;
      while (viewModel.queue.length <= 1 && attempts < 40) {
        await Future.delayed(const Duration(milliseconds: 250));
        attempts++;
      }

      print('  Final Queue Length for Song 3: ${viewModel.queue.length}');
      expect(viewModel.queue.length, greaterThan(1), reason: 'Song 3 queue MUST NOT hit a wall or be dropped!');
      expect(viewModel.queue.first.title, equals(s3.title), reason: 'Queue head must be Song 3');

      // Verify that Song 1 or Song 2 did not pollute Song 3's queue head
      print('  ✅ PASS: Song 3 successfully grabbed a queue of ${viewModel.queue.length} songs despite rapid skipping!');
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('Test 2: Complex Cluttered Regional Titles (Telugu, Hindi, Tamil) generate robust queue', () async {
      print('\n📱 [Mobile Test 2] Testing songs with cluttered metadata, film credits, and brackets...');

      final clutteredSeeds = [
        createTestSong('c1', 'Samajavaragamana - Male (From "Ala Vaikunthapurramuloo")', 'Sid Sriram, Thaman S', album: 'Ala Vaikunthapurramuloo'),
        createTestSong('c2', 'Tum Hi Ho (From "Aashiqui 2") [Remix]', 'Mithoon, Arijit Singh', album: 'Aashiqui 2'),
        createTestSong('c3', 'Arabic Kuthu - Halamithi Habibo (From "Beast") [Tamil]', 'Anirudh Ravichander, Jonita Gandhi', album: 'Beast'),
      ];

      for (int i = 0; i < clutteredSeeds.length; i++) {
        final seed = clutteredSeeds[i];
        print('\n  Testing Cluttered Seed #${i + 1}: "${seed.title}" by "${seed.artist}"');
        final sw = Stopwatch()..start();

        await viewModel.playSong(seed);

        int attempts = 0;
        while (viewModel.queue.length <= 1 && attempts < 40) {
          await Future.delayed(const Duration(milliseconds: 250));
          attempts++;
        }
        sw.stop();

        print('    Finished in ${sw.elapsedMilliseconds}ms -> Queue size: ${viewModel.queue.length}');
        expect(viewModel.queue.length, greaterThan(1), reason: 'Queue for "${seed.title}" must not be empty');
        print('    Next up in queue: "${viewModel.queue[1].title}" by "${viewModel.queue[1].artist}"');
        print('    ✅ PASS');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Test 3: Stress Loop: 5 rapid consecutive skips followed by playback 3 times in a row', () async {
      print('\n📱 [Mobile Test 3] Stress Loop: Skipping 5 songs in a burst, 3 times in a row...');

      final testPool = [
        createTestSong('p1', 'Buttabomma', 'Armaan Malik', album: 'Ala Vaikunthapurramuloo'),
        createTestSong('p2', 'Ramuloo Ramulaa', 'Anurag Kulkarni', album: 'Ala Vaikunthapurramuloo'),
        createTestSong('p3', 'Inkem Inkem', 'Sid Sriram', album: 'Geetha Govindam'),
        createTestSong('p4', 'Oo Antava', 'Indravathi Chauhan', album: 'Pushpa'),
        createTestSong('p5', 'Srivalli', 'Sid Sriram', album: 'Pushpa'),
        createTestSong('p6', 'Kurchi Madathapetti', 'Thaman S, Mahesh Babu', album: 'Guntur Kaaram'),
        createTestSong('p7', 'Chitti', 'Ram Miriyala', album: 'Jathi Ratnalu'),
        createTestSong('p8', 'Priya Mithunam', 'Anurag Kulkarni', album: 'Adipurush'),
      ];

      for (int round = 1; round <= 3; round++) {
        print('\n  --- ROUND $round of 3 ---');

        // Burst 4 skips
        for (int i = 0; i < 4; i++) {
          final song = testPool[(round * 2 + i) % testPool.length];
          viewModel.playSong(song);
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 5th song settles and user listens
        final settleSong = testPool[(round * 3) % testPool.length];
        print('  User settles on: "${settleSong.title}"');
        viewModel.playSong(settleSong);

        int attempts = 0;
        while (viewModel.queue.length <= 1 && attempts < 40) {
          await Future.delayed(const Duration(milliseconds: 250));
          attempts++;
        }

        print('  Round $round Settle Queue Size: ${viewModel.queue.length}');
        expect(viewModel.queue.length, greaterThan(1), reason: 'Round $round MUST successfully form a queue');
        expect(viewModel.queue.first.title, equals(settleSong.title));
        print('  Round $round ✅ PASS');
      }
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
