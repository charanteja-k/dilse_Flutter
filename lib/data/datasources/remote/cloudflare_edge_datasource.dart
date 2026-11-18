import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dilse/core/constants/api_endpoints.dart';
import 'package:dilse/data/models/album_model.dart';
import 'package:dilse/data/models/artist_model.dart';
import 'package:dilse/data/models/song_model.dart';

/// Contract for fetching songs, albums, and artists from remote edge services.
abstract class CloudflareEdgeDatasource {
  Future<List<SongModel>> searchSongs(String query, {int limit = 20, int page = 1});
  Future<List<AlbumModel>> searchAlbums(String query, {int limit = 15, int page = 1});
  Future<List<ArtistModel>> searchArtists(String query, {int limit = 15, int page = 1});
  Future<List<SongModel>> getAlbumDetails(String albumId);
  Future<({List<SongModel> topSongs, List<AlbumModel> topAlbums, int followerCount})> getArtistDetails(String artistId);
  Future<SongModel?> resolveSingleTrack(String title, {String? artist});
  Future<List<SongModel>> getRecommendations({String query = 'telugu', int limit = 15});
  Future<List<Map<String, dynamic>>> fetchYtmRadioTracks(String seedQuery, {int limit = 50});
  Future<({String? plainLyrics, String? syncedLyrics})> fetchLyrics({
    required String title,
    String? artist,
    Duration? duration,
    String? videoId,
  });
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
  Future<List<AlbumModel>> searchAlbums(String query, {int limit = 15, int page = 1}) async {
    final uri = Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=$limit&p=$page&q=${Uri.encodeComponent(query)}',
    );

