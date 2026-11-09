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
}
