import 'dart:convert';
import 'package:dilse/data/datasources/remote/cloudflare_edge_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('3-Level Lyrics Fetching Engine (LRCLIB, YouTube Music, JioSaavn)', () {
    test('Prioritizes synchronized LRC lyrics from LRCLIB over plain text', () async {
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        if (url.contains('lrclib.net/api/get')) {
          return http.Response(
            jsonEncode({
              'id': 101,
              'trackName': 'Samajavaragamana',
              'artistName': 'Sid Sriram',
              'duration': 214,
              'plainLyrics': 'Nuvvante naaku chala istam',
              'syncedLyrics': '[00:15.20] Nuvvante naaku chala istam\n[00:20.50] Samajavaragamana',
            }),
            200,
          );
        }

        return http.Response('[]', 200);
      });

      final datasource = CloudflareEdgeDatasourceImpl(client: mockClient);
      final result = await datasource.fetchLyrics(
        title: 'Samajavaragamana (From "Ala Vaikunthapurramuloo")',
        artist: 'Sid Sriram',
        duration: const Duration(seconds: 214),
      );

      expect(result.syncedLyrics, isNotNull);
      expect(result.syncedLyrics, contains('[00:15.20]'));
      expect(result.syncedLyrics, contains('Samajavaragamana'));
    });

    test('Falls back to JioSaavn official catalog when LRCLIB has no matches', () async {
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        // LRCLIB returns empty
        if (url.contains('lrclib.net')) {
          return http.Response('[]', 200);
        }

        // JioSaavn search
        if (url.contains('jiosaavn.com') && url.contains('search.getResults')) {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 'jio_123',
                  'title': 'Buttabomma',
                  'subtitle': 'Armaan Malik',
                  'has_lyrics': 'true',
                }
              ]
            }),
            200,
          );
        }

        // JioSaavn lyrics
        if (url.contains('jiosaavn.com') && url.contains('lyrics.getLyrics')) {
          return http.Response(
            jsonEncode({
              'lyrics': 'Inkem inkem inkem kaavaale<br/>Chalu chalu idhi chalu',
            }),
            200,
          );
        }

        return http.Response('[]', 200);
      });

      final datasource = CloudflareEdgeDatasourceImpl(client: mockClient);
      final result = await datasource.fetchLyrics(
        title: 'Buttabomma',
        artist: 'Armaan Malik',
      );

      expect(result.plainLyrics, contains('Inkem inkem inkem kaavaale'));
      expect(result.plainLyrics, contains('\n'));
    });
  });
}