    try {
      final response = await client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['results'] is List) {
          return (decoded['results'] as List)
              .map((item) => AlbumModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<ArtistModel>> searchArtists(String query, {int limit = 15, int page = 1}) async {
    final uri = Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=search.getArtistResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=$limit&p=$page&q=${Uri.encodeComponent(query)}',
    );

    try {
      final response = await client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['results'] is List) {
          return (decoded['results'] as List)
              .map((item) => ArtistModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<SongModel>> getAlbumDetails(String albumId) async {
    final uri = ApiEndpoints.jioAlbumDetailsUri(albumId: albumId);
    try {
      final response = await client.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['list'] is List) {
          final albumTitle = _unescapeHtml((decoded['title'] ?? '').toString());
          String albumArt = (decoded['image'] ?? '').toString();
          if (albumArt.contains('150x150')) {
            albumArt = albumArt.replaceAll('150x150', '500x500');
          } else if (albumArt.contains('50x50')) {
            albumArt = albumArt.replaceAll('50x50', '500x500');
          }

          final songList = <SongModel>[];
          for (final raw in (decoded['list'] as List)) {
            if (raw is! Map) continue;
            final map = Map<String, dynamic>.from(raw);
            final title = _unescapeHtml((map['title'] ?? 'Unknown Track').toString());

            final moreInfo = map['more_info'] is Map ? map['more_info'] as Map : {};
            final artistMap = moreInfo['artistMap'] is Map ? moreInfo['artistMap'] as Map : {};
            final primaryArtistsList = artistMap['primary_artists'] is List ? artistMap['primary_artists'] as List : [];
            final primaryNames = primaryArtistsList
                .whereType<Map>()
                .map((a) => _unescapeHtml((a['name'] ?? '').toString()))
                .where((n) => n.isNotEmpty)
                .toList();

            final artist = primaryNames.isNotEmpty
                ? primaryNames.join(', ')
                : _unescapeHtml((map['subtitle'] ?? 'Unknown Artist').toString());

            final rawDuration = moreInfo['duration'] ?? map['duration'] ?? '0';
            final durSec = int.tryParse(rawDuration.toString()) ?? 0;

            String songThumb = (map['image'] ?? albumArt).toString();
            if (songThumb.contains('150x150')) {
              songThumb = songThumb.replaceAll('150x150', '500x500');
            } else if (songThumb.contains('50x50')) {
              songThumb = songThumb.replaceAll('50x50', '500x500');
            }

            songList.add(SongModel(
              id: (map['id'] ?? '').toString(),
              title: title,
              artist: artist,
              album: albumTitle.isNotEmpty ? albumTitle : 'DilSe',
              thumbnailUrl: songThumb.isNotEmpty ? songThumb : albumArt,
              streamUrl: '', // Resolved on-demand or pre-warmed
              duration: Duration(seconds: durSec),
              source: 'jiosaavn',
              bitrate: '320kbps',
            ));
          }
          return songList;
        }
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<({List<SongModel> topSongs, List<AlbumModel> topAlbums, int followerCount})> getArtistDetails(String artistId) async {
    final uri = ApiEndpoints.jioArtistDetailsUri(artistId: artistId, songCount: 30, albumCount: 20);
    try {
      final response = await client.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final rawFollowers = decoded['follower_count'] ?? decoded['fan_count'] ?? '0';
          final followerCount = int.tryParse(rawFollowers.toString()) ?? 0;

          // Parse top songs
          final topSongs = <SongModel>[];
          if (decoded['topSongs'] is List) {
            for (final raw in (decoded['topSongs'] as List)) {
              if (raw is! Map) continue;
              final map = Map<String, dynamic>.from(raw);
              final title = _unescapeHtml((map['title'] ?? 'Unknown Track').toString());

              final moreInfo = map['more_info'] is Map ? map['more_info'] as Map : {};
              final artistMap = moreInfo['artistMap'] is Map ? moreInfo['artistMap'] as Map : {};
              final primaryList = artistMap['primary_artists'] is List ? artistMap['primary_artists'] as List : [];
              final primaryNames = primaryList
                  .whereType<Map>()
                  .map((a) => _unescapeHtml((a['name'] ?? '').toString()))
                  .where((n) => n.isNotEmpty)
                  .toList();

              final artist = primaryNames.isNotEmpty
                  ? primaryNames.join(', ')
                  : _unescapeHtml((map['subtitle'] ?? 'Unknown Artist').toString());

              final album = _unescapeHtml((moreInfo['album'] ?? map['album'] ?? 'DilSe').toString());
              final rawDuration = moreInfo['duration'] ?? map['duration'] ?? '0';
              final durSec = int.tryParse(rawDuration.toString()) ?? 0;

              String songThumb = (map['image'] ?? '').toString();
              if (songThumb.contains('150x150')) {
                songThumb = songThumb.replaceAll('150x150', '500x500');
              } else if (songThumb.contains('50x50')) {
                songThumb = songThumb.replaceAll('50x50', '500x500');
              }

              topSongs.add(SongModel(
                id: (map['id'] ?? '').toString(),
                title: title,
                artist: artist,
                album: album,
                thumbnailUrl: songThumb,
                streamUrl: '',
                duration: Duration(seconds: durSec),
                source: 'jiosaavn',
                bitrate: '320kbps',
              ));
            }
          }

          // Parse top albums
          final topAlbums = <AlbumModel>[];
          if (decoded['topAlbums'] is List) {
            for (final raw in (decoded['topAlbums'] as List)) {
              if (raw is! Map) continue;
              topAlbums.add(AlbumModel.fromJson(Map<String, dynamic>.from(raw)));
            }
          }

          return (
            topSongs: topSongs,
            topAlbums: topAlbums,
            followerCount: followerCount,
          );
        }
      }
    } catch (_) {}
    return (topSongs: <SongModel>[], topAlbums: <AlbumModel>[], followerCount: 0);
  }

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
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

  static const Map<String, String> _ytmHeaders = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  static const Map<String, dynamic> _ytmContext = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': 'en',
      'gl': 'IN',
    }
  };

  @override
  Future<List<Map<String, dynamic>>> fetchYtmRadioTracks(String seedQuery, {int limit = 50}) async {
    try {
      String? videoId;
      final trimmed = seedQuery.trim();
      final isYtId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed);

      if (isYtId) {
        videoId = trimmed;
      } else {
        // 1. Resolve seed query to a YouTube Music videoId via InnerTube search
        final searchUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final searchRes = await client.post(
          searchUri,
          headers: _ytmHeaders,
          body: jsonEncode({
            'context': _ytmContext,
            'query': trimmed,
            'params': 'EgWKAQIIAWoKEAkQChADEAQQBQ%3D%3D',
          }),
        ).timeout(const Duration(seconds: 8));

        if (searchRes.statusCode == 200) {
          final searchData = jsonDecode(searchRes.body);
          videoId = _extractVideoIdFromYtmSearch(searchData);
        }

        // Secondary fallback search without strict protobuf filter for regional/complex queries
        if (videoId == null || videoId.isEmpty) {
          try {
            final fbRes = await client.post(
              searchUri,
              headers: _ytmHeaders,
              body: jsonEncode({
                'context': _ytmContext,
                'query': trimmed,
              }),
            ).timeout(const Duration(seconds: 6));
            if (fbRes.statusCode == 200) {
              final fbData = jsonDecode(fbRes.body);
              videoId = _extractVideoIdFromYtmSearch(fbData);
            }
          } catch (_) {}
        }
      }

      if (videoId == null || videoId.isEmpty) return [];

      // 2. Fetch Google's radio co-listening automix graph (RDAMVM$videoId)
      final List<Map<String, dynamic>> tracks = await _fetchInnerTubeNextTracks(videoId);

      // 3. Neural Continuation Chaining:
      // If primary neural automix returned fewer than 35 tracks, chain using the last track
      if (tracks.isNotEmpty && tracks.length < 35 && limit > tracks.length) {
        final nextSeedId = tracks.last['id'] as String?;
        if (nextSeedId != null && nextSeedId.length == 11) {
          final chained = await _fetchInnerTubeNextTracks(nextSeedId);
          for (final t in chained) {
            if (!tracks.any((e) => e['id'] == t['id'])) {
              tracks.add(t);
              if (tracks.length >= limit) break;
            }
          }
        }
      }

      return tracks.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchInnerTubeNextTracks(String videoId) async {
    try {
      final nextUri = Uri.parse('https://music.youtube.com/youtubei/v1/next');
      final nextRes = await client.post(
        nextUri,
        headers: _ytmHeaders,
        body: jsonEncode({
          'context': _ytmContext,
          'videoId': videoId,
          'playlistId': 'RDAMVM$videoId',
          'enablePersistentPlaylistPanel': true,
        }),
      ).timeout(const Duration(seconds: 8));

      if (nextRes.statusCode != 200) return [];

      final nextData = jsonDecode(nextRes.body);
      final tabs = nextData['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']
          ?['watchNextTabbedResultsRenderer']?['tabs'] as List?;
      final upNext = tabs?[0]?['tabRenderer']?['content']?['musicQueueRenderer']?['content']
          ?['playlistPanelRenderer']?['contents'] as List?;

      if (upNext == null) return [];

      final List<Map<String, dynamic>> tracks = [];
      for (final item in upNext) {
        final r = item['playlistPanelVideoRenderer'];
        if (r == null) continue;
        final vid = r['videoId'] as String?;
        if (vid == null || vid.isEmpty) continue;
        if (vid == videoId && tracks.isNotEmpty) continue;

        final title = r['title']?['runs']?[0]?['text'] as String? ?? 'Unknown Title';
        final artist = r['longBylineText']?['runs']?[0]?['text'] as String? ?? 'Unknown Artist';
        final length = r['lengthText']?['runs']?[0]?['text'] as String? ?? '';
        final thumbnails = r['thumbnail']?['thumbnails'] as List?;
        final thumbUrl = (thumbnails != null && thumbnails.isNotEmpty)
            ? thumbnails.last['url'] as String?
            : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';

        tracks.add({
          'id': vid,
          'title': title,
          'artist': artist,
          'author': artist,
          'thumbnail': thumbUrl ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          'duration': length,
          'source': 'google_automix',
        });
      }

      return tracks;
    } catch (_) {
      return [];
    }
  }

  static String? _extractVideoIdFromYtmSearch(dynamic searchData) {
    if (searchData is! Map) return null;
    final contents = searchData['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']
        ?['content']?['sectionListRenderer']?['contents'] as List?;
    if (contents != null) {
      for (final section in contents) {
        final items = (section['musicShelfRenderer']?['contents'] ??
            section['itemSectionRenderer']?['contents']) as List?;
        if (items != null && items.isNotEmpty) {
          for (final item in items) {
            final renderer = item['musicResponsiveListItemRenderer'];
            final playNav = renderer?['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                ?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
            final vid = playNav?['watchEndpoint']?['videoId'] as String? ??
                renderer?['playlistItemData']?['videoId'] as String?;
            if (vid != null && vid.isNotEmpty) return vid;
          }
        }
      }
    }
    return null;
  }

  @override
  Future<({String? plainLyrics, String? syncedLyrics})> fetchLyrics({
    required String title,
    String? artist,
    Duration? duration,
    String? videoId,
  }) async {
    final cleanT = _cleanTitle(title);
    final cleanA = artist != null ? _cleanArtist(artist) : '';
    final targetLang = _detectLanguage('$title ${artist ?? ''}');
    final durationSec = duration?.inSeconds;
    final safeHeaders = {'Accept': 'application/json'};

    final List<dynamic> candidatePool = [];
    final List<Future<void>> queries = [];

    // Level 1: LRCLIB Global Engine (Synchronized LRC & Plain Text)
    if (cleanT.isNotEmpty) {
      if (cleanA.isNotEmpty) {
        // Direct LRCLIB get API (with duration if available)
        queries.add(() async {
          try {
            final durParam = durationSec != null && durationSec > 0 ? '&duration=$durationSec' : '';
            final getUri = Uri.parse(
              'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanT)}&artist_name=${Uri.encodeComponent(cleanA)}$durParam',
            );
            final res = await client.get(getUri, headers: safeHeaders).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final decoded = jsonDecode(res.body);
              if (decoded is Map<String, dynamic> &&
                  (decoded['syncedLyrics'] != null || decoded['plainLyrics'] != null)) {
                candidatePool.add(decoded);
              }
            }
          } catch (_) {}
        }());

        // Search with cleanTitle + cleanArtist
        queries.add(() async {
          try {
            final searchUri = Uri.parse(
              'https://lrclib.net/api/search?q=${Uri.encodeComponent("$cleanT $cleanA")}',
            );
            final res = await client.get(searchUri, headers: safeHeaders).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final decoded = jsonDecode(res.body);
              if (decoded is List) {
                candidatePool.addAll(decoded);
              }
            }
          } catch (_) {}
        }());
      }

      // Search with track name only
      queries.add(() async {
        try {
          final searchTrackUri = Uri.parse(
            'https://lrclib.net/api/search?track_name=${Uri.encodeComponent(cleanT)}',
          );
          final res = await client.get(searchTrackUri, headers: safeHeaders).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is List) {
              candidatePool.addAll(decoded);
            }
          }
        } catch (_) {}
      }());
    }

