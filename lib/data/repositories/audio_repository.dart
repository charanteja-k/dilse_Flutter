import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';

/// Repository contract for song fetching, search, and recommendation flows.
abstract class AudioRepository {
  Future<List<SongModel>> searchSongs(
    String query, {
    int limit = 20,
    int page = 1,
  });
  Future<List<AlbumModel>> searchAlbums(
    String query, {
    int limit = 15,
    int page = 1,
  });
  Future<List<ArtistModel>> searchArtists(
    String query, {
    int limit = 15,
    int page = 1,
  });
  Future<List<SongModel>> getAlbumDetails(String albumId);
  Future<
    ({List<SongModel> topSongs, List<AlbumModel> topAlbums, int followerCount})
  >
  getArtistDetails(String artistId);
  Future<SongModel?> resolveSingleTrack(String title, {String? artist});
  Future<List<SongModel>> getRecommendations({
    String query = 'telugu',
    int limit = 15,
  });

  /// Generates a high-fidelity queue powered by Google's recommendation graph
  /// resolved into 320kbps JioSaavn streams.
  Future<List<SongModel>> generateAlgorithmicQueue({
    required SongModel seedSong,
    int limit = 50,
  });

  /// Fetches synchronized and plain text lyrics across Edge, Backend, JioSaavn, YTM, and LRCLIB tiers.
  Future<({String? plainLyrics, String? syncedLyrics})> fetchLyrics({
    required String title,
    String? artist,
    Duration? duration,
    String? videoId,
  });
}
