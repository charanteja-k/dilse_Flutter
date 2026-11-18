import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../models/app_update_info.dart';

/// Custom exception for GitHub Releases API failures with user-actionable hints.
class GithubReleaseException implements Exception {
  final String message;
  final int? statusCode;

  const GithubReleaseException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

abstract class GithubUpdateDatasource {
  Future<GitHubReleaseItem?> fetchLatestRelease({
    required String owner,
    required String repo,
  });

  Future<List<GitHubReleaseItem>> fetchAllReleases({
    required String owner,
    required String repo,
    int perPage = 30,
  });
}

/// Pure HTTP datasource fetching GitHub Releases without static singletons.
class GithubUpdateDatasourceImpl implements GithubUpdateDatasource {
  final http.Client client;

  const GithubUpdateDatasourceImpl({required this.client});

  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'DilSe-Flutter-Updater',
  };

  @override
  Future<GitHubReleaseItem?> fetchLatestRelease({
    required String owner,
    required String repo,
  }) async {
    final uri = ApiEndpoints.githubLatestReleaseUri(owner: owner, repo: repo);
    final response = await client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return _parseRelease(decoded);
      }
      return null;
    }

    // Fallback: GitHub returns 404 on /releases/latest when a repo is private,
    // has 0 releases, or only contains pre-releases. Query /releases to disambiguate.
    if (response.statusCode == 404) {
      final releases = await fetchAllReleases(
        owner: owner,
        repo: repo,
        perPage: 10,
      );
      final nonDrafts = releases.where((r) => !r.isDraft).toList();
      if (nonDrafts.isNotEmpty) {
        return nonDrafts.first;
      }
      return null;
    }

    throw _mapHttpError(response.statusCode, owner, repo);
  }

  @override
  Future<List<GitHubReleaseItem>> fetchAllReleases({
    required String owner,
    required String repo,
    int perPage = 30,
  }) async {
    final uri = ApiEndpoints.githubReleasesUri(
      owner: owner,
      repo: repo,
      perPage: perPage,
    );
    final response = await client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is! List<dynamic>) return const [];

      final releases = <GitHubReleaseItem>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final parsed = _parseRelease(entry);
          if (parsed != null && !parsed.isDraft) {
            releases.add(parsed);
          }
        }
      }
      return releases;
    }

    throw _mapHttpError(response.statusCode, owner, repo);
  }

  GithubReleaseException _mapHttpError(
    int statusCode,
    String owner,
    String repo,
  ) {
    if (statusCode == 404) {
      return GithubReleaseException(
        'Repository "$owner/$repo" not found or is private. Point to a public GitHub repo to fetch releases.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 403 || statusCode == 429) {
      return GithubReleaseException(
        'GitHub API rate limit reached. Try again shortly.',
        statusCode: statusCode,
      );
    }
    return GithubReleaseException(
      'GitHub returned HTTP $statusCode while checking updates.',
      statusCode: statusCode,
    );
  }

  GitHubReleaseItem? _parseRelease(Map<String, dynamic> data) {
    final tagName = (data['tag_name'] as String? ?? '').trim();
    if (tagName.isEmpty) return null;

    final rawName = (data['name'] as String? ?? '').trim();
    final releaseName = rawName.isEmpty ? tagName : rawName;
    final changelog = (data['body'] as String? ?? '').trim();
    final isPrerelease = data['prerelease'] as bool? ?? false;
    final isDraft = data['draft'] as bool? ?? false;
    final htmlUrl = (data['html_url'] as String? ?? '').trim();

    DateTime? publishedAt;
    if (data['published_at'] is String) {
      publishedAt = DateTime.tryParse(data['published_at'] as String);
    }

    final assets = (data['assets'] as List<dynamic>? ?? const []);
    String? apkDownloadUrl;
    String? apkFileName;
    int apkSize = 0;

    // Prefer universal/arm64 APK if multiple APKs are uploaded
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').trim();
      final lower = name.toLowerCase();
      if (!lower.endsWith('.apk')) continue;

      final candidateUrl = (asset['browser_download_url'] as String? ?? '')
          .trim();
      final candidateSize = (asset['size'] as num?)?.toInt() ?? 0;
      if (candidateUrl.isEmpty) continue;

      if (apkDownloadUrl == null ||
          lower.contains('universal') ||
          lower.contains('arm64')) {
        apkDownloadUrl = candidateUrl;
        apkFileName = name;
        apkSize = candidateSize;
        if (lower.contains('universal')) break;
      }
    }

    return GitHubReleaseItem(
      tagName: tagName,
      releaseName: releaseName,
      changelog: changelog,
      apkDownloadUrl: apkDownloadUrl,
      apkFileName: apkFileName,
      apkSizeBytes: apkSize,
      publishedAt: publishedAt,
      isPrerelease: isPrerelease,
      isDraft: isDraft,
      htmlUrl: htmlUrl,
    );
  }
}
