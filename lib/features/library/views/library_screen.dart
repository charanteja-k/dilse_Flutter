import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/artist_model.dart';
import '../../../data/models/playlist_model.dart';
import '../../../data/models/song_model.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../../search/views/album_detail_screen.dart';
import '../../search/views/artist_detail_screen.dart';
import '../viewmodels/library_viewmodel.dart';

/// Pure Monochrome Library Screen ("MY VAULT") adhering to AGENTS.md Invariants 1-4.
/// Features:
/// - Quick-launch Hero Tiles ([Liked Songs] & [On Repeat] with one-tap play)
/// - 2-Column tactile playlist grid with cover mosaics
/// - Saved Albums & Artists with direct links to AlbumDetailScreen & ArtistDetailScreen
/// - Inline Search filter & New Playlist creator
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryVm = context.watch<LibraryViewModel>();

    return Scaffold(
      backgroundColor: context.colors.oledBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, libraryVm),
            _buildSectionChips(context, libraryVm),
            Expanded(
              child: libraryVm.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.textPrimary,
                      ),
                    )
                  : _buildSectionContent(context, libraryVm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LibraryViewModel vm) {
    if (_isSearching) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.xs,
        ),
        child: Container(
          height: context.sizes.chipHeight * 1.1,
          decoration: BoxDecoration(
            color: context.colors.cardDarkSurface,
            borderRadius: context.radius.asBorderRadiusFull,
            border: Border.all(
              color: context.colors.solidMatteBorder,
              width: context.sizes.borderThin,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
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
                  autofocus: true,
                  style: context.typography.bodyMedium.copyWith(
                    color: context.colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Filter your vault...',
                    hintStyle: context.typography.bodyMedium.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => vm.setSearchFilter(val),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: context.colors.textSecondary,
                  size: context.sizes.iconSm,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    vm.setSearchFilter('');
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MY VAULT',
            style: context.typography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.search_rounded,
                  color: context.colors.textPrimary,
                  size: context.sizes.iconMd,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  color: context.colors.textPrimary,
                  size: context.sizes.iconMd,
                ),
                onPressed: () => _showCreatePlaylistDialog(context, vm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChips(BuildContext context, LibraryViewModel vm) {
    return SizedBox(
      height: context.sizes.chipHeight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: LibrarySection.values.length,
        separatorBuilder: (context, index) => SizedBox(width: context.spacing.xs),
        itemBuilder: (context, index) {
          final section = LibrarySection.values[index];
          final isSelected = section == vm.currentSection;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              vm.selectSection(section);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
              child: Center(
                child: Text(
                  section.label,
                  style: context.typography.titleMedium.copyWith(
                    color: isSelected
                        ? context.colors.oledBackground
                        : context.colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, LibraryViewModel vm) {
    switch (vm.currentSection) {
      case LibrarySection.all:
        return _buildAllVaultView(context, vm);
      case LibrarySection.playlists:
        return _buildPlaylistsView(context, vm);
      case LibrarySection.liked:
        return _buildLikedSongsView(context, vm);
      case LibrarySection.history:
        return _buildHistoryView(context, vm);
      case LibrarySection.albums:
        return _buildAlbumsView(context, vm);
      case LibrarySection.artists:
        return _buildArtistsView(context, vm);
    }
  }

  // --- "ALL" DASHBOARD VIEW ---
  Widget _buildAllVaultView(BuildContext context, LibraryViewModel vm) {
    final playlists = vm.playlists;
    final likedSongs = vm.likedSongs;
    final history = vm.history;
    final albums = vm.derivedAlbums;
    final artists = vm.derivedArtists;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.md,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      children: [
        // 1. Two Hero Quick Access Cards: [Liked Songs] & [On Repeat]
        Row(
          children: [
            Expanded(
              child: _buildHeroCard(
                context,
                title: 'Liked Songs',
                subtitle: '${likedSongs.length} Tracks',
                icon: Icons.favorite_rounded,
                onTap: () => vm.selectSection(LibrarySection.liked),
                onPlay: likedSongs.isEmpty
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        context.read<AudioPlayerViewModel>().playFromQueue(likedSongs);
                      },
              ),
            ),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: _buildHeroCard(
                context,
                title: 'On Repeat',
                subtitle: history.isEmpty ? 'No history' : '${history.length} Recent',
                icon: Icons.history_rounded,
                onTap: () => vm.selectSection(LibrarySection.history),
                onPlay: history.isEmpty
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        context.read<AudioPlayerViewModel>().playFromQueue(history);
                      },
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacing.lg),

        // 2. Playlists Section Bar & 2-Column Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PLAYLISTS (${playlists.length})',
              style: context.typography.eyebrow.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () => vm.selectSection(LibrarySection.playlists),
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
        SizedBox(height: context.spacing.sm),

        if (playlists.isEmpty)
          _buildEmptyCard(
            context,
            message: 'No playlists yet. Tap "+" above to create one.',
            onTap: () => _showCreatePlaylistDialog(context, vm),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: context.spacing.sm,
              mainAxisSpacing: context.spacing.sm,
              childAspectRatio: 0.76,
            ),
            itemCount: playlists.length > 4 ? 4 : playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return _buildPlaylistGridCard(context, pl, vm);
            },
          ),
        SizedBox(height: context.spacing.lg),

        // 3. Saved Albums Section Bar & Grid
        if (albums.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALBUMS IN VAULT (${albums.length})',
                style: context.typography.eyebrow.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => vm.selectSection(LibrarySection.albums),
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
          SizedBox(height: context.spacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: context.spacing.sm,
              mainAxisSpacing: context.spacing.sm,
              childAspectRatio: 0.76,
            ),
            itemCount: albums.length > 4 ? 4 : albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              return _buildDerivedAlbumCard(context, albumName, vm);
            },
          ),
          SizedBox(height: context.spacing.lg),
        ],

        // 4. Artists in Vault
        if (artists.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ARTISTS IN VAULT (${artists.length})',
                style: context.typography.eyebrow.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => vm.selectSection(LibrarySection.artists),
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
          SizedBox(height: context.spacing.sm),
          SizedBox(
            height: context.sizes.avatarLg * 2.1,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: artists.length > 8 ? 8 : artists.length,
              separatorBuilder: (context, index) => SizedBox(width: context.spacing.sm),
              itemBuilder: (context, index) {
                final artistName = artists[index];
                return _buildArtistBubble(context, artistName, vm);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onPlay,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: context.radius.asBorderRadiusCard,
      child: Container(
        height: 110,
        padding: EdgeInsets.all(context.spacing.md),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: context.sizes.iconLg,
                  height: context.sizes.iconLg,
                  decoration: BoxDecoration(
                    color: context.colors.oledBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.solidMatteBorder,
                      width: context.sizes.borderThin,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconSm,
                  ),
                ),
                if (onPlay != null)
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: context.sizes.iconLg * 0.95,
                      height: context.sizes.iconLg * 0.95,
                      decoration: BoxDecoration(
                        color: context.colors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: context.colors.oledBackground,
                        size: context.sizes.iconSm,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.spacing.xxs),
                Text(
                  subtitle,
                  style: context.typography.captionMuted.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- PLAYLISTS VIEW ---
  Widget _buildPlaylistsView(BuildContext context, LibraryViewModel vm) {
    final playlists = vm.playlists;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.md,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      children: [
        if (playlists.isEmpty)
          _buildEmptyCard(
            context,
            message: 'No playlists yet. Tap "+" above to create one.',
            onTap: () => _showCreatePlaylistDialog(context, vm),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: context.spacing.sm,
              mainAxisSpacing: context.spacing.sm,
              childAspectRatio: 0.76,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return _buildPlaylistGridCard(context, pl, vm);
            },
          ),
      ],
    );
  }

  Widget _buildPlaylistGridCard(
    BuildContext context,
    PlaylistModel pl,
    LibraryViewModel vm,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPlaylistDetailBottomSheet(context, pl, vm);
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
                  child: _buildPlaylistArtwork(context, pl),
                ),
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pl.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconSm,
                  ),
                  onPressed: () => vm.deletePlaylist(pl.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: context.spacing.xxs),
            Text(
              '${pl.songCount} ${pl.songCount == 1 ? 'song' : 'songs'}',
              maxLines: 1,
              style: context.typography.captionMuted.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistArtwork(BuildContext context, PlaylistModel pl) {
    final thumbs = pl.songs
        .map((s) => s.thumbnailUrl)
        .where((t) => t.isNotEmpty)
        .take(4)
        .toList();

    if (thumbs.length >= 4) {
      return GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: thumbs.map((url) {
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: context.colors.cardDarkSurface,
              child: Icon(Icons.music_note_rounded, color: context.colors.textSecondary, size: 16),
            ),
          );
        }).toList(),
      );
    } else if (thumbs.isNotEmpty) {
      return Image.network(
        thumbs.first,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(context, Icons.queue_music_rounded),
      );
    }

    return _buildPlaceholderIcon(context, Icons.queue_music_rounded);
  }

  // --- DERIVED ALBUMS VIEW ---
  Widget _buildAlbumsView(BuildContext context, LibraryViewModel vm) {
    final albums = vm.derivedAlbums;
    if (albums.isEmpty) {
      return _buildEmptyCard(
        context,
        message: 'No albums in vault yet. Like or play songs to collect albums here.',
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.md,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: context.spacing.sm,
        mainAxisSpacing: context.spacing.sm,
        childAspectRatio: 0.76,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final albumName = albums[index];
        return _buildDerivedAlbumCard(context, albumName, vm);
      },
    );
  }

  Widget _buildDerivedAlbumCard(
    BuildContext context,
    String albumName,
    LibraryViewModel vm,
  ) {
    // Find representative song for thumbnail
    final allSongs = [...vm.likedSongs, ...vm.history];
    for (final p in vm.playlists) {
      allSongs.addAll(p.songs);
    }
    final match = allSongs.firstWhere(
      (s) => s.album.trim().toLowerCase() == albumName.toLowerCase(),
      orElse: () => SongModel(
        id: '',
        title: '',
        artist: '',
        album: albumName,
        thumbnailUrl: '',
        streamUrl: '',
        duration: Duration.zero,
      ),
    );

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(
              album: AlbumModel(
                id: match.id,
                title: albumName,
                subtitle: match.artist,
                artist: match.artist,
                year: '',
                language: '',
                thumbnailUrl: match.thumbnailUrl,
                songCount: 0,
              ),
            ),
          ),
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
                  child: match.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          match.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(context, Icons.album_rounded),
                        )
                      : _buildPlaceholderIcon(context, Icons.album_rounded),
                ),
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              albumName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.spacing.xxs),
            Text(
              match.artist.isNotEmpty ? match.artist : 'Album',
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

  // --- DERIVED ARTISTS VIEW ---
  Widget _buildArtistsView(BuildContext context, LibraryViewModel vm) {
    final artists = vm.derivedArtists;
    if (artists.isEmpty) {
      return _buildEmptyCard(
        context,
        message: 'No artists in vault yet. Like or play songs to collect artists here.',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.md,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      itemCount: artists.length,
      separatorBuilder: (context, index) => SizedBox(height: context.spacing.xs),
      itemBuilder: (context, index) {
        final artistName = artists[index];
        return _buildArtistRow(context, artistName, vm);
      },
    );
  }

  Widget _buildArtistBubble(BuildContext context, String artistName, LibraryViewModel vm) {
    // Find representative thumbnail
    final allSongs = [...vm.likedSongs, ...vm.history];
    for (final p in vm.playlists) {
      allSongs.addAll(p.songs);
    }
    final match = allSongs.firstWhere(
      (s) => s.artist.trim().toLowerCase().contains(artistName.toLowerCase()),
      orElse: () => SongModel(id: '', title: '', artist: artistName, album: '', thumbnailUrl: '', streamUrl: '', duration: Duration.zero),
    );

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(
              artist: ArtistModel(
                id: match.id,
                name: artistName,
                role: 'Artist',
                thumbnailUrl: match.thumbnailUrl,
              ),
            ),
          ),
        );
      },
      borderRadius: context.radius.asBorderRadiusFull,
      child: Column(
        children: [
          Container(
            width: context.sizes.avatarLg * 1.3,
            height: context.sizes.avatarLg * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.cardDarkSurface,
              border: Border.all(
                color: context.colors.solidMatteBorder,
                width: context.sizes.borderThin,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: match.thumbnailUrl.isNotEmpty
                ? Image.network(
                    match.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(context, Icons.person_rounded),
                  )
                : _buildPlaceholderIcon(context, Icons.person_rounded),
          ),
          SizedBox(height: context.spacing.xs),
          SizedBox(
            width: context.sizes.avatarLg * 1.4,
            child: Text(
              artistName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.captionMuted.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistRow(BuildContext context, String artistName, LibraryViewModel vm) {
    final allSongs = [...vm.likedSongs, ...vm.history];
    for (final p in vm.playlists) {
      allSongs.addAll(p.songs);
    }
    final match = allSongs.firstWhere(
      (s) => s.artist.trim().toLowerCase().contains(artistName.toLowerCase()),
      orElse: () => SongModel(id: '', title: '', artist: artistName, album: '', thumbnailUrl: '', streamUrl: '', duration: Duration.zero),
    );

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(
              artist: ArtistModel(
                id: match.id,
                name: artistName,
                role: 'Artist',
                thumbnailUrl: match.thumbnailUrl,
              ),
            ),
          ),
        );
      },
      borderRadius: context.radius.asBorderRadiusMd,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xs,
        ),
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
            Container(
              width: context.sizes.thumbnailMd,
              height: context.sizes.thumbnailMd,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.oledBackground,
                border: Border.all(
                  color: context.colors.solidMatteBorder,
                  width: context.sizes.borderThin,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: match.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      match.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(context, Icons.person_rounded),
                    )
                  : _buildPlaceholderIcon(context, Icons.person_rounded),
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artistName,
                    style: context.typography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    'Artist Profile',
                    style: context.typography.captionMuted.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: context.colors.textSecondary,
              size: context.sizes.iconSm,
            ),
          ],
        ),
      ),
    );
  }

  // --- LIKED SONGS VIEW ---
  Widget _buildLikedSongsView(BuildContext context, LibraryViewModel vm) {
    final songs = vm.likedSongs;

    if (songs.isEmpty) {
      return _buildEmptyCard(
        context,
        message: 'No liked songs yet. Heart songs while listening to save them here.',
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.md,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      children: [
        // Action Bar (Play All / Shuffle)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${songs.length} Tracks',
              style: context.typography.eyebrow,
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconMd,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final shuffled = List<SongModel>.from(songs)..shuffle();
                    context.read<AudioPlayerViewModel>().playFromQueue(shuffled);
                  },
                ),
                SizedBox(width: context.spacing.xs),
                IconButton(
                  icon: Icon(
                    Icons.play_circle_fill_rounded,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconLg,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.read<AudioPlayerViewModel>().playFromQueue(songs);
                  },
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: context.spacing.xs),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return _buildSongRow(context, song);
          },
        ),
      ],
    );
  }

  // --- HISTORY VIEW ---
  Widget _buildHistoryView(BuildContext context, LibraryViewModel vm) {
    final history = vm.history;

    if (history.isEmpty) {
      return _buildEmptyCard(
        context,
        message: 'No listening history yet.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.md,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final song = history[index];
        return _buildSongRow(context, song);
      },
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required String message,
    VoidCallback? onTap,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radius.asBorderRadiusCard,
          child: Container(
            padding: EdgeInsets.all(context.spacing.lg),
            decoration: BoxDecoration(
              color: context.colors.cardDarkSurface,
              borderRadius: context.radius.asBorderRadiusCard,
              border: Border.all(
                color: context.colors.solidMatteBorder,
                width: context.sizes.borderThin,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bookmarks_outlined,
                  size: context.sizes.iconLg,
                  color: context.colors.textSecondary,
                ),
                SizedBox(height: context.spacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.typography.bodyMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context, IconData icon) {
    return Center(
      child: Icon(
        icon,
        color: context.colors.textSecondary,
        size: context.sizes.iconLg,
      ),
    );
  }

  Widget _buildSongRow(BuildContext context, SongModel song) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: context.radius.asBorderRadiusMd,
        onTap: () {
          HapticFeedback.lightImpact();
          context.read<AudioPlayerViewModel>().playSong(song);
          context.read<LibraryViewModel>().addToHistory(song);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
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
                          errorBuilder: (context, error, stackTrace) => Icon(
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
                      style: context.typography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.spacing.xxs),
                    Text(
                      song.artist.isNotEmpty ? song.artist : 'DilSe Track',
                      style: context.typography.captionMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.colors.textSecondary,
                  size: context.sizes.iconSm,
                ),
                onPressed: () => SongOptionsBottomSheet.show(context, song),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaylistDetailBottomSheet(
    BuildContext context,
    PlaylistModel pl,
    LibraryViewModel vm,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.cardDarkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radius.sheet),
        ),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.symmetric(vertical: context.spacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.solidMatteBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pl.title,
                          style: context.typography.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pl.songs.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.play_circle_fill_rounded,
                            color: context.colors.textPrimary,
                            size: context.sizes.iconLg,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                            context.read<AudioPlayerViewModel>().playFromQueue(pl.songs);
                          },
                        ),
                    ],
                  ),
                  Text(
                    '${pl.songCount} tracks',
                    style: context.typography.captionMuted.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: context.spacing.md),
                  Expanded(
                    child: pl.songs.isEmpty
                        ? Center(
                            child: Text(
                              'This playlist is empty.',
                              style: context.typography.bodyMedium.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: pl.songs.length,
                            itemBuilder: (context, idx) {
                              final song = pl.songs[idx];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: context.radius.asBorderRadiusSm,
                                  child: Container(
                                    width: context.sizes.thumbnailMd,
                                    height: context.sizes.thumbnailMd,
                                    color: context.colors.oledBackground,
                                    child: song.thumbnailUrl.isNotEmpty
                                        ? Image.network(song.thumbnailUrl, fit: BoxFit.cover)
                                        : Icon(Icons.music_note_rounded, color: context.colors.textSecondary),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.titleMedium,
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.captionMuted,
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: context.colors.textSecondary,
                                    size: context.sizes.iconSm,
                                  ),
                                  onPressed: () {
                                    vm.removeSongFromPlaylist(pl.id, song.id);
                                    Navigator.pop(ctx);
                                  },
                                ),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(ctx);
                                  context.read<AudioPlayerViewModel>().playFromQueue(
                                        pl.songs,
                                        initialIndex: idx,
                                      );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, LibraryViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.cardDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: context.radius.asBorderRadiusLg,
          side: BorderSide(
            color: context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        title: Text(
          'New Playlist',
          style: context.typography.titleLarge,
        ),
        content: TextField(
          controller: controller,
          style: context.typography.titleMedium,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: context.typography.captionMuted,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.solidMatteBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: context.typography.titleMedium.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.textPrimary,
              foregroundColor: context.colors.oledBackground,
              shape: RoundedRectangleBorder(
                borderRadius: context.radius.asBorderRadiusFull,
              ),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                vm.createPlaylist(controller.text);
                Navigator.pop(ctx);
                DilSeNotification.show(
                  context,
                  message: 'Created "${controller.text.trim()}"',
                );
              }
            },
            child: Text(
              'Create',
              style: context.typography.titleMedium.copyWith(
                color: context.colors.oledBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
