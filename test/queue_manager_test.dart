import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/data/datasources/local/queue_manager.dart';
import 'package:dilse/data/models/song_model.dart';

void main() {
  group('QueueManager Unit Tests', () {
    late QueueManager queueManager;

    final songA = SongModel(
      id: '1',
      title: 'Song A',
      artist: 'Artist A',
      album: 'Album A',
      thumbnailUrl: '',
      streamUrl: 'http://example.com/a.mp4',
      duration: const Duration(seconds: 200),
    );

    final songB = SongModel(
      id: '2',
      title: 'Song B',
      artist: 'Artist B',
      album: 'Album B',
      thumbnailUrl: '',
      streamUrl: 'http://example.com/b.mp4',
      duration: const Duration(seconds: 210),
    );

    final songC = SongModel(
      id: '3',
      title: 'Song C',
      artist: 'Artist C',
      album: 'Album C',
      thumbnailUrl: '',
      streamUrl: 'http://example.com/c.mp4',
      duration: const Duration(seconds: 190),
    );

    setUp(() {
      queueManager = QueueManager();
    });

    test('Initial empty queue behaves correctly', () {
      expect(queueManager.currentSong, isNull);
      expect(queueManager.hasNext, isFalse);
      expect(queueManager.hasPrevious, isFalse);
      expect(queueManager.currentIndex, equals(-1));
    });

    test('setQueue sets initial index and queue order', () {
      queueManager.setQueue([songA, songB, songC], initialIndex: 1);

      expect(queueManager.currentQueue.length, equals(3));
      expect(queueManager.currentIndex, equals(1));
      expect(queueManager.currentSong, equals(songB));
      expect(queueManager.hasNext, isTrue);
      expect(queueManager.hasPrevious, isTrue);
    });

    test('skipToNext and skipToPrevious work in linear mode', () {
      queueManager.setQueue([songA, songB, songC]);

      expect(queueManager.currentSong, equals(songA));
      expect(queueManager.skipToNext(), equals(songB));
      expect(queueManager.skipToNext(), equals(songC));
      expect(queueManager.skipToNext(), isNull); // Reached end

      expect(queueManager.skipToPrevious(), equals(songB));
      expect(queueManager.skipToPrevious(), equals(songA));
      expect(queueManager.skipToPrevious(), isNull); // Reached start
    });

    test('RepeatMode.all loops seamlessly at queue bounds', () {
      queueManager.setQueue([songA, songB, songC]);
      queueManager.setRepeatMode(RepeatMode.all);

      queueManager.skipToIndex(2); // At song C
      expect(queueManager.currentSong, equals(songC));

      final loopedNext = queueManager.skipToNext();
      expect(loopedNext, equals(songA)); // Wrapped around to start

      final loopedPrev = queueManager.skipToPrevious();
      expect(loopedPrev, equals(songC)); // Wrapped around to end
    });

    test('RepeatMode.one retains current song upon skip', () {
      queueManager.setQueue([songA, songB, songC], initialIndex: 1);
      queueManager.setRepeatMode(RepeatMode.one);

      expect(queueManager.skipToNext(), equals(songB));
      expect(queueManager.skipToPrevious(), equals(songB));
    });

    test('Shuffle preserves active track at index 0 and un-shuffle restores original order', () {
      queueManager.setQueue([songA, songB, songC], initialIndex: 1); // active is songB

      queueManager.toggleShuffle();
      expect(queueManager.isShuffled, isTrue);
      expect(queueManager.currentSong, equals(songB));
      expect(queueManager.currentQueue.first, equals(songB));
      expect(queueManager.currentQueue.length, equals(3));

      queueManager.toggleShuffle();
      expect(queueManager.isShuffled, isFalse);
      expect(queueManager.currentQueue, equals([songA, songB, songC]));
      expect(queueManager.currentSong, equals(songB));
    });
  });
}

