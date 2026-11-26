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
        title: 'Saranga Dariya',
        artist: 'Mangli',
        album: 'Love Story - Telugu',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 210),
      ),
      SongModel(
        id: 'c_2',
        title: 'Aasa Kooda',
        artist: 'Sai Abhyankkar',
        album: 'Think Indie - Tamil',
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

      final sarangaDariya = calibrated.firstWhere((t) => t.song.title == 'Saranga Dariya');
      expect(sarangaDariya.badge, equals(QueueTrackBadge.discovery));

      final aasaKooda = calibrated.firstWhere((t) => t.song.title == 'Aasa Kooda');
      expect(aasaKooda.badge, equals(QueueTrackBadge.similarVibe));
    });

    test('Single language mode strictly quarantines off-language tracks', () {
      final calibrated = calibrator.calibrate(
        seedSong: seedSong,
        rawCandidates: rawCandidates,
        mode: QueueMode.singleLanguage,
        userLikedSongs: likedSongs,
        userHistory: historySongs,
      );

      // Chaleya (Hindi) and Aasa Kooda (Tamil) must be quarantined for Telugu seed
      final hasChaleya = calibrated.any((t) => t.song.title == 'Chaleya');
      expect(hasChaleya, isFalse, reason: 'Hindi track must be filtered out for Telugu seed');

      final hasAasaKooda = calibrated.any((t) => t.song.title == 'Aasa Kooda');
      expect(hasAasaKooda, isFalse, reason: 'Tamil track must be filtered out for Telugu seed');

      // Only Telugu tracks should remain
      expect(calibrated.every((t) => t.song.title != 'Chaleya' && t.song.title != 'Aasa Kooda'), isTrue);
    });

    test('Single language mode with Hindi seed strictly quarantines Telugu/English', () {
      final hindiSeed = SongModel(
        id: 'seed_hindi',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2 - Hindi',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 262),
      );

      final mixedCandidates = [
        SongModel(id: 'h_1', title: 'Kesariya', artist: 'Arijit Singh, Pritam', album: 'Brahmastra', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 240)),
        SongModel(id: 'h_2', title: 'Channa Mereya', artist: 'Arijit Singh', album: 'Ae Dil Hai Mushkil', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 280)),
        SongModel(id: 't_1', title: 'Saranga Dariya', artist: 'Mangli', album: 'Love Story', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 210)),
        SongModel(id: 'e_1', title: 'Shape of You', artist: 'Ed Sheeran', album: 'Divide', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 230)),
      ];

      final calibrated = calibrator.calibrate(
        seedSong: hindiSeed,
        rawCandidates: mixedCandidates,
        mode: QueueMode.singleLanguage,
      );

      expect(calibrated.any((t) => t.song.title == 'Saranga Dariya'), isFalse);
      expect(calibrated.any((t) => t.song.title == 'Shape of You'), isFalse);
      expect(calibrated.every((t) => t.song.title == 'Kesariya' || t.song.title == 'Channa Mereya'), isTrue);
    });

    test('Single language mode with English seed strictly quarantines regional Indian tracks', () {
      final englishSeed = SongModel(
        id: 'seed_en',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        thumbnailUrl: '',
        streamUrl: '',
        duration: const Duration(seconds: 200),
      );

      final mixedCandidates = [
        SongModel(id: 'e_1', title: 'Shape of You', artist: 'Ed Sheeran', album: 'Divide', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 230)),
        SongModel(id: 'e_2', title: 'Save Your Tears', artist: 'The Weeknd', album: 'After Hours', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 215)),
        SongModel(id: 'h_1', title: 'Kesariya', artist: 'Arijit Singh', album: 'Brahmastra', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 240)),
        SongModel(id: 't_1', title: 'Saranga Dariya', artist: 'Mangli', album: 'Love Story', thumbnailUrl: '', streamUrl: '', duration: const Duration(seconds: 210)),
      ];

      final calibrated = calibrator.calibrate(
        seedSong: englishSeed,
        rawCandidates: mixedCandidates,
        mode: QueueMode.singleLanguage,
      );

      expect(calibrated.any((t) => t.song.title == 'Kesariya'), isFalse);
      expect(calibrated.any((t) => t.song.title == 'Saranga Dariya'), isFalse);
      expect(calibrated.every((t) => t.song.title == 'Shape of You' || t.song.title == 'Save Your Tears'), isTrue);
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

