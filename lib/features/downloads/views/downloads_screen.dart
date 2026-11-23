import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/song_model.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../viewmodels/downloads_viewmodel.dart';

/// Pure Monochrome Downloads Screen adhering strictly to AGENTS.md Invariants 1-4.
/// Features dual instant playback actions, sort pills, and tactile song cards.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final minutes = d.inMinutes.remainder(60);
    final seconds = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final downloadsVm = context.watch<DownloadsViewModel>();
    final songs = downloadsVm.filteredSongs;

    return Scaffold(
      backgroundColor: context.colors.oledBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, downloadsVm),
            if (downloadsVm.downloadedSongs.isNotEmpty) ...[
              _buildSearchBar(context, downloadsVm),
              _buildActionRow(context, downloadsVm),
              _buildSortPills(context, downloadsVm),
            ],
            Expanded(
              child: downloadsVm.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.colors.textPrimary,
                      ),
                    )
                  : downloadsVm.downloadedSongs.isEmpty
                      ? _buildEmptyState(context)
                      : _buildDownloadedSongsList(context, songs, downloadsVm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DownloadsViewModel vm) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OFFLINE',
            style: context.typography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.spacing.xxs),
          Text(
            '${vm.downloadedSongs.length} Tracks • ${vm.formattedTotalStorage}',
            style: context.typography.captionMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, DownloadsViewModel vm) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Container(
        height: context.sizes.quickAccessTileHeight,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
        decoration: BoxDecoration(
          color: context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusMd,
          border: Border.all(
            color: context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: context.colors.textSecondary,
              size: context.sizes.iconSm,
            ),
            SizedBox(width: context.spacing.xs),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: context.typography.titleMedium,
                cursorColor: context.colors.textPrimary,
                onChanged: (val) => vm.updateSearchFilter(val),
                decoration: InputDecoration(
                  hintText: 'Filter offline downloads...',
                  hintStyle: context.typography.titleMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  vm.updateSearchFilter('');
                },
                child: Icon(
                  Icons.close_rounded,
                  color: context.colors.textSecondary,
                  size: context.sizes.iconSm,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, DownloadsViewModel vm) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: context.colors.textPrimary,
              borderRadius: context.radius.asBorderRadiusMd,
              child: InkWell(
                borderRadius: context.radius.asBorderRadiusMd,
                onTap: () {
                  HapticFeedback.lightImpact();
                  final songs = vm.downloadedSongs;
                  if (songs.isNotEmpty) {
                    context.read<AudioPlayerViewModel>().playFromQueue(songs);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: context.colors.oledBackground,
                        size: context.sizes.iconMd,
                      ),
                      SizedBox(width: context.spacing.xs),
                      Text(
                        'Play All',
                        style: context.typography.titleMedium.copyWith(
                          color: context.colors.oledBackground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Material(
              color: context.colors.cardDarkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: context.radius.asBorderRadiusMd,
                side: BorderSide(
                  color: context.colors.solidMatteBorder,
                  width: context.sizes.borderThin,
                ),
              ),
              child: InkWell(
                borderRadius: context.radius.asBorderRadiusMd,
                onTap: () {
                  HapticFeedback.lightImpact();
                  final songs = List<SongModel>.from(vm.downloadedSongs);
                  if (songs.isNotEmpty) {
                    songs.shuffle(Random());
                    context.read<AudioPlayerViewModel>().playFromQueue(songs);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shuffle_rounded,
                        color: context.colors.textPrimary,
                        size: context.sizes.iconSm,
                      ),
                      SizedBox(width: context.spacing.xs),
                      Text(
                        'Shuffle',
                        style: context.typography.titleMedium.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortPills(BuildContext context, DownloadsViewModel vm) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Row(
        children: [
          _buildPill(
            context,
            label: 'All (${vm.downloadedSongs.length})',
            isSelected: vm.selectedSort == DownloadSortOption.all,
            onTap: () => vm.setSortOption(DownloadSortOption.all),
          ),
          SizedBox(width: context.spacing.xs),
          _buildPill(
            context,
            label: 'Recently Added',
            isSelected: vm.selectedSort == DownloadSortOption.recent,
            onTap: () => vm.setSortOption(DownloadSortOption.recent),
          ),
          SizedBox(width: context.spacing.xs),
          _buildPill(
            context,
            label: 'Largest Size',
            isSelected: vm.selectedSort == DownloadSortOption.largest,
            onTap: () => vm.setSortOption(DownloadSortOption.largest),
          ),
          SizedBox(width: context.spacing.xs),
          _buildPill(
            context,
            label: 'A-Z',
            isSelected: vm.selectedSort == DownloadSortOption.alphabetical,
            onTap: () => vm.setSortOption(DownloadSortOption.alphabetical),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.textPrimary
              : context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusFull,
          border: Border.all(
            color: isSelected
                ? context.colors.textPrimary
                : context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        child: Text(
          label,
          style: context.typography.captionMuted.copyWith(
            color: isSelected
                ? context.colors.oledBackground
                : context.colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done_rounded,
              size: context.sizes.iconLg,
              color: context.colors.textSecondary,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'No downloads yet',
              style: context.typography.headlineMedium,
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              'Download songs to enjoy guaranteed 100% offline playback.',
              style: context.typography.bodyMedium.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedSongsList(
    BuildContext context,
    List<SongModel> songs,
    DownloadsViewModel vm,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.xs,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final durationStr = _formatDuration(song.duration);
        final fileSizeStr = vm.formatSongSize(song.id);

        return Padding(
          padding: EdgeInsets.only(bottom: context.spacing.xs),
          child: Material(
            color: context.colors.cardDarkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: context.radius.asBorderRadiusMd,
              side: BorderSide(
                color: context.colors.solidMatteBorder,
                width: context.sizes.borderThin,
              ),
            ),
            child: InkWell(
              borderRadius: context.radius.asBorderRadiusMd,
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AudioPlayerViewModel>().playSong(song);
              },
              child: Padding(
                padding: EdgeInsets.all(context.spacing.xs + 2),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: context.radius.asBorderRadiusSm,
                      child: Container(
                        width: context.sizes.thumbnailMd,
                        height: context.sizes.thumbnailMd,
                        color: context.colors.cardDarkSurface,
                        child: song.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                song.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Icon(
                                  Icons.music_note_rounded,
                                  color: context.colors.textSecondary,
                                ),
                              )
                            : Icon(
                                Icons.music_note_rounded,
                                color: context.colors.textSecondary,
                              ),
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: context.typography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.spacing.xxs),
                          Text(
                            song.artist.isNotEmpty
                                ? song.artist
                                : (song.album.isNotEmpty
                                    ? song.album
                                    : 'Offline Song'),
                            style: context.typography.captionMuted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.spacing.xxs + 2),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.spacing.xxs + 2,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.oledBackground,
                                  borderRadius: context.radius.asBorderRadiusXs,
                                  border: Border.all(
                                    color: context.colors.solidMatteBorder,
                                    width: context.sizes.borderThin,
                                  ),
                                ),
                                child: Text(
                                  '320 KBPS',
                                  style: context.typography.captionMuted.copyWith(
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (fileSizeStr != '0 MB') ...[
                                SizedBox(width: context.spacing.xxs + 2),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.xxs + 2,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.oledBackground,
                                    borderRadius:
                                        context.radius.asBorderRadiusXs,
                                    border: Border.all(
                                      color: context.colors.solidMatteBorder,
                                      width: context.sizes.borderThin,
                                    ),
                                  ),
                                  child: Text(
                                    fileSizeStr,
                                    style:
                                        context.typography.captionMuted.copyWith(
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              if (durationStr.isNotEmpty) ...[
                                SizedBox(width: context.spacing.xs),
                                Text(
                                  durationStr,
                                  style: context.typography.captionMuted
                                      .copyWith(fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconSm,
                      ),
                      onPressed: () {
                        vm.removeDownload(song.id);
                        DilSeNotification.show(
                          context,
                          message: 'Removed ${song.title} from downloads',
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconSm,
                      ),
                      onPressed: () =>
                          SongOptionsBottomSheet.show(context, song),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
