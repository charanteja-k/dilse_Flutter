import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dilse/core/constants/api_endpoints.dart';
import 'package:dilse/data/models/song_model.dart';

/// Contract for fetching songs from remote edge services.
abstract class CloudflareEdgeDatasource {
  Future<List<SongModel>> searchSongs(String query, {int limit = 20, int page = 1});
  Future<SongModel?> resolveSingleTrack(String title, {String? artist});
  Future<List<SongModel>> getRecommendations({String query = 'telugu', int limit = 15});
  Future<List<Map<String, dynamic>>> fetchYtmRadioTracks(String seedQuery, {int limit = 50});
}

/// Concrete implementation communicating with Cloudflare Workers V8 edge compute.
/// Follows strict MVVM Protocol & Invariant 1 (Context/Provider injectable, zero singletons).
class CloudflareEdgeDatasourceImpl implements CloudflareEdgeDatasource {
  final http.Client client;
  final String baseUrl;

  CloudflareEdgeDatasourceImpl({
    required this.client,
    this.baseUrl = ApiEndpoints.defaultCloudflareWorkerUrl,
  });

  @override
  Future<List<SongModel>> searchSongs(String query, {int limit = 20, int page = 1}) async {
    final uri = ApiEndpoints.jioSearchUri(
      query: query,
      limit: limit,
      page: page,
      baseUrl: baseUrl,
    );

    final response = await client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) => SongModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<SongModel?> resolveSingleTrack(String title, {String? artist}) async {
    final uri = ApiEndpoints.jioSingleTrackUri(
      title: title,
      artist: artist,
      baseUrl: baseUrl,
    );

    final response = await client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['match'] == true && decoded['data'] != null) {
        return SongModel.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
      }
    }
    return null;
  }

  @override
  Future<List<SongModel>> getRecommendations({String query = 'telugu', int limit = 15}) async {
    final uri = ApiEndpoints.jioRecommendationsUri(
      query: query,
      limit: limit,
      baseUrl: baseUrl,
    );

    final response = await client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) => SongModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchYtmRadioTracks(String seedQuery, {int limit = 50}) async {
    try {
      // 1. Resolve seed query to a YouTube Music videoId
      final searchUri = ApiEndpoints.ytmSearchUri(query: seedQuery, limit: 3, baseUrl: baseUrl);
      final searchRes = await client.get(searchUri).timeout(const Duration(seconds: 10));

      String? videoId;
      if (searchRes.statusCode == 200) {
        final decoded = jsonDecode(searchRes.body);
        if (decoded is List && decoded.isNotEmpty) {
          videoId = decoded.first['id']?.toString();
        }
      }

      if (videoId == null || videoId.isEmpty) return [];

      // 2. Fetch Google's radio co-listening automix graph
      final radioUri = ApiEndpoints.ytmRadioUri(videoId: videoId, limit: limit, baseUrl: baseUrl);
      final radioRes = await client.get(radioUri).timeout(const Duration(seconds: 10));

      if (radioRes.statusCode == 200) {
        final decoded = jsonDecode(radioRes.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
