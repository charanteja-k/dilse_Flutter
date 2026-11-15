import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/playlist_model.dart';
import '../../../data/models/song_model.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../viewmodels/library_viewmodel.dart';

/// Pure Monochrome Library Screen adhering to AGENTS.md Invariants 1-4.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'LIBRARY',
            style: context.typography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (vm.currentSection == LibrarySection.playlists)
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
                  color: context.colors.solidMatteBorder,
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
        // Create Playlist Banner
        GestureDetector(
          onTap: () => _showCreatePlaylistDialog(context, vm),
          child: Container(
            padding: EdgeInsets.all(context.spacing.md),
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
                    color: context.colors.oledBackground,
                    borderRadius: context.radius.asBorderRadiusSm,
                    border: Border.all(
                      color: context.colors.solidMatteBorder,
                      width: context.sizes.borderThin,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconMd,
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Playlist',
                        style: context.typography.titleMedium,
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        'Build your custom collections',
                        style: context.typography.captionMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: context.spacing.md),

        if (playlists.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.xl),
              child: Text(
                'No playlists yet. Tap above to create one.',
                style: context.typography.bodyMedium,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: playlists.length,
            separatorBuilder: (context, index) => SizedBox(height: context.spacing.xs),
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return _buildPlaylistTile(context, pl, vm);
            },
          ),
      ],
    );
  }

  Widget _buildPlaylistTile(
      BuildContext context, PlaylistModel pl, LibraryViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.cardDarkSurface,
        borderRadius: context.radius.asBorderRadiusMd,
        border: Border.all(
          color: context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xxs,
        ),
        leading: ClipRRect(
          borderRadius: context.radius.asBorderRadiusSm,
          child: Container(
            width: context.sizes.thumbnailMd,
            height: context.sizes.thumbnailMd,
            color: context.colors.oledBackground,
            child: pl.thumbnailUrl.isNotEmpty
                ? Image.network(
                    pl.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.queue_music_rounded,
                      color: context.colors.textSecondary,
                    ),
                  )
                : Icon(
                    Icons.queue_music_rounded,
                    color: context.colors.textSecondary,
                  ),
          ),
        ),
        title: Text(
          pl.title,
          style: context.typography.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${pl.songCount} songs',
          style: context.typography.captionMuted,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pl.songs.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: context.colors.textPrimary,
                  size: context.sizes.iconMd,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<AudioPlayerViewModel>().playFromQueue(pl.songs);
                },
              ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.colors.textSecondary,
                size: context.sizes.iconSm,
              ),
              onPressed: () => vm.deletePlaylist(pl.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikedSongsView(BuildContext context, LibraryViewModel vm) {
    final songs = vm.likedSongs;

    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: context.sizes.iconLg,
                color: context.colors.textSecondary,
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                'No liked songs yet',
                style: context.typography.headlineMedium,
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                'Heart songs while listening to save them here.',
                style: context.typography.bodyMedium,
              ),
            ],
          ),
        ),
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
                    context
                        .read<AudioPlayerViewModel>()
                        .playFromQueue(shuffled);
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

        // Boxless Song Rows on OLED Black
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

  Widget _buildHistoryView(BuildContext context, LibraryViewModel vm) {
    final history = vm.history;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl),
          child: Text(
            'No listening history yet.',
            style: context.typography.bodyMedium,
          ),
        ),
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

  Widget _buildAlbumsView(BuildContext context, LibraryViewModel vm) {
    final albums = vm.derivedAlbums;
    if (albums.isEmpty) {
      return Center(
        child: Text(
          'No albums in library yet.',
          style: context.typography.bodyMedium,
        ),
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
      itemCount: albums.length,
      separatorBuilder: (context, index) => SizedBox(height: context.spacing.xs),
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          leading: Icon(
            Icons.album_rounded,
            color: context.colors.textSecondary,
            size: context.sizes.iconMd,
          ),
          title: Text(album, style: context.typography.titleMedium),
        );
      },
    );
  }

  Widget _buildArtistsView(BuildContext context, LibraryViewModel vm) {
    final artists = vm.derivedArtists;
    if (artists.isEmpty) {
      return Center(
        child: Text(
          'No artists in library yet.',
          style: context.typography.bodyMedium,
        ),
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
        final artist = artists[index];
        return ListTile(
          leading: Icon(
            Icons.person_rounded,
            color: context.colors.textSecondary,
            size: context.sizes.iconMd,
          ),
          title: Text(artist, style: context.typography.titleMedium),
        );
      },
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
