/// Central API endpoints and routing configuration for DilSe audio services.
/// Zero singletons - provides static URL generator methods and fallback constants.
class ApiEndpoints {
  static const String defaultCloudflareWorkerUrl =
      'https://dilse-edge-stream.charanteja-kondakalla030206.workers.dev';

  static const String defaultRenderBackendUrl =
      'https://music-backend-4kel.onrender.com';

  /// Primary JioSaavn catalog search via Cloudflare Edge Worker (instant, zero cold start).
  static Uri jioSearchUri({
    required String query,
    int limit = 20,
    int page = 1,
    String baseUrl = defaultCloudflareWorkerUrl,
  }) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$cleanBase/jio/search?q=${Uri.encodeComponent(query)}&limit=$limit&page=$page',
    );
  }

  /// Single-track JioSaavn metadata & 320k stream resolver.
  static Uri jioSingleTrackUri({
    required String title,
    String? artist,
    String baseUrl = defaultCloudflareWorkerUrl,
  }) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final buffer = StringBuffer(
      '$cleanBase/jio?title=${Uri.encodeComponent(title)}',
    );
    if (artist != null && artist.isNotEmpty) {
      buffer.write('&artist=${Uri.encodeComponent(artist)}');
    }
    return Uri.parse(buffer.toString());
  }

  /// Language-aware recommendations for Home feeds and Discover cards.
  static Uri jioRecommendationsUri({
    required String query,
    String language = 'telugu',
    int limit = 15,
    String baseUrl = defaultCloudflareWorkerUrl,
  }) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$cleanBase/jio/recommendations?q=${Uri.encodeComponent(query)}&language=${Uri.encodeComponent(language)}&limit=$limit',
    );
  }

  /// Cloudflare Edge synced LRC / plain text lyrics endpoint.
  static Uri lyricsUri({
    required String title,
    String? artist,
    String baseUrl = defaultCloudflareWorkerUrl,
  }) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final buffer = StringBuffer(
      '$cleanBase/lyrics?title=${Uri.encodeComponent(title)}',
    );
    if (artist != null && artist.isNotEmpty) {
      buffer.write('&artist=${Uri.encodeComponent(artist)}');
    }
    return Uri.parse(buffer.toString());
  }
}

