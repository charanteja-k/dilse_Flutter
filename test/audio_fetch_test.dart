import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dilse/data/datasources/remote/cloudflare_edge_datasource.dart';
import 'package:dilse/data/repositories/audio_repository_impl.dart';

void main() {
  group('Audio Fetching Live Integration Tests', () {
    late http.Client httpClient;
    late CloudflareEdgeDatasource datasource;
    late AudioRepositoryImpl repository;

    setUp(() {
      httpClient = http.Client();
      datasource = CloudflareEdgeDatasourceImpl(client: httpClient);
      repository = AudioRepositoryImpl(remoteDatasource: datasource);
    });

    tearDown(() {
      httpClient.close();
    });

    test('searchSongs returns valid SongModel list with 320kbps streams', () async {
      final songs = await repository.searchSongs('Kesariya', limit: 5);

      expect(songs, isNotEmpty);
      final firstSong = songs.first;
      expect(firstSong.id, isNotEmpty);
      expect(firstSong.title.toLowerCase(), contains('kesariya'));
      expect(firstSong.streamUrl, startsWith('http'));
      expect(firstSong.bitrate, equals('320kbps'));
    });

    test('resolveSingleTrack matches and fetches stream details', () async {
      final song = await repository.resolveSingleTrack('Kesariya', artist: 'Arijit Singh');

      expect(song, isNotNull);
      expect(song!.title, isNotEmpty);
      expect(song.streamUrl, contains('.mp4'));
      expect(song.thumbnailUrl, startsWith('http'));
    });

    test('getRecommendations returns valid regional discovery songs', () async {
      final recommendations = await repository.getRecommendations(query: 'telugu', limit: 5);

      expect(recommendations, isNotEmpty);
      expect(recommendations.length, inInclusiveRange(1, 5));
      expect(recommendations.first.streamUrl, isNotEmpty);
    });
  });
}

