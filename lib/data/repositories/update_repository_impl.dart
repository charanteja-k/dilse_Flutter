import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_endpoints.dart';
import '../datasources/remote/github_update_datasource.dart';
import '../models/app_update_info.dart';
import 'update_repository.dart';

/// Concrete repository coordinating GitHub Releases checks, semver comparison,
/// local repo preference persistence, and inline Android OTA installation.
class UpdateRepositoryImpl implements UpdateRepository {
  final GithubUpdateDatasource remoteDatasource;

  static const String _prefRepoOwnerKey = 'dilse_update_repo_owner';
  static const String _prefRepoNameKey = 'dilse_update_repo_name';
  static const String _prefPendingUpdateKey = 'dilse_pending_update_json';

  const UpdateRepositoryImpl({required this.remoteDatasource});

  @override
  Future<({String version, String buildNumber})> getInstalledPackageInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    return (version: pkg.version, buildNumber: pkg.buildNumber);
  }

  @override
  Future<({String owner, String repo})> getTargetRepo() async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_prefRepoOwnerKey)?.trim();
    final repo = prefs.getString(_prefRepoNameKey)?.trim();
    return (
      owner: (owner != null && owner.isNotEmpty)
          ? owner
          : ApiEndpoints.defaultUpdateRepoOwner,
      repo: (repo != null && repo.isNotEmpty)
          ? repo
          : ApiEndpoints.defaultUpdateRepoName,
    );
  }

  @override
  Future<void> setTargetRepo({required String owner, required String repo}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRepoOwnerKey, owner.trim());
    await prefs.setString(_prefRepoNameKey, repo.trim());
    await prefs.remove(_prefPendingUpdateKey);
  }

  @override
  Future<AppUpdateInfo?> getCachedPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefPendingUpdateKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final info = AppUpdateInfo.fromJson(decoded);

      final pkg = await getInstalledPackageInfo();
      if (compareVersion(info.tagName, pkg.version, pkg.buildNumber) <= 0) {
        await clearPendingUpdate();
        return null;
      }
      return info;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPendingUpdateKey);
  }

  Future<void> _savePendingUpdate(AppUpdateInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPendingUpdateKey, json.encode(info.toJson()));
  }

  @override
  Future<AppUpdateInfo?> checkForUpdate({
    required String owner,
    required String repo,
  }) async {
    final pkg = await getInstalledPackageInfo();
    final latest = await remoteDatasource.fetchLatestRelease(
      owner: owner,
      repo: repo,
    );

    if (latest == null) {
      await clearPendingUpdate();
      return null;
    }

    final hasUpdate = compareVersion(
          latest.tagName,
          pkg.version,
          pkg.buildNumber,
        ) >
        0;

    final fallbackPage = latest.htmlUrl.isNotEmpty
        ? latest.htmlUrl
        : 'https://github.com/$owner/$repo/releases/tag/${latest.tagName}';

    final info = AppUpdateInfo(
      tagName: latest.tagName,
      releaseName: latest.releaseName,
      changelog: latest.changelog.isNotEmpty
          ? latest.changelog
          : 'Bug fixes and performance improvements.',
      downloadUrl: latest.apkDownloadUrl ?? fallbackPage,
      apkSizeBytes: latest.apkSizeBytes,
      currentVersion: pkg.version,
      currentBuildNumber: pkg.buildNumber,
      hasUpdate: hasUpdate,
      hasApk: latest.hasApk,
      releasePageUrl: fallbackPage,
    );

    if (hasUpdate) {
      await _savePendingUpdate(info);
    } else {
      await clearPendingUpdate();
    }

    return info;
  }

  @override
  Future<List<GitHubReleaseItem>> fetchAllReleases({
    required String owner,
    required String repo,
    int perPage = 30,
  }) {
    return remoteDatasource.fetchAllReleases(
      owner: owner,
      repo: repo,
      perPage: perPage,
    );
  }

  @override
  int compareVersion(
    String remoteTag,
    String currentVersion, [
    String currentBuild = '',
  ]) {
    final parsedRemote = _parseSemver(remoteTag);
    final parsedCurrent = _parseSemver(
      currentVersion,
      fallbackBuild: int.tryParse(currentBuild) ?? 0,
    );

    for (int i = 0; i < 3; i++) {
      if (parsedRemote.parts[i] > parsedCurrent.parts[i]) return 1;
      if (parsedRemote.parts[i] < parsedCurrent.parts[i]) return -1;
    }

    if (parsedRemote.build > 0 && parsedCurrent.build > 0) {
      if (parsedRemote.build > parsedCurrent.build) return 1;
      if (parsedRemote.build < parsedCurrent.build) return -1;
    }

    return 0;
  }

  ({List<int> parts, int build}) _parseSemver(
    String raw, {
    int fallbackBuild = 0,
  }) {
    final strippedPrefix = raw.replaceAll(RegExp(r'^[vV]'), '').trim();
    final plusSplit = strippedPrefix.split('+');
    final buildNumber = plusSplit.length > 1
        ? (int.tryParse(plusSplit[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? fallbackBuild)
        : fallbackBuild;

    // Strip pre-release suffix (e.g. "1.0.2-beta" -> "1.0.2") before parsing ints
    final versionCore = plusSplit[0].split('-').first;
    final parts = versionCore
        .split('.')
        .map((segment) => int.tryParse(segment.trim()) ?? 0)
        .toList();

    while (parts.length < 3) {
      parts.add(0);
    }

    return (parts: parts.take(3).toList(), build: buildNumber);
  }

  @override
  Stream<OtaDownloadState> startInlineApkInstall({
    required String downloadUrl,
    String? filename,
  }) async* {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      yield const OtaDownloadState(
        phase: OtaDownloadPhase.error,
        errorMessage: 'Inline APK install is supported on Android devices only.',
      );
      return;
    }

    // Request "Install unknown apps" permission on Android 8+
    try {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          yield const OtaDownloadState(
            phase: OtaDownloadPhase.permissionDenied,
            errorMessage:
                'Permission needed: enable "Install unknown apps" for DilSe or open in browser.',
          );
          return;
        }
      }
    } catch (_) {
      // Proceed to let native plugin attempt install intent
    }

    yield const OtaDownloadState(
      phase: OtaDownloadPhase.downloading,
      progressPercent: 0,
      statusMessage: 'Connecting to GitHub...',
    );

    final controller = StreamController<OtaDownloadState>();
    StreamSubscription<OtaEvent>? sub;

    try {
      final safeFilename = (filename != null &&
              filename.isNotEmpty &&
              !filename.contains('/') &&
              filename.toLowerCase().endsWith('.apk'))
          ? filename
          : 'dilse_latest.apk';

      sub = OtaUpdate()
          .execute(
            downloadUrl,
            destinationFilename: safeFilename,
          )
          .listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final pct = int.tryParse(event.value ?? '0') ?? 0;
              controller.add(
                OtaDownloadState(
                  phase: OtaDownloadPhase.downloading,
                  progressPercent: pct.clamp(0, 100),
                  statusMessage: 'Downloading APK... ($pct%)',
                ),
              );
              break;
            case OtaStatus.INSTALLING:
              controller.add(
                const OtaDownloadState(
                  phase: OtaDownloadPhase.installing,
                  progressPercent: 100,
                  statusMessage: 'Launching Android installer...',
                ),
              );
              break;
            case OtaStatus.INSTALLATION_DONE:
              controller.add(
                const OtaDownloadState(
                  phase: OtaDownloadPhase.completed,
                  progressPercent: 100,
                  statusMessage: 'Installation complete!',
                ),
              );
              controller.close();
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              controller.add(
                const OtaDownloadState(
                  phase: OtaDownloadPhase.permissionDenied,
                  errorMessage: 'Install permission was not granted.',
                ),
              );
              controller.close();
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              controller.add(
                const OtaDownloadState(
                  phase: OtaDownloadPhase.error,
                  errorMessage: 'An update download is already in progress.',
                ),
              );
              controller.close();
              break;
            case OtaStatus.CANCELED:
              controller.add(
                const OtaDownloadState(
                  phase: OtaDownloadPhase.idle,
                  statusMessage: 'Download canceled.',
                ),
              );
              controller.close();
              break;
            case OtaStatus.INSTALLATION_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              controller.add(
                OtaDownloadState(
                  phase: OtaDownloadPhase.error,
                  errorMessage:
                      'Update failed (${event.status.name}): ${event.value ?? 'Unknown error'}',
                ),
              );
              controller.close();
              break;
          }
        },
        onError: (Object err) {
          if (!controller.isClosed) {
            controller.add(
              OtaDownloadState(
                phase: OtaDownloadPhase.error,
                errorMessage: 'Download error: $err',
              ),
            );
            controller.close();
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );
    } catch (e) {
      if (!controller.isClosed) {
        controller.add(
          OtaDownloadState(
            phase: OtaDownloadPhase.error,
            errorMessage: 'Failed to start OTA update: $e',
          ),
        );
        controller.close();
      }
    }

    try {
      yield* controller.stream;
    } finally {
      await sub?.cancel();
    }
  }

  @override
  Future<bool> openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

