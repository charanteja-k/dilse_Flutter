import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/core/services/queue_calibrator.dart';
import 'package:dilse/data/models/song_model.dart';

void main() {
  group('QueueCalibrator Unit Tests', () {
    const calibrator = QueueCalibrator();

    final seedSong = SongModel(
      id: 'seed_1',
      title: 'Chuttamalle',
      artist: 'Anirudh Ravichander, Shilpa Rao',
      album: 'Devara Part 1 - Telugu',
      thumbnailUrl: '',
      streamUrl: '',
      duration: const Duration(seconds: 222),
    );

    final likedSongs = [
      SongModel(
        id: 'liked_1',
        title: 'Maate Vinadhuga',
        artist: 'Sid Sriram',
        album: 'Taxiwaala',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 250),
      ),
      SongModel(
        id: 'liked_2',
        title: 'Samayama',
        artist: 'Anurag Kulkarni',
        album: 'Hi Nanna',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 240),
      ),
    ];

    final historySongs = [
      SongModel(
        id: 'hist_1',
        title: 'Kalyana Vayasu',
        artist: 'Anirudh Ravichander',
        album: 'CoCo',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 200),
      ),
      SongModel(
        id: 'hist_2',
        title: 'Inkem Inkem',
        artist: 'Sid Sriram',
        album: 'Geetha Govindam',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 260),
      ),
    ];

    final rawCandidates = [
      SongModel(
        id: 'c_1',
        title: 'Aasa Kooda',
        artist: 'Sai Abhyankkar',
        album: 'Think Indie',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 210),
      ),
      SongModel(
        id: 'c_2',
        title: 'KALYANI (Remix)',
        artist: 'ARJN',
        album: 'Club',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 180),
      ),
      SongModel(
        id: 'c_3',
        title: 'Maate Vinadhuga',
        artist: 'Sid Sriram',
        album: 'Taxiwaala',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 250),
      ),
      SongModel(
        id: 'c_4',
        title: 'Vellake',
        artist: 'Bharatt-Saurabh',
        album: 'Single',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 195),
      ),
      SongModel(
        id: 'c_5',
        title: 'Samayama',
        artist: 'Anurag Kulkarni',
        album: 'Hi Nanna',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 240),
      ),
      SongModel(
        id: 'c_6',
        title: 'Chaleya',
        artist: 'Arijit Singh, Anirudh Ravichander',
        album: 'Jawan (Hindi)',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 200),
      ),
    ];

    test('Blend mode accurately paces discoveries and familiar anchors', () {
      final calibrated = calibrator.calibrate(
        seedSong: seedSong,
        rawCandidates: rawCandidates,
        mode: QueueMode.blend,
        userLikedSongs: likedSongs,
        userHistory: historySongs,
      );

      expect(calibrated.isNotEmpty, isTrue);
      // Verify badges are assigned
      final sidSriramTrack = calibrated.firstWhere((t) => t.song.title == 'Maate Vinadhuga');
      expect(sidSriramTrack.badge, equals(QueueTrackBadge.topArtist));

      final aasaKooda = calibrated.firstWhere((t) => t.song.title == 'Aasa Kooda');
      expect(aasaKooda.badge, equals(QueueTrackBadge.discovery));
    });

    test('Single language mode quarantines off-language tracks', () {
      final calibrated = calibrator.calibrate(
        seedSong: seedSong,
        rawCandidates: rawCandidates,
        mode: QueueMode.singleLanguage,
        userLikedSongs: likedSongs,
        userHistory: historySongs,
      );

      // Chaleya (Hindi) should be filtered out in single language mode for Telugu seed
      final hasChaleya = calibrated.any((t) => t.song.title == 'Chaleya');
      expect(hasChaleya, isFalse);
    });

    test('Discover mode prioritizes fresh discoveries', () {
      final calibrated = calibrator.calibrate(
        seedSong: seedSong,
        rawCandidates: rawCandidates,
        mode: QueueMode.discover,
        userLikedSongs: likedSongs,
        userHistory: historySongs,
      );

      expect(calibrated.isNotEmpty, isTrue);
      expect(calibrated.first.badge, equals(QueueTrackBadge.discovery));
    });
  });
}

