import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../data/models/app_update_info.dart';
import '../../../data/repositories/update_repository.dart';

/// ViewModel managing GitHub Releases checks, temporary repo override,
/// and inline Android OTA APK download/installation state.
/// Adheres strictly to AGENTS.md Invariants 1 & 3 (Zero singletons, zero BuildContext).
class UpdateViewModel extends ChangeNotifier {
  final UpdateRepository updateRepository;

  String _repoOwner = ApiEndpoints.defaultUpdateRepoOwner;
  String _repoName = ApiEndpoints.defaultUpdateRepoName;
  String _currentVersion = '';
  String _currentBuildNumber = '';

  AppUpdateInfo? _latestUpdate;
  List<GitHubReleaseItem> _releases = const [];
  bool _isChecking = false;
  bool _isLoadingReleases = false;
  String? _errorMessage;
  String? _releasesErrorMessage;

  String? _activeDownloadTag;
  OtaDownloadState _downloadState = OtaDownloadState.idle;
  StreamSubscription<OtaDownloadState>? _downloadSub;

  bool _isDisposed = false;
  bool _initialized = false;

  UpdateViewModel({required this.updateRepository});

  // Getters
  String get repoOwner => _repoOwner;
  String get repoName => _repoName;
  String get repoSlug => '$_repoOwner/$_repoName';
  String get currentVersion => _currentVersion;
  String get currentBuildNumber => _currentBuildNumber;

  AppUpdateInfo? get latestUpdate => _latestUpdate;
  List<GitHubReleaseItem> get releases => List.unmodifiable(_releases);
  bool get isChecking => _isChecking;
  bool get isLoadingReleases => _isLoadingReleases;
  String? get errorMessage => _errorMessage;
  String? get releasesErrorMessage => _releasesErrorMessage;

  String? get activeDownloadTag => _activeDownloadTag;
  OtaDownloadState get downloadState => _downloadState;
  bool get isDownloading =>
      _downloadState.phase == OtaDownloadPhase.downloading;
  bool get hasAvailableUpdate => _latestUpdate?.hasUpdate ?? false;
  bool get canRunInlineOta =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get formattedCurrentVersion {
    if (_currentVersion.isEmpty) return 'Checking...';
    return _currentBuildNumber.isNotEmpty
        ? 'v$_currentVersion+$_currentBuildNumber'
        : 'v$_currentVersion';
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Hydrates installed package version, saved target repo, and runs initial update check.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final pkg = await updateRepository.getInstalledPackageInfo();
      _currentVersion = pkg.version;
      _currentBuildNumber = pkg.buildNumber;

      final savedRepo = await updateRepository.getTargetRepo();
      _repoOwner = savedRepo.owner;
      _repoName = savedRepo.repo;

      final cached = await updateRepository.getCachedPendingUpdate();
      if (cached != null) {
        _latestUpdate = cached;
      }
      _safeNotify();
    } catch (_) {
      // Ignore startup platform info read failures silently
    }

