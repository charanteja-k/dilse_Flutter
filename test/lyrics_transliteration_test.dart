import 'package:dilse/core/services/lyrics_transliteration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LyricsTransliterationService', () {
    test('hasIndicScript correctly identifies Brahmic scripts', () {
      expect(LyricsTransliterationService.hasIndicScript('రాజమండ్రి'), isTrue);
      expect(LyricsTransliterationService.hasIndicScript('तुम ही हो'), isTrue);
      expect(LyricsTransliterationService.hasIndicScript('கண்ணம்மா'), isTrue);
      expect(
        LyricsTransliterationService.hasIndicScript('Hello world! 123'),
        isFalse,
      );
    });

    test(
      'transliterateText converts Telugu to phonetic English pronunciation',
      () {
        final input = 'రాజమండ్రి రాగమంజరి';
        final romanized = LyricsTransliterationService.transliterateText(input);
        expect(romanized.toLowerCase(), contains('raajamamdri'));
        expect(romanized.toLowerCase(), contains('raagamamjari'));
      },
    );

    test(
      'transliterateText converts Devanagari to phonetic English pronunciation',
      () {
        final input = 'तुम ही हो';
        final romanized = LyricsTransliterationService.transliterateText(input);
        expect(romanized.toLowerCase(), contains('tum'));
        expect(romanized.toLowerCase(), contains('ho'));
      },
    );

    test('toTeluguScript converts Romanized Tenglish into Telugu script', () {
      final input = 'samajavaragamana';
      final telugu = LyricsTransliterationService.toTeluguScript(input);
      expect(LyricsTransliterationService.hasIndicScript(telugu), isTrue);
      expect(telugu, contains('సమజవరగమన'));
    });

    test('transliterateLrc preserves timestamp tags accurately', () {
      final lrc = '''
[00:12.34] రాజమండ్రి
[01:05.67] రాగమంజరి
''';
      final transliterated = LyricsTransliterationService.transliterateLrc(lrc);
      expect(transliterated, contains('[00:12.34]'));
      expect(transliterated, contains('[01:05.67]'));
      expect(transliterated.toLowerCase(), contains('raajamamdri'));
    });
  });
}
