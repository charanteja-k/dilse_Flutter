import 'package:meta/meta.dart';

/// Immutable model representing the latest GitHub release comparison against
/// the currently installed build. Zero Flutter UI dependencies (AGENTS.md Invariant 3).
@immutable
class AppUpdateInfo {
  final String tagName;
  final String releaseName;
  final String changelog;
  final String downloadUrl;
  final int apkSizeBytes;
  final String currentVersion;
  final String currentBuildNumber;
  final bool hasUpdate;
  final bool hasApk;
  final String? releasePageUrl;

  const AppUpdateInfo({
    required this.tagName,
    required this.releaseName,
    required this.changelog,
    required this.downloadUrl,
    required this.apkSizeBytes,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.hasUpdate,
    required this.hasApk,
    this.releasePageUrl,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return 'Unknown size';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'tagName': tagName,
      'releaseName': releaseName,
      'changelog': changelog,
      'downloadUrl': downloadUrl,
      'apkSizeBytes': apkSizeBytes,
      'currentVersion': currentVersion,
      'currentBuildNumber': currentBuildNumber,
      'hasUpdate': hasUpdate,
      'hasApk': hasApk,
      'releasePageUrl': releasePageUrl,
    };
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final download = (json['downloadUrl'] as String? ?? '').trim();
    return AppUpdateInfo(
      tagName: (json['tagName'] as String? ?? '').trim(),
      releaseName: (json['releaseName'] as String? ?? '').trim(),
      changelog: (json['changelog'] as String? ?? '').trim(),
      downloadUrl: download,
      apkSizeBytes: (json['apkSizeBytes'] as num?)?.toInt() ?? 0,
      currentVersion: (json['currentVersion'] as String? ?? '').trim(),
      currentBuildNumber: (json['currentBuildNumber'] as String? ?? '').trim(),
      hasUpdate: json['hasUpdate'] as bool? ?? false,
      hasApk: json['hasApk'] as bool? ?? download.toLowerCase().endsWith('.apk'),
      releasePageUrl: json['releasePageUrl'] as String?,
    );
  }
}

/// Immutable model representing any release entry returned from the GitHub Releases API.
@immutable
class GitHubReleaseItem {
  final String tagName;
  final String releaseName;
  final String changelog;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int apkSizeBytes;
  final DateTime? publishedAt;
  final bool isPrerelease;
  final bool isDraft;
  final String htmlUrl;

  const GitHubReleaseItem({
    required this.tagName,
    required this.releaseName,
    required this.changelog,
    this.apkDownloadUrl,
    this.apkFileName,
    required this.apkSizeBytes,
    this.publishedAt,
    required this.isPrerelease,
    required this.isDraft,
    required this.htmlUrl,
  });

  bool get hasApk => apkDownloadUrl != null && apkDownloadUrl!.isNotEmpty;

  String get formattedSize {
    if (apkSizeBytes <= 0) return hasApk ? 'APK attached' : 'Source only';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Pure domain state for an in-app OTA APK download & install stream.
enum OtaDownloadPhase {
  idle,
  downloading,
  installing,
  completed,
  permissionDenied,
  error,
}

@immutable
class OtaDownloadState {
  final OtaDownloadPhase phase;
  final int progressPercent;
  final String statusMessage;
  final String? errorMessage;

  const OtaDownloadState({
    required this.phase,
    this.progressPercent = 0,
    this.statusMessage = '',
    this.errorMessage,
  });

  static const idle = OtaDownloadState(phase: OtaDownloadPhase.idle);
}

