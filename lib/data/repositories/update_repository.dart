import '../models/app_update_info.dart';

/// Pure repository contract for checking GitHub releases and executing
/// inline Android OTA APK downloads and installs.
abstract class UpdateRepository {
  Future<({String version, String buildNumber})> getInstalledPackageInfo();

  Future<({String owner, String repo})> getTargetRepo();

  Future<void> setTargetRepo({required String owner, required String repo});

  Future<AppUpdateInfo?> checkForUpdate({
    required String owner,
    required String repo,
  });

  Future<List<GitHubReleaseItem>> fetchAllReleases({
    required String owner,
    required String repo,
    int perPage = 30,
  });

  Future<AppUpdateInfo?> getCachedPendingUpdate();

  Future<void> clearPendingUpdate();

  int compareVersion(
    String remoteTag,
    String currentVersion, [
    String currentBuild = '',
  ]);

  Stream<OtaDownloadState> startInlineApkInstall({
    required String downloadUrl,
    String? filename,
  });

  Future<bool> openExternalUrl(String url);
}
