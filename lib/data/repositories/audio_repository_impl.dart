import 'package:dilse/data/datasources/remote/cloudflare_edge_datasource.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/data/repositories/audio_repository.dart';

/// Implementation of AudioRepository.
/// Follows MVVM tripartite protocol and zero-singleton architecture.
class AudioRepositoryImpl implements AudioRepository {
  final CloudflareEdgeDatasource remoteDatasource;

  AudioRepositoryImpl({required this.remoteDatasource});

  @override
  Future<List<SongModel>> searchSongs(String query, {int limit = 20, int page = 1}) {
    return remoteDatasource.searchSongs(query, limit: limit, page: page);
  }

  @override
  Future<SongModel?> resolveSingleTrack(String title, {String? artist}) {
    return remoteDatasource.resolveSingleTrack(title, artist: artist);
  }

  @override
  Future<List<SongModel>> getRecommendations({String query = 'telugu', int limit = 15}) {
    return remoteDatasource.getRecommendations(query: query, limit: limit);
  }

  @override
  Future<List<SongModel>> generateAlgorithmicQueue({
    required SongModel seedSong,
    int limit = 50,
  }) async {
    // 1. Query Google's recommendation graph
    final seedQuery = '${seedSong.title} ${seedSong.artist}'.trim();
    final ytmTracks = await remoteDatasource.fetchYtmRadioTracks(seedQuery, limit: limit);

    final List<SongModel> queue = [seedSong];
    if (ytmTracks.isEmpty) return queue;

    // 2. Resolve Google-recommended tracks into JioSaavn 320k streams in concurrent batches
    const batchSize = 5;
    for (int i = 0; i < ytmTracks.length; i += batchSize) {
      final batch = ytmTracks.sublist(i, (i + batchSize).clamp(0, ytmTracks.length));
      final futures = batch.map((track) async {
        final title = (track['title'] ?? '').toString();
        final artist = (track['author'] ?? track['artist'] ?? '').toString();
        if (title.isEmpty) return null;

        // Try single track resolver
        final resolved = await remoteDatasource.resolveSingleTrack(title, artist: artist);
        if (resolved != null && resolved.streamUrl.isNotEmpty) {
          return resolved;
        }

        // Fallback to top studio search match
        final searchResults = await remoteDatasource.searchSongs('$title $artist', limit: 1);
        if (searchResults.isNotEmpty && searchResults.first.streamUrl.isNotEmpty) {
          return searchResults.first;
        }
        return null;
      });

      final results = await Future.wait(futures);
      for (final song in results) {
        if (song != null && !queue.any((s) => s.id == song.id || s.title.toLowerCase() == song.title.toLowerCase())) {
          queue.add(song);
        }
      }

      if (queue.length >= limit) break;
    }

    return queue;
  }

  @override
  Future<({String? plainLyrics, String? syncedLyrics})> fetchLyrics({
    required String title,
    String? artist,
  }) {
    return remoteDatasource.fetchLyrics(title: title, artist: artist);
  }
}