    await checkForUpdate(silent: true);
  }

  /// Queries GitHub Releases `/latest` for the active repository.
  Future<void> checkForUpdate({
    bool silent = false,
    bool includeReleases = false,
  }) async {
    if (_isChecking) return;
    _isChecking = true;
    if (!silent) {
      _errorMessage = null;
    }
    _safeNotify();

    try {
      final pkg = await updateRepository.getInstalledPackageInfo();
      _currentVersion = pkg.version;
      _currentBuildNumber = pkg.buildNumber;

      final info = await updateRepository.checkForUpdate(
        owner: _repoOwner,
        repo: _repoName,
      );
      if (_isDisposed) return;

      _latestUpdate = info;
      _errorMessage = null;
    } catch (e) {
      if (_isDisposed) return;
      if (!silent) {
        _errorMessage = e.toString();
      }
    } finally {
      if (!_isDisposed) {
        _isChecking = false;
        _safeNotify();
      }
    }

    if (includeReleases && !_isDisposed) {
      await loadReleases();
    }
  }

  /// Fetches all GitHub releases (both latest and historical) for the active repo.
  Future<void> loadReleases() async {
    if (_isLoadingReleases) return;
    _isLoadingReleases = true;
    _releasesErrorMessage = null;
    _safeNotify();

    try {
      final items = await updateRepository.fetchAllReleases(
        owner: _repoOwner,
        repo: _repoName,
        perPage: 30,
      );
      if (_isDisposed) return;

      _releases = items;
      _releasesErrorMessage = null;
    } catch (e) {
      if (_isDisposed) return;
      _releases = const [];
      _releasesErrorMessage = e.toString();
    } finally {
      if (!_isDisposed) {
        _isLoadingReleases = false;
        _safeNotify();
      }
    }
  }

  /// Points the updater to another GitHub repo (`owner/repo` or full GitHub URL)
  /// so test builds can be pulled from any temporary public repository.
  Future<bool> updateTargetRepo(String rawInput) async {
    final normalized = _parseRepoInput(rawInput);
    if (normalized == null) {
      _errorMessage = 'Enter a valid GitHub repository as "owner/repo".';
      _safeNotify();
      return false;
    }

    _repoOwner = normalized.owner;
    _repoName = normalized.repo;
    _latestUpdate = null;
    _releases = const [];
    _errorMessage = null;
    _releasesErrorMessage = null;
    _safeNotify();

    await updateRepository.setTargetRepo(owner: _repoOwner, repo: _repoName);
    await checkForUpdate(silent: false, includeReleases: true);
    return true;
  }

  Future<void> resetTargetRepo() async {
    await updateTargetRepo(
      '${ApiEndpoints.defaultUpdateRepoOwner}/${ApiEndpoints.defaultUpdateRepoName}',
    );
  }

  ({String owner, String repo})? _parseRepoInput(String rawInput) {
    var trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // Allow pasting full https://github.com/owner/repo URLs gracefully
    trimmed = trimmed
        .replaceFirst(RegExp(r'^https?://(www\.)?github\.com/'), '')
        .replaceAll(RegExp(r'\.git$'), '');

    final segments = trimmed
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) return null;

    final owner = segments[0].trim();
    final repo = segments[1].trim();
    if (owner.isEmpty || repo.isEmpty) return null;
    return (owner: owner, repo: repo);
  }

  int compareWithCurrent(String remoteTag) {
    if (_currentVersion.isEmpty) return 0;
    return updateRepository.compareVersion(
      remoteTag,
      _currentVersion,
      _currentBuildNumber,
    );
  }

  /// Downloads APK directly inside the app and triggers Android's package installer.
  void startInlineDownload({
    required String downloadUrl,
    required String tagName,
    String? filename,
  }) {
    if (isDownloading) return;

    _downloadSub?.cancel();
    _activeDownloadTag = tagName;
    _downloadState = const OtaDownloadState(
      phase: OtaDownloadPhase.downloading,
      progressPercent: 0,
      statusMessage: 'Preparing download...',
    );
    _safeNotify();

    _downloadSub = updateRepository
        .startInlineApkInstall(
          downloadUrl: downloadUrl,
          filename: filename ?? 'dilse_$tagName.apk',
        )
        .listen(
          (state) {
            if (_isDisposed) return;
            _downloadState = state;
            if (state.phase == OtaDownloadPhase.installing ||
                state.phase == OtaDownloadPhase.completed ||
                state.phase == OtaDownloadPhase.error ||
                state.phase == OtaDownloadPhase.permissionDenied ||
                state.phase == OtaDownloadPhase.idle) {
              // Release active download lock once installer Intent has handed off or failed
              if (state.phase != OtaDownloadPhase.downloading) {
                _activeDownloadTag = null;
              }
            }
            _safeNotify();
          },
          onError: (Object err) {
            if (_isDisposed) return;
            _activeDownloadTag = null;
            _downloadState = OtaDownloadState(
              phase: OtaDownloadPhase.error,
              errorMessage: 'Download failed: $err',
            );
            _safeNotify();
          },
          onDone: () {
            if (_isDisposed) return;
            if (_downloadState.phase == OtaDownloadPhase.downloading) {
              _activeDownloadTag = null;
            }
            _safeNotify();
          },
        );
  }

  void clearDownloadFeedback() {
    _downloadState = OtaDownloadState.idle;
    _activeDownloadTag = null;
    _safeNotify();
  }

  Future<bool> openExternalUrl(String url) {
    return updateRepository.openExternalUrl(url);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _downloadSub?.cancel();
    super.dispose();
  }
}
