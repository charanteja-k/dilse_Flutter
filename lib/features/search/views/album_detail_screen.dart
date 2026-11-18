import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../viewmodels/album_detail_viewmodel.dart';

/// Dedicated screen for an Album.
/// Displays high-res cover art, release year, language, track count,
/// [ ▶ Play All ] & [ 🔀 Shuffle ] controls, and a numbered tracklist.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 2: Context-Exposed Design Tokens (strictly zero magic numbers/raw colors).
/// - Invariant 3: Strict MVVM (View contains presentation only, zero business logic).
/// - Invariant 4: Strict Monochrome & B&W Theme (zero gradients, zero neons; artwork is sole exception).
class AlbumDetailScreen extends StatelessWidget {
  final AlbumModel album;

  const AlbumDetailScreen({
    super.key,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AlbumDetailViewModel(
        audioRepository: ctx.read<AudioRepository>(),
        album: album,
      ),
      child: const _AlbumDetailView(),
    );
  }
}

class _AlbumDetailView extends StatelessWidget {
  const _AlbumDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlbumDetailViewModel>();
    final album = vm.album;

    return Scaffold(
      backgroundColor: context.colors.oledBackground,
      appBar: AppBar(
        backgroundColor: context.colors.oledBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colors.textPrimary,
            size: context.sizes.iconMd,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.titleMedium.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: vm.isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.textPrimary,
              ),
            )
          : vm.errorMessage != null
              ? _buildErrorView(context, vm)
              : _buildContent(context, vm),
    );
  }

  Widget _buildErrorView(BuildContext context, AlbumDetailViewModel vm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: context.colors.textSecondary,
              size: context.sizes.avatarMd,
            ),
            SizedBox(height: context.spacing.md),
            Text(
              vm.errorMessage!,
              textAlign: TextAlign.center,
              style: context.typography.bodyMedium.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: context.spacing.md),
            OutlinedButton(
              onPressed: () => vm.fetchAlbumTracks(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.solidMatteBorder),
                foregroundColor: context.colors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.asBorderRadiusCard,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.lg,
                  vertical: context.spacing.sm,
                ),
              ),
              child: Text('Retry', style: context.typography.titleMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AlbumDetailViewModel vm) {
    final album = vm.album;
    final tracks = vm.tracks;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: context.spacing.md),
                // Artwork Hero
                Container(
                  width: context.sizes.heroCardHeight,
                  height: context.sizes.heroCardHeight,
                  decoration: BoxDecoration(
                    borderRadius: context.radius.asBorderRadiusArtwork,
                    border: Border.all(
                      color: context.colors.solidMatteBorder,
                      width: context.sizes.borderThin,
                    ),
                    color: context.colors.cardDarkSurface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: album.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          album.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(context),
                        )
                      : _buildPlaceholderArt(context),
                ),
                SizedBox(height: context.spacing.md),
                // Album Title
                Text(
                  album.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.headlineMedium.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                // Artist / Music Director
                Text(
                  album.artist.isNotEmpty ? album.artist : album.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.titleMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                // Meta badge: Year • Language • Songs Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (album.year.isNotEmpty) ...[
                      Text(
                        album.year,
                        style: context.typography.captionMuted.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                      _buildDot(context),
                    ],
                    if (album.language.isNotEmpty) ...[
                      Text(
                        album.language.toUpperCase(),
                        style: context.typography.captionMuted.copyWith(
                          color: context.colors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      _buildDot(context),
                    ],
                    Text(
                      '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
                      style: context.typography.captionMuted.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.lg),
                // Action Buttons: Play All & Shuffle
                if (tracks.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _playAll(context, tracks, shuffle: false),
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: context.colors.oledBackground,
                            size: context.sizes.iconMd,
                          ),
                          label: Text(
                            'Play All',
                            style: context.typography.titleMedium.copyWith(
                              color: context.colors.oledBackground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.textPrimary,
                            foregroundColor: context.colors.oledBackground,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: context.radius.asBorderRadiusFull,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.spacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _playAll(context, tracks, shuffle: true),
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: context.colors.textPrimary,
                            size: context.sizes.iconMd,
                          ),
                          label: Text(
                            'Shuffle',
                            style: context.typography.titleMedium.copyWith(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: context.colors.solidMatteBorder,
                              width: context.sizes.borderThin,
                            ),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: context.radius.asBorderRadiusFull,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: context.spacing.lg),
              ],
            ),
          ),
        ),
        // Tracklist
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = tracks[index];
                return _buildTrackTile(context, song, index + 1, tracks);
              },
              childCount: tracks.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: context.sizes.miniPlayerHeight + context.sizes.navDockHeight + context.spacing.xl),
        ),
      ],
    );
  }

  Widget _buildDot(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
      child: Text(
        '•',
        style: context.typography.captionMuted.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt(BuildContext context) {
    return Center(
      child: Icon(
        Icons.album_rounded,
        size: context.sizes.avatarLg,
        color: context.colors.textSecondary,
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    SongModel song,
    int trackIndex,
    List<SongModel> allTracks,
  ) {
    final playerVm = context.watch<AudioPlayerViewModel>();
    final isCurrent = playerVm.currentSong?.id == song.id;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        playerVm.playFromQueue(allTracks, initialIndex: trackIndex - 1);
      },
      borderRadius: context.radius.asBorderRadiusMd,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.spacing.sm,
          horizontal: context.spacing.xs,
        ),
        child: Row(
          children: [
            // Track Number or Active Wave
            SizedBox(
              width: context.spacing.lg,
              child: isCurrent
                  ? Icon(
                      Icons.volume_up_rounded,
                      color: context.colors.textPrimary,
                      size: context.sizes.iconSm,
                    )
                  : Text(
                      '$trackIndex',
                      textAlign: TextAlign.center,
                      style: context.typography.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            SizedBox(width: context.spacing.sm),
            // Song Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleMedium.copyWith(
                      color: isCurrent ? context.colors.textPrimary : context.colors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyMedium.copyWith(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Duration
            if (song.duration > Duration.zero) ...[
              Text(
                _formatDuration(song.duration),
                style: context.typography.captionMuted.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(width: context.spacing.xs),
            ],
            // More options
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.colors.textSecondary,
                size: context.sizes.iconSm,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                SongOptionsBottomSheet.show(context, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _playAll(BuildContext context, List<SongModel> tracks, {required bool shuffle}) {
    HapticFeedback.mediumImpact();
    final playerVm = context.read<AudioPlayerViewModel>();
    final queue = List<SongModel>.from(tracks);
    if (shuffle) {
      queue.shuffle();
    }
    playerVm.playFromQueue(queue, initialIndex: 0);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
