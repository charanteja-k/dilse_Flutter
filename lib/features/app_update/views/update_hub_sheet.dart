import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/app_update_info.dart';
import '../viewmodels/update_viewmodel.dart';

/// Modal bottom sheet for checking GitHub Releases, pointing to a custom or
/// temporary GitHub repository, viewing all release builds, and installing
/// APK updates inline inside the app.
/// Adheres strictly to AGENTS.md Invariants 1, 2 & 3.
class UpdateHubSheet extends StatefulWidget {
  const UpdateHubSheet({super.key});

  static Future<void> show(BuildContext context) {
    final updateVm = context.read<UpdateViewModel>();
    updateVm.checkForUpdate(silent: false, includeReleases: true);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.oledBackground.withAlpha(0),
      builder: (_) => const UpdateHubSheet(),
    );
  }

  @override
  State<UpdateHubSheet> createState() => _UpdateHubSheetState();
}

class _UpdateHubSheetState extends State<UpdateHubSheet> {
  final TextEditingController _repoController = TextEditingController();
  final Set<String> _expandedChangelogs = {};
  bool _isEditingRepo = false;

  @override
  void initState() {
    super.initState();
    _repoController.text = context.read<UpdateViewModel>().repoSlug;
  }

  @override
  void dispose() {
    _repoController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _saveRepoTarget(UpdateViewModel vm) async {
    HapticFeedback.lightImpact();
    final ok = await vm.updateTargetRepo(_repoController.text);
    if (ok && mounted) {
      setState(() {
        _isEditingRepo = false;
        _repoController.text = vm.repoSlug;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UpdateViewModel>();

    return Container(
      decoration: BoxDecoration(
        color: context.colors.oledBackground,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radius.lg),
        ),
        border: Border.all(
          color: context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Padding(
            padding: EdgeInsets.only(top: context.spacing.sm),
            child: Container(
              width: context.spacing.xl,
              height: context.spacing.xs,
              decoration: BoxDecoration(
                color: context.colors.solidMatteBorder,
                borderRadius: context.radius.asBorderRadiusFull,
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacing.md,
              context.spacing.sm,
              context.spacing.sm,
              context.spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: context.colors.brandRuby,
                  size: context.sizes.iconMd,
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GitHub App Updates',
                        style: context.typography.titleLarge,
                      ),
                      Text(
                        'Installed: ${vm.formattedCurrentVersion}',
                        style: context.typography.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh releases',
                  onPressed: vm.isChecking
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          vm.checkForUpdate(
                            silent: false,
                            includeReleases: true,
                          );
                        },
                  icon: vm.isChecking
                      ? SizedBox(
                          width: context.sizes.iconSm,
                          height: context.sizes.iconSm,
                          child: CircularProgressIndicator(
                            strokeWidth: context.spacing.xxs,
                            color: context.colors.brandRuby,
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          color: context.colors.textPrimary,
                          size: context.sizes.iconMd,
                        ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconMd,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: context.sizes.borderThin,
            color: context.colors.solidMatteBorder,
          ),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.spacing.md,
                context.spacing.md,
                context.spacing.md,
                MediaQuery.viewInsetsOf(context).bottom + context.spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRepoSelectorCard(context, vm),
                  SizedBox(height: context.spacing.md),

                  if (vm.downloadState.phase != OtaDownloadPhase.idle) ...[
                    _buildDownloadProgressCard(context, vm),
                    SizedBox(height: context.spacing.md),
                  ],

                  _buildLatestUpdateCard(context, vm),
                  SizedBox(height: context.spacing.lg),

                  _buildAllReleasesSection(context, vm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoSelectorCard(BuildContext context, UpdateViewModel vm) {
    return Container(
      padding: EdgeInsets.all(context.spacing.sm),
      decoration: BoxDecoration(
        color: context.colors.cardDarkSurface,
        borderRadius: context.radius.asBorderRadiusMd,
        border: Border.all(
          color: context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_open_rounded,
                color: context.colors.textSecondary,
                size: context.sizes.iconSm,
              ),
              SizedBox(width: context.spacing.xs),
              Text(
                'GITHUB REPOSITORY TARGET',
                style: context.typography.eyebrow,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isEditingRepo = !_isEditingRepo;
                    _repoController.text = vm.repoSlug;
                  });
                },
                child: Text(
                  _isEditingRepo ? 'Cancel' : 'Change Repo',
                  style: context.typography.bodyMedium.copyWith(
                    color: context.colors.brandRuby,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!_isEditingRepo)
            Text(
              vm.repoSlug,
              style: context.typography.titleMedium,
            )
          else ...[
            SizedBox(height: context.spacing.xs),
            TextField(
              controller: _repoController,
              style: context.typography.titleMedium,
              cursorColor: context.colors.brandRuby,
              decoration: InputDecoration(
                hintText: 'owner/repo (public GitHub repo)',
                hintStyle: context.typography.bodyMedium,
                isDense: true,
                filled: true,
                fillColor: context.colors.oledBackground,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.spacing.sm,
                  vertical: context.spacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: context.radius.asBorderRadiusSm,
                  borderSide: BorderSide(
                    color: context.colors.solidMatteBorder,
                    width: context.sizes.borderThin,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: context.radius.asBorderRadiusSm,
                  borderSide: BorderSide(
                    color: context.colors.solidMatteBorder,
                    width: context.sizes.borderThin,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: context.radius.asBorderRadiusSm,
                  borderSide: BorderSide(
                    color: context.colors.brandRuby,
                    width: context.sizes.borderThin,
                  ),
                ),
              ),
              onSubmitted: (_) => _saveRepoTarget(vm),
            ),
            SizedBox(height: context.spacing.sm),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await vm.resetTargetRepo();
                    if (mounted) {
                      setState(() {
                        _isEditingRepo = false;
                        _repoController.text = vm.repoSlug;
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textSecondary,
                    side: BorderSide(
                      color: context.colors.solidMatteBorder,
                      width: context.sizes.borderThin,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: context.radius.asBorderRadiusSm,
                    ),
                  ),
                  child: const Text('Reset Default'),
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveRepoTarget(vm),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brandRuby,
                      foregroundColor: context.colors.oledBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: context.radius.asBorderRadiusSm,
                      ),
                    ),
                    child: Text(
                      'Save & Check Releases',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.oledBackground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadProgressCard(BuildContext context, UpdateViewModel vm) {
    final dl = vm.downloadState;
    final isError = dl.phase == OtaDownloadPhase.error ||
        dl.phase == OtaDownloadPhase.permissionDenied;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: context.colors.cardDarkSurface,
        borderRadius: context.radius.asBorderRadiusMd,
        border: Border.all(
          color: isError
              ? context.colors.errorCrimson
              : context.colors.brandRuby,
          width: context.sizes.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : (dl.phase == OtaDownloadPhase.installing
                        ? Icons.android_rounded
                        : Icons.downloading_rounded),
                color: isError
                    ? context.colors.errorCrimson
                    : context.colors.brandRuby,
                size: context.sizes.iconMd,
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  isError
                      ? (dl.errorMessage ?? 'Update failed')
                      : dl.statusMessage,
                  style: context.typography.titleMedium,
                ),
              ),
              if (isError || dl.phase == OtaDownloadPhase.installing)
                IconButton(
                  onPressed: vm.clearDownloadFeedback,
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconSm,
                  ),
                ),
            ],
          ),
          if (dl.phase == OtaDownloadPhase.downloading) ...[
            SizedBox(height: context.spacing.sm),
            ClipRRect(
              borderRadius: context.radius.asBorderRadiusFull,
              child: LinearProgressIndicator(
                value: dl.progressPercent > 0 ? dl.progressPercent / 100.0 : null,
                minHeight: context.sizes.progressBarHeight,
                backgroundColor: context.colors.oledBackground,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.colors.brandRuby,
                ),
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              'Keep DilSe open until the Android installer appears.',
              style: context.typography.captionMuted,
            ),
          ],
          if (isError && vm.latestUpdate != null) ...[
            SizedBox(height: context.spacing.sm),
            TextButton.icon(
              onPressed: () => vm.openExternalUrl(vm.latestUpdate!.downloadUrl),
              icon: Icon(
                Icons.open_in_new_rounded,
                size: context.sizes.iconSm,
                color: context.colors.textPrimary,
              ),
              label: Text(
                'Download via Browser instead',
                style: context.typography.titleMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatestUpdateCard(BuildContext context, UpdateViewModel vm) {
    if (vm.isChecking && vm.latestUpdate == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.spacing.md),
        decoration: BoxDecoration(
          color: context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusLg,
          border: Border.all(
            color: context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        child: Row(
          children: [
            CircularProgressIndicator(
              strokeWidth: context.spacing.xxs,
              color: context.colors.brandRuby,
            ),
            SizedBox(width: context.spacing.md),
            Text(
              'Checking GitHub releases...',
              style: context.typography.titleMedium,
            ),
          ],
        ),
      );
    }

    if (vm.errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.spacing.md),
        decoration: BoxDecoration(
          color: context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusLg,
          border: Border.all(
            color: context.colors.warningAmber,
            width: context.sizes.borderThin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.colors.warningAmber,
                  size: context.sizes.iconMd,
                ),
                SizedBox(width: context.spacing.sm),
                Text(
                  'Unable to reach release feed',
                  style: context.typography.titleMedium,
                ),
              ],
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              vm.errorMessage!,
              style: context.typography.bodyMedium,
            ),
          ],
        ),
      );
    }

    final info = vm.latestUpdate;
    if (info == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.spacing.md),
        decoration: BoxDecoration(
          color: context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusLg,
          border: Border.all(
            color: context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No published releases found',
              style: context.typography.titleMedium,
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              'Publish a release with an .apk asset to ${vm.repoSlug} (public repo) or tap Change Repo above.',
              style: context.typography.bodyMedium,
            ),
          ],
        ),
      );
    }

    final hasUpdate = info.hasUpdate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: context.colors.cardDarkSurface,
        borderRadius: context.radius.asBorderRadiusLg,
        border: Border.all(
          color: hasUpdate
              ? context.colors.brandRuby
              : context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.sm,
                  vertical: context.spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: hasUpdate
                      ? context.colors.brandRuby
                      : context.colors.successEmerald,
                  borderRadius: context.radius.asBorderRadiusFull,
                ),
                child: Text(
                  hasUpdate ? 'NEW RELEASE' : 'UP TO DATE',
                  style: context.typography.eyebrow.copyWith(
                    color: context.colors.oledBackground,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                info.formattedSize,
                style: context.typography.bodyMedium,
              ),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            '${info.releaseName} (${info.tagName})',
            style: context.typography.headlineMedium,
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            info.changelog,
            style: context.typography.bodyMedium,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.spacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: vm.isDownloading
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          if (vm.canRunInlineOta && info.hasApk) {
                            vm.startInlineDownload(
                              downloadUrl: info.downloadUrl,
                              tagName: info.tagName,
                            );
                          } else {
                            vm.openExternalUrl(info.downloadUrl);
                          }
                        },
                  icon: Icon(
                    (vm.canRunInlineOta && info.hasApk)
                        ? Icons.download_rounded
                        : Icons.open_in_new_rounded,
                    size: context.sizes.iconSm,
                  ),
                  label: Text(
                    vm.canRunInlineOta && info.hasApk
                        ? (hasUpdate
                            ? 'Download & Install Update'
                            : 'Reinstall Latest APK')
                        : 'Open Release on GitHub',
                    style: context.typography.titleMedium.copyWith(
                      color: context.colors.oledBackground,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brandRuby,
                    foregroundColor: context.colors.oledBackground,
                    padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
                    shape: RoundedRectangleBorder(
                      borderRadius: context.radius.asBorderRadiusMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllReleasesSection(BuildContext context, UpdateViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALL RELEASES',
          style: context.typography.eyebrow,
        ),
        SizedBox(height: context.spacing.xs),
        if (vm.isLoadingReleases)
          Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Center(
              child: CircularProgressIndicator(
                color: context.colors.brandRuby,
              ),
            ),
          )
        else if (vm.releasesErrorMessage != null)
          Text(
            vm.releasesErrorMessage!,
            style: context.typography.bodyMedium,
          )
        else if (vm.releases.isEmpty)
          Text(
            'No releases returned for ${vm.repoSlug}.',
            style: context.typography.bodyMedium,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vm.releases.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: context.spacing.sm),
            itemBuilder: (context, index) {
              final release = vm.releases[index];
              return _buildReleaseRow(context, vm, release, isFirst: index == 0);
            },
          ),
      ],
    );
  }

  Widget _buildReleaseRow(
    BuildContext context,
    UpdateViewModel vm,
    GitHubReleaseItem release, {
    required bool isFirst,
  }) {
    final cmp = vm.compareWithCurrent(release.tagName);
    final isInstalled = cmp == 0;
    final isNewer = cmp > 0;
    final isExpanded = _expandedChangelogs.contains(release.tagName);
    final isThisDownloading = vm.activeDownloadTag == release.tagName;

    String statusLabel = 'ROLLBACK';
    Color badgeColor = context.colors.solidMatteBorder;
    Color badgeTextColor = context.colors.textPrimary;
    if (isInstalled) {
      statusLabel = 'INSTALLED';
      badgeColor = context.colors.successEmerald;
      badgeTextColor = context.colors.oledBackground;
    } else if (isNewer) {
      statusLabel = isFirst ? 'LATEST' : 'NEWER';
      badgeColor = context.colors.brandRuby;
      badgeTextColor = context.colors.oledBackground;
    } else if (release.isPrerelease) {
      statusLabel = 'PRE-RELEASE';
      badgeColor = context.colors.warningAmber;
      badgeTextColor = context.colors.oledBackground;
    }

    return Container(
      padding: EdgeInsets.all(context.spacing.sm),
      decoration: BoxDecoration(
        color: context.colors.cardDarkSurface,
        borderRadius: context.radius.asBorderRadiusMd,
        border: Border.all(
          color: isInstalled
              ? context.colors.successEmerald
              : context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.xs,
                            vertical: context.spacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: context.radius.asBorderRadiusSm,
                          ),
                          child: Text(
                            statusLabel,
                            style: context.typography.eyebrow.copyWith(
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                        SizedBox(width: context.spacing.xs),
                        Flexible(
                          child: Text(
                            release.tagName,
                            style: context.typography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.spacing.xxs),
                    Text(
                      '${_formatDate(release.publishedAt)} • ${release.formattedSize}',
                      style: context.typography.captionMuted,
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spacing.xs),
              OutlinedButton(
                onPressed: vm.isDownloading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        if (vm.canRunInlineOta && release.hasApk) {
                          vm.startInlineDownload(
                            downloadUrl: release.apkDownloadUrl!,
                            tagName: release.tagName,
                            filename: release.apkFileName,
                          );
                        } else {
                          vm.openExternalUrl(
                            release.apkDownloadUrl ?? release.htmlUrl,
                          );
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textPrimary,
                  side: BorderSide(
                    color: isNewer
                        ? context.colors.brandRuby
                        : context.colors.solidMatteBorder,
                    width: context.sizes.borderThin,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: context.radius.asBorderRadiusSm,
                  ),
                ),
                child: isThisDownloading
                    ? SizedBox(
                        width: context.sizes.iconSm,
                        height: context.sizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: context.spacing.xxs,
                          color: context.colors.brandRuby,
                        ),
                      )
                    : Text(
                        !release.hasApk
                            ? 'Open'
                            : (isInstalled
                                ? 'Reinstall'
                                : (isNewer ? 'Install' : 'Rollback')),
                      ),
              ),
            ],
          ),
          if (release.changelog.isNotEmpty) ...[
            SizedBox(height: context.spacing.xs),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedChangelogs.remove(release.tagName);
                  } else {
                    _expandedChangelogs.add(release.tagName);
                  }
                });
              },
              child: Text(
                isExpanded
                    ? release.changelog
                    : '${release.changelog.split('\n').first} (tap for notes)',
                style: context.typography.bodyMedium,
                maxLines: isExpanded ? null : 1,
                overflow:
                    isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
