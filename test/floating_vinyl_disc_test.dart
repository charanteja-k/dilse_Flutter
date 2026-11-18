import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/core/theme/app_theme.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/features/audio_player/views/floating_vinyl_disc.dart';

void main() {
  final testSong = SongModel(
    id: 'test_1',
    title: 'Pushpa Pushpa',
    artist: 'Devi Sri Prasad',
    album: 'Pushpa 2',
    thumbnailUrl: '',
    streamUrl: 'https://example.com/audio.m4a',
    duration: const Duration(minutes: 3, seconds: 30),
  );

  Widget createTestWidget({
    required bool isVisible,
    required bool isPlaying,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Stack(
          children: [
            FloatingVinylDisc(
              isVisible: isVisible,
              song: testSong,
              isPlaying: isPlaying,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  group('FloatingVinylDisc Widget Tests', () {
    testWidgets('Renders when isVisible is true', (tester) async {
      await tester.pumpWidget(
        createTestWidget(isVisible: true, isPlaying: true),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(FloatingVinylDisc), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingVinylDisc),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Tapping the disc fires onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestWidget(
          isVisible: true,
          isPlaying: true,
          onTap: () {
            tapped = true;
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byType(FloatingVinylDisc));
      await tester.pump(const Duration(milliseconds: 350));

      expect(tapped, isTrue);
    });

    testWidgets('Dragging leftwards past midpoint snaps to left dock', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(isVisible: true, isPlaying: true),
      );
      await tester.pump(const Duration(milliseconds: 350));

      // Drag leftwards past the midpoint
      await tester.drag(find.byType(FloatingVinylDisc), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 350));

      final finalPos = tester.getTopLeft(find.byType(FloatingVinylDisc));

      // The disc should have snapped to the left dock (16.0)
      expect(finalPos.dx, equals(16.0));
    });
  });
}
