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
    // 1. Query Google's collaborative filtering recommendation graph
    final seedQuery = seedSong.id.length == 11 && !seedSong.id.contains(' ')
        ? seedSong.id
        : '${seedSong.title} ${seedSong.artist}'.trim();
    final ytmTracks = await remoteDatasource.fetchYtmRadioTracks(seedQuery, limit: limit);

    final List<SongModel> queue = [seedSong];
    if (ytmTracks.isEmpty) return queue;

    final seenTitles = <String>{seedSong.title.toLowerCase().trim()};

    // 2. Populate 50-song progressive queue immediately with Google ML tracks
    for (final track in ytmTracks) {
      final id = (track['id'] ?? '').toString();
      final title = (track['title'] ?? '').toString().trim();
      final artist = (track['author'] ?? track['artist'] ?? '').toString().trim();
      final thumbnail = (track['thumbnail'] ?? track['thumbnailUrl'] ?? '').toString();
      final rawDuration = track['duration'];

      if (id.isEmpty || title.isEmpty) continue;
      final cleanTitleKey = title.toLowerCase().trim();
      if (seenTitles.contains(cleanTitleKey)) continue;
      seenTitles.add(cleanTitleKey);

      Duration parsedDur = Duration.zero;
      if (rawDuration is Duration) {
        parsedDur = rawDuration;
      } else if (rawDuration is num) {
        parsedDur = Duration(seconds: rawDuration.toInt());
      } else if (rawDuration is String) {
        final parsed = int.tryParse(rawDuration);
        if (parsed != null) {
          parsedDur = Duration(seconds: parsed);
        } else if (rawDuration.contains(':')) {
          final parts = rawDuration.trim().split(':');
          if (parts.length == 2) {
            parsedDur = Duration(minutes: int.tryParse(parts[0]) ?? 0, seconds: int.tryParse(parts[1]) ?? 0);
          } else if (parts.length == 3) {
            parsedDur = Duration(hours: int.tryParse(parts[0]) ?? 0, minutes: int.tryParse(parts[1]) ?? 0, seconds: int.tryParse(parts[2]) ?? 0);
          }
        }
      }

      queue.add(SongModel(
        id: id,
        title: title,
        artist: artist,
        album: 'DilSe Radio',
        thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
        streamUrl: '',
        duration: parsedDur,
        source: 'google_automix',
        bitrate: '320kbps',
      ));

      if (queue.length >= limit) break;
    }

    // 3. Proactively pre-resolve the immediate upcoming track for zero-latency handoff
    if (queue.length > 1) {
      final nextTrack = queue[1];
      try {
        final resolved = await remoteDatasource.resolveSingleTrack(
          nextTrack.title,
          artist: nextTrack.artist,
        );
        if (resolved != null && resolved.streamUrl.isNotEmpty) {
          queue[1] = nextTrack.copyWith(
            streamUrl: resolved.streamUrl,
            album: resolved.album.isNotEmpty ? resolved.album : nextTrack.album,
            thumbnailUrl: resolved.thumbnailUrl.isNotEmpty ? resolved.thumbnailUrl : nextTrack.thumbnailUrl,
            duration: resolved.duration > Duration.zero ? resolved.duration : nextTrack.duration,
          );
        }
      } catch (_) {}
    }

    return queue;
  }

  @override
  Future<({String? plainLyrics, String? syncedLyrics})> fetchLyrics({
    required String title,
    String? artist,
    Duration? duration,
    String? videoId,
  }) {
    return remoteDatasource.fetchLyrics(
      title: title,
      artist: artist,
      duration: duration,
      videoId: videoId,
    );
  }
}
