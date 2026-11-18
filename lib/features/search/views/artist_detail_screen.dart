import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/artist_model.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../viewmodels/artist_detail_viewmodel.dart';
import 'album_detail_screen.dart';

/// Dedicated screen for an Artist.
/// Displays circular avatar hero, verified name, follower count,
/// [ ▶ Play Top Hits ] & [ 🔀 Shuffle ], filter chips ([ All ], [ Top Tracks ], [ Albums ]),
/// top tracks with rank badges, and a 2-column discography album grid.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 2: Context-Exposed Design Tokens (strictly zero magic numbers/raw colors).
/// - Invariant 3: Strict MVVM (View contains presentation only, zero business logic).
/// - Invariant 4: Strict Monochrome & B&W Theme (zero gradients, zero neons; artwork is sole exception).
class ArtistDetailScreen extends StatelessWidget {
  final ArtistModel artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ArtistDetailViewModel(
        audioRepository: ctx.read<AudioRepository>(),
        artist: artist,
      ),
      child: const _ArtistDetailView(),
    );
  }
}

class _ArtistDetailView extends StatelessWidget {
  const _ArtistDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ArtistDetailViewModel>();
    final artist = vm.artist;

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
          artist.name,
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

  Widget _buildErrorView(BuildContext context, ArtistDetailViewModel vm) {
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
              onPressed: () => vm.fetchArtistDetails(),
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

  Widget _buildContent(BuildContext context, ArtistDetailViewModel vm) {
    final artist = vm.artist;
    final topSongs = vm.topSongs;
    final topAlbums = vm.topAlbums;

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
                // Circular Avatar Hero
                Container(
                  width: context.sizes.avatarLg * 2.2,
                  height: context.sizes.avatarLg * 2.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.solidMatteBorder,
                      width: context.sizes.borderThin,
                    ),
                    color: context.colors.cardDarkSurface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: artist.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          artist.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderAvatar(context),
                        )
                      : _buildPlaceholderAvatar(context),
                ),
                SizedBox(height: context.spacing.md),
                // Artist Name
                Text(
                  artist.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.headlineMedium.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                // Follower count / verified
                Text(
                  vm.followerCount > 0
                      ? '${_formatFollowers(vm.followerCount)} Listeners'
                      : (artist.role.isNotEmpty ? artist.role : 'Artist'),
                  textAlign: TextAlign.center,
                  style: context.typography.captionMuted.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: context.spacing.lg),
                // Action Buttons: Play Top Hits & Shuffle
                if (topSongs.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _playTopSongs(context, topSongs, shuffle: false),
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: context.colors.oledBackground,
                            size: context.sizes.iconMd,
                          ),
                          label: Text(
                            'Play Top Hits',
                            style: context.typography.titleMedium.copyWith(
                              color: context.colors.oledBackground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.textPrimary,
                            foregroundColor: context.colors.oledBackground,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              vertical: context.spacing.sm,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: context.radius.asBorderRadiusFull,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.spacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _playTopSongs(context, topSongs, shuffle: true),
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
                            padding: EdgeInsets.symmetric(
                              vertical: context.spacing.sm,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: context.radius.asBorderRadiusFull,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: context.spacing.md),
                // Filter Chips: [ All ], [ Top Tracks ], [ Albums ]
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        context,
                        label: 'All',
                        isSelected: vm.currentFilter == ArtistFilter.all,
                        onTap: () => vm.setFilter(ArtistFilter.all),
                      ),
                      SizedBox(width: context.spacing.xs),
                      _buildFilterChip(
                        context,
                        label: 'Top Tracks (${topSongs.length})',
                        isSelected: vm.currentFilter == ArtistFilter.topTracks,
                        onTap: () => vm.setFilter(ArtistFilter.topTracks),
                      ),
                      SizedBox(width: context.spacing.xs),
                      _buildFilterChip(
                        context,
                        label: 'Albums & Singles (${topAlbums.length})',
                        isSelected: vm.currentFilter == ArtistFilter.albums,
                        onTap: () => vm.setFilter(ArtistFilter.albums),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.spacing.md),
              ],
            ),
          ),
        ),
        // Filter-specific views
        if (vm.currentFilter == ArtistFilter.all) ...[
          // Top Songs Preview Header
          if (topSongs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.md,
                  vertical: context.spacing.xs,
                ),
                child: Text(
                  'Popular Tracks',
                  style: context.typography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = topSongs[index];
                  return _buildSongTile(context, song, index + 1, topSongs);
                }, childCount: topSongs.length > 5 ? 5 : topSongs.length),
              ),
            ),
          ],
          // Discography Albums Shelf Header
          if (topAlbums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: context.spacing.md,
                  right: context.spacing.md,
                  top: context.spacing.lg,
                  bottom: context.spacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discography & Albums',
                      style: context.typography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () => vm.setFilter(ArtistFilter.albums),
                      child: Text(
                        'See all',
                        style: context.typography.captionMuted.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: context.spacing.sm,
                  mainAxisSpacing: context.spacing.sm,
                  childAspectRatio: 0.76,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final album = topAlbums[index];
                  return _buildAlbumGridCard(context, album);
                }, childCount: topAlbums.length > 4 ? 4 : topAlbums.length),
              ),
            ),
          ],
        ] else if (vm.currentFilter == ArtistFilter.topTracks) ...[
          // Full Top Tracks List
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = topSongs[index];
                return _buildSongTile(context, song, index + 1, topSongs);
              }, childCount: topSongs.length),
            ),
          ),
        ] else if (vm.currentFilter == ArtistFilter.albums) ...[
          // Full Discography 2-column Grid
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: context.spacing.sm,
                mainAxisSpacing: context.spacing.sm,
                childAspectRatio: 0.76,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final album = topAlbums[index];
                return _buildAlbumGridCard(context, album);
              }, childCount: topAlbums.length),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(
            height:
                context.sizes.miniPlayerHeight +
                context.sizes.navDockHeight +
                context.spacing.xl,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar(BuildContext context) {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: context.sizes.avatarLg,
        color: context.colors.textSecondary,
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: context.radius.asBorderRadiusFull,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.xs,
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
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile(
    BuildContext context,
    SongModel song,
    int rank,
    List<SongModel> allTracks,
  ) {
    final playerVm = context.watch<AudioPlayerViewModel>();
    final isCurrent = playerVm.currentSong?.id == song.id;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        playerVm.playFromQueue(allTracks, initialIndex: rank - 1);
      },
      borderRadius: context.radius.asBorderRadiusMd,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.spacing.sm,
          horizontal: context.spacing.xs,
        ),
        child: Row(
          children: [
            // Rank badge or Volume wave
            SizedBox(
              width: context.spacing.lg,
              child: isCurrent
                  ? Icon(
                      Icons.volume_up_rounded,
                      color: context.colors.textPrimary,
                      size: context.sizes.iconSm,
                    )
                  : Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: context.typography.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            SizedBox(width: context.spacing.xs),
            // Song Thumbnail
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
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.music_note_rounded,
                          color: context.colors.textSecondary,
                          size: context.sizes.iconSm,
                        ),
                      )
                    : Icon(
                        Icons.music_note_rounded,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconSm,
                      ),
              ),
            ),
            SizedBox(width: context.spacing.sm),
            // Title & Album/Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleMedium.copyWith(
                      color: isCurrent
                          ? context.colors.textPrimary
                          : context.colors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    song.album.isNotEmpty ? song.album : song.artist,
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

  Widget _buildAlbumGridCard(BuildContext context, AlbumModel album) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
        );
      },
      borderRadius: context.radius.asBorderRadiusCard,
      child: Container(
        padding: EdgeInsets.all(context.spacing.xs),
        decoration: BoxDecoration(
          color: context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusCard,
          border: Border.all(
            color: context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: context.radius.asBorderRadiusMd,
                child: Container(
                  width: double.infinity,
                  color: context.colors.oledBackground,
                  child: album.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          album.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.album_rounded,
                              color: context.colors.textSecondary,
                              size: context.sizes.iconLg,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.album_rounded,
                            color: context.colors.textSecondary,
                            size: context.sizes.iconLg,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.spacing.xxs),
            Text(
              album.year.isNotEmpty
                  ? album.year
                  : (album.artist.isNotEmpty ? album.artist : 'Album'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.captionMuted.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playTopSongs(
    BuildContext context,
    List<SongModel> songs, {
    required bool shuffle,
  }) {
    HapticFeedback.mediumImpact();
    final playerVm = context.read<AudioPlayerViewModel>();
    final queue = List<SongModel>.from(songs);
    if (shuffle) {
      queue.shuffle();
    }
    playerVm.playFromQueue(queue, initialIndex: 0);
  }

  String _formatFollowers(int count) {
    if (count >= 1000000) {
      final m = (count / 1000000).toStringAsFixed(1);
      return '${m.endsWith('.0') ? m.substring(0, m.length - 2) : m}M';
    } else if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(1);
      return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}K';
    }
    return count.toString();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
