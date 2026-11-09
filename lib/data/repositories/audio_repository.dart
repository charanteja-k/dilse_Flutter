import '../models/song_model.dart';

/// Repository contract for song fetching, search, and recommendation flows.
abstract class AudioRepository {
  Future<List<SongModel>> searchSongs(String query, {int limit = 20, int page = 1});
  Future<SongModel?> resolveSingleTrack(String title, {String? artist});
  Future<List<SongModel>> getRecommendations({String query = 'telugu', int limit = 15});
}