    // Level 2: YouTube Music InnerTube Lyrics
    if (videoId != null && videoId.isNotEmpty) {
      queries.add(() async {
        final ytmCandidate = await _fetchYtmLyrics(videoId, cleanT, cleanA);
        if (ytmCandidate != null) {
          candidatePool.add(ytmCandidate);
        }
      }());
    }

    // Level 3: JioSaavn Official Lyrics (Indic Direct Catalog)
    if (cleanT.isNotEmpty) {
      queries.add(() async {
        final jioCandidate = await _fetchJioSaavnLyrics(cleanT, cleanA);
        if (jioCandidate != null) {
          candidatePool.add(jioCandidate);
        }
      }());
    }

    // Execute all 3 levels concurrently
    await Future.wait(queries);

    // Score and select best candidate
    final seenIds = <dynamic>{};
    Map<String, dynamic>? bestCandidate;
    int bestScore = 100;
    Map<String, dynamic>? bestSyncedCandidate;
    int bestSyncedScore = 100;

    for (final item in candidatePool) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id'] ?? '${map['trackName']}_${map['artistName']}';
      if (seenIds.contains(id)) continue;
      seenIds.add(id);

      final score = _scoreLyricsCandidate(
        targetTitle: cleanT,
        targetArtist: cleanA,
        targetDurationSec: durationSec,
        targetLang: targetLang,
        candidate: map,
      );

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = map;
      }

      final synced = (map['syncedLyrics'] as String?)?.trim();
      if (synced != null && synced.isNotEmpty && score > bestSyncedScore) {
        bestSyncedScore = score;
        bestSyncedCandidate = map;
      }
    }

    // Synced candidates ALWAYS supersede plain lyrics whenever available
    final chosenCandidate = bestSyncedCandidate ?? bestCandidate;

    if (chosenCandidate != null) {
      final synced = (chosenCandidate['syncedLyrics'] as String?)?.trim();
      final plain = (chosenCandidate['plainLyrics'] as String?)?.trim();
      return (
        plainLyrics: (plain != null && plain.isNotEmpty) ? plain : null,
        syncedLyrics: (synced != null && synced.isNotEmpty) ? synced : null,
      );
    }

    return (plainLyrics: null, syncedLyrics: null);
  }

  static String _cleanTitle(String raw) {
    var s = raw
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-');
    s = s.replaceAll(RegExp(r'\b(?:feat\.?|ft\.?)\s+[^(\]]+', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), ' ');
    s = s.replaceAll(
      RegExp(
        r'\b(official\s+video|official\s+music\s+video|official\s+lyric\s+video|lyric\s+video|'
        r'full\s+video\s+song|video\s+song|full\s+song|full\s+audio|audio\s+song|lyrics|'
        r'4k|hdr|remix|hd|promo|teaser|trailer|song)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    final parts = s.split(RegExp(r'\s*[|:/]\s*|\s+-\s+'));
    if (parts.isNotEmpty) {
      s = parts.first;
    }
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _cleanArtist(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\b(?:vevo|records|music|official|channel)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+-\s+Topic\b', caseSensitive: false), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _detectLanguage(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0C00 && code <= 0x0C7F) return 'telugu';
      if (code >= 0x0900 && code <= 0x097F) return 'hindi';
      if (code >= 0x0B80 && code <= 0x0BFF) return 'tamil';
      if (code >= 0x0C80 && code <= 0x0CFF) return 'kannada';
      if (code >= 0x0D00 && code <= 0x0D7F) return 'malayalam';
      if (code >= 0x0A00 && code <= 0x0A7F) return 'punjabi';
    }
    final lower = text.toLowerCase();
    if (lower.contains('telugu')) return 'telugu';
    if (lower.contains('hindi')) return 'hindi';
    if (lower.contains('tamil')) return 'tamil';
    return null;
  }

  static int _scoreLyricsCandidate({
    required String targetTitle,
    required String targetArtist,
    required int? targetDurationSec,
    required String? targetLang,
    required Map<String, dynamic> candidate,
  }) {
    final synced = (candidate['syncedLyrics'] as String?)?.trim();
    final plain = (candidate['plainLyrics'] as String?)?.trim();
    final text = (synced?.isNotEmpty == true ? synced! : (plain ?? '')).trim();
    if (text.isEmpty) return -9999;

    final lower = text.toLowerCase();
    if (lower.contains('[instrumental]') ||
        lower == 'instrumental' ||
        lower.contains('no lyrics available') ||
        lower.contains('lyrics not available')) {
      return -9999;
    }

    int score = 0;
    final candLang = _detectLanguage(text);
    if (targetLang != null && candLang != null) {
      if (candLang != targetLang) {
        return -9999;
      } else {
        score += 400;
      }
    }

    final candTrack = (candidate['trackName']?.toString() ?? '').toLowerCase();
    final candArtist = (candidate['artistName']?.toString() ?? '').toLowerCase();

    final cTitle = _cleanTitle(candTrack).toLowerCase();
    final tTitle = _cleanTitle(targetTitle).toLowerCase();
    if (cTitle == tTitle) {
      score += 250;
    } else if (cTitle.contains(tTitle) || tTitle.contains(cTitle)) {
      score += 150;
    } else {
      score -= 100;
    }

    if (targetArtist.isNotEmpty && candArtist.isNotEmpty) {
      final tTokens = targetArtist.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
      final cTokens = candArtist.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
      if (tTokens.intersection(cTokens).isNotEmpty) {
        score += 180;
      } else if (tTokens.isNotEmpty && cTokens.isNotEmpty) {
        score -= 250;
      }
    }

    final num? cDurNum = candidate['duration'] as num?;
    if (targetDurationSec != null && targetDurationSec > 0 && cDurNum != null && cDurNum > 0) {
      final diff = (cDurNum.toDouble() - targetDurationSec).abs();
      if (diff > 60) {
        return -9999;
      } else if (diff <= 4) {
        score += 120;
      } else if (diff <= 10) {
        score += 60;
      } else if (diff > 25) {
        score -= 300;
      }
    }

    if (synced != null && synced.isNotEmpty) {
      score += 300;
    }

    return score;
  }

  Future<Map<String, dynamic>?> _fetchJioSaavnLyrics(String cleanTitle, String cleanArtist) async {
    try {
      final query = '$cleanTitle $cleanArtist'.trim();
      final searchUrl = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&api_version=4&ctx=android&n=5&p=1&q=${Uri.encodeComponent(query)}',
      );
      final res = await client.get(searchUrl, headers: {
        'User-Agent': 'SaavnAndroid/9.0.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final results = decoded['results'] as List?;
        if (results != null) {
          for (final r in results) {
            final id = r['id']?.toString();
            final hasLyrics = r['more_info']?['has_lyrics']?.toString() == 'true' ||
                r['has_lyrics']?.toString() == 'true';
            if (id == null || !hasLyrics) continue;

            final lyricsUrl = Uri.parse(
              'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$id&ctx=web6dot0&api_version=4&_format=json',
            );
            final lRes = await client.get(lyricsUrl, headers: {
              'User-Agent': 'SaavnAndroid/9.0.0',
              'Accept': 'application/json',
            }).timeout(const Duration(seconds: 4));

            if (lRes.statusCode == 200) {
              final lData = jsonDecode(lRes.body);
              final rawLyrics = lData['lyrics']?.toString();
              if (rawLyrics != null && rawLyrics.trim().length > 10) {
                final clean = rawLyrics
                    .replaceAll(RegExp(r'<br\s*[\/]?>', caseSensitive: false), '\n')
                    .replaceAll('&quot;', '"')
                    .replaceAll('&#039;', "'")
                    .replaceAll('&amp;', '&')
                    .replaceAll(RegExp(r'<[^>]+>'), '')
                    .trim();

                return {
                  'id': 'jio_$id',
                  'trackName': r['title']?.toString() ?? cleanTitle,
                  'artistName': r['more_info']?['artistMap']?['primary_artists']?[0]?['name']?.toString() ??
                      r['subtitle']?.toString() ??
                      cleanArtist,
                  'plainLyrics': clean,
                  'syncedLyrics': null,
                  'source': 'jiosaavn_official',
                };
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchYtmLyrics(String videoId, String cleanTitle, String cleanArtist) async {
    try {
      final nextUri = Uri.parse('https://music.youtube.com/youtubei/v1/next');
      final headers = {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
      };
      final context = {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.01.00',
          'hl': 'en',
          'gl': 'IN',
        }
      };

      final nextRes = await client
          .post(
            nextUri,
            headers: headers,
            body: jsonEncode({
              'videoId': videoId,
              'context': context,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (nextRes.statusCode == 200) {
        final nextData = jsonDecode(nextRes.body);
        final tabs = nextData['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']
            ?['watchNextTabbedResultsRenderer']?['tabs'] as List?;
        String? lyricsBrowseId;
        if (tabs != null) {
          for (final t in tabs) {
            final tab = t['tabRenderer'];
            final tabTitle = tab?['title']?.toString().toLowerCase() ?? '';
            if (tabTitle.contains('lyric')) {
              lyricsBrowseId = tab?['endpoint']?['browseEndpoint']?['browseId']?.toString();
              break;
            }
          }
        }

        if (lyricsBrowseId != null && lyricsBrowseId.isNotEmpty) {
          final browseUri = Uri.parse('https://music.youtube.com/youtubei/v1/browse');
          final browseRes = await client
              .post(
                browseUri,
                headers: headers,
                body: jsonEncode({
                  'browseId': lyricsBrowseId,
                  'context': context,
                }),
              )
              .timeout(const Duration(seconds: 4));

          if (browseRes.statusCode == 200) {
            final browseData = jsonDecode(browseRes.body);
            final section = browseData['contents']?['sectionListRenderer']?['contents']?[0]?['musicDescriptionShelfRenderer'];
            final runs = section?['description']?['runs'] as List?;
            if (runs != null) {
              final text = runs.map((r) => r['text']?.toString() ?? '').join('').trim();
              if (text.length > 10) {
                return {
                  'id': 'ytm_$videoId',
                  'trackName': cleanTitle,
                  'artistName': cleanArtist,
                  'plainLyrics': text,
                  'syncedLyrics': null,
                  'source': 'youtube_music_official',
                };
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
