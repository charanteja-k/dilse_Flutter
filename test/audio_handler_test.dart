// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dilse/data/datasources/local/audio_handler.dart';
import 'package:dilse/data/models/song_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DilSeAudioHandler Lockscreen & Notification Controls', () {
    late DilSeAudioHandler handler;

    setUp(() {
      handler = DilSeAudioHandler();
    });

    tearDown(() async {
      await handler.disposeHandler();
    });

    test('Initializes with full systemActions and compact action indices', () {
      final state = handler.playbackState.value;
      expect(state.androidCompactActionIndices, equals([0, 1, 3]));
      expect(state.systemActions.contains(MediaAction.play), isTrue);
      expect(state.systemActions.contains(MediaAction.pause), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToPrevious), isTrue);
      expect(state.systemActions.contains(MediaAction.seek), isTrue);
    });

    test(
      'notifyLoading maintains compact actions, systemActions, and sets loading state',
      () {
        handler.notifyLoading(isLoading: true);
        final loadingState = handler.playbackState.value;
        expect(
          loadingState.processingState,
          equals(AudioProcessingState.loading),
        );
        expect(loadingState.androidCompactActionIndices, equals([0, 1, 3]));
        expect(loadingState.systemActions.contains(MediaAction.seek), isTrue);
        expect(
          loadingState.systemActions.contains(MediaAction.skipToNext),
          isTrue,
        );

        handler.notifyLoading(isLoading: false);
        final readyState = handler.playbackState.value;
        expect(readyState.processingState, equals(AudioProcessingState.ready));
        expect(readyState.androidCompactActionIndices, equals([0, 1, 3]));
      },
    );

    test(
      'updateMediaForSong properly updates mediaItem with title, artist, artwork',
      () {
        const song = SongModel(
          id: 'test_123',
          title: 'Samajavaragamana',
          artist: 'Sid Sriram',
          album: 'Ala Vaikunthapurramuloo',
          thumbnailUrl: 'https://i.ytimg.com/vi/test/hqdefault.jpg',
          streamUrl: 'https://aac.saavncdn.com/test.mp4',
          duration: Duration(minutes: 3, seconds: 40),
        );

        handler.updateMediaForSong(song);
        final item = handler.mediaItem.value;
        expect(item, isNotNull);
        expect(item!.id, equals('test_123'));
        expect(item.title, equals('Samajavaragamana'));
        expect(item.artist, equals('Sid Sriram'));
        expect(item.album, equals('Ala Vaikunthapurramuloo'));
        expect(item.duration, equals(const Duration(minutes: 3, seconds: 40)));
        expect(
          item.artUri,
          equals(Uri.parse('https://i.ytimg.com/vi/test/hqdefault.jpg')),
        );
      },
    );

    test(
      'Delegates play, pause, skipToNext, skipToPrevious to registered ViewModel handlers',
      () async {
        bool playCalled = false;
        bool pauseCalled = false;
        bool nextCalled = false;
        bool prevCalled = false;
        Duration? seekedPos;

        handler.onPlay = () async => playCalled = true;
        handler.onPause = () async => pauseCalled = true;
        handler.onSkipToNext = () async => nextCalled = true;
        handler.onSkipToPrevious = () async => prevCalled = true;
        handler.onSeek = (pos) async => seekedPos = pos;

        await handler.play();
        expect(playCalled, isTrue);

        await handler.pause();
        expect(pauseCalled, isTrue);

        await handler.skipToNext();
        expect(nextCalled, isTrue);

        await handler.skipToPrevious();
        expect(prevCalled, isTrue);

        await handler.seek(const Duration(seconds: 45));
        expect(seekedPos, equals(const Duration(seconds: 45)));
      },
    );

    test('click method handles MediaButton events seamlessly', () async {
      bool playCalled = false;
      bool nextCalled = false;
      bool prevCalled = false;

      handler.onPlay = () async => playCalled = true;
      handler.onSkipToNext = () async => nextCalled = true;
      handler.onSkipToPrevious = () async => prevCalled = true;

      await handler.click(MediaButton.media);
      expect(playCalled, isTrue);

      await handler.click(MediaButton.next);
      expect(nextCalled, isTrue);

      await handler.click(MediaButton.previous);
      expect(prevCalled, isTrue);
    });
  });
}
