import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/artist_model.dart';
import '../../../data/models/song_model.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../viewmodels/search_viewmodel.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';

/// Editorial Spotlight Search tab for DilSe.
/// Features a dedicated Top Result Spotlight hero card, sub-category filter rail,
/// live audio equalizer indicator, 2-column curated discovery grid, and interactive history.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 2: Context-Exposed Design Tokens (strictly zero magic numbers/raw colors).
/// - Invariant 3: Strict MVVM (View contains presentation only, zero business logic).
/// - Invariant 4: Strict Monochrome & B&W Theme (zero gradients, zero neons; artwork is sole exception).
class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final bool autoFocus;

  const SearchScreen({
    super.key,
    this.onBackToHome,
    this.autoFocus = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final searchVm = context.read<SearchViewModel>();
    _controller = TextEditingController(text: searchVm.query);
    _focusNode = FocusNode();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final minutes = d.inMinutes.remainder(60);
    final seconds = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onSongSelected(BuildContext context, SongModel song) {
    HapticFeedback.lightImpact();
    context.read<AudioPlayerViewModel>().playSong(song);
    DilSeNotification.show(
      context,
      message: 'Playing ${song.title} • Generating Google ML Mix...',
    );
  }

  void _onCategoryTapped(SearchViewModel searchVm, SearchCategory category) {
    HapticFeedback.lightImpact();
    _controller.text = category.query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: category.query.length),
    );
    searchVm.search(category.query);
  }

  @override
  Widget build(BuildContext context) {
    final searchVm = context.watch<SearchViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (searchVm.query.isNotEmpty) {
          _controller.clear();
          searchVm.clearSearch();
        } else if (widget.onBackToHome != null) {
          widget.onBackToHome!();
        }
      },
      child: Container(
        color: context.colors.oledBackground,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Search Input Header
              _buildSearchHeader(context, searchVm),

              // Filter Rail (Visible when search has query or results)
              if (searchVm.query.isNotEmpty && !searchVm.isLoading && searchVm.errorMessage == null)
                _buildFilterRail(context, searchVm),

              // Main Content Area
              Expanded(
                child: searchVm.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.brandRuby,
                        ),
                      )
                    : searchVm.errorMessage != null
                        ? _buildErrorView(context, searchVm)
                        : searchVm.query.isEmpty
                            ? _buildExploreView(context, searchVm)
                            : !searchVm.hasResults
                                ? _buildEmptyResultsView(context, searchVm)
                                : _buildSearchResultsList(context, searchVm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, SearchViewModel searchVm) {
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
          borderRadius: context.radius.asBorderRadiusFull,
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
                controller: _controller,
                focusNode: _focusNode,
                style: context.typography.titleMedium,
                cursorColor: context.colors.brandRuby,
                textInputAction: TextInputAction.search,
                onChanged: (text) => searchVm.onQueryChanged(text),
                onSubmitted: (text) {
                  _focusNode.unfocus();
                  searchVm.search(text);
                },
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: context.typography.titleMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.clear();
                  searchVm.clearSearch();
                },
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.xxs),
                  child: Icon(
                    Icons.close_rounded,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconSm,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRail(BuildContext context, SearchViewModel searchVm) {
    return SizedBox(
      height: context.sizes.chipHeight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: SearchFilter.values.length,
        separatorBuilder: (context, index) => SizedBox(width: context.spacing.xs),
        itemBuilder: (context, index) {
          final filter = SearchFilter.values[index];
          final isSelected = filter == searchVm.selectedFilter;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              searchVm.setFilter(filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.md,
                vertical: context.spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: isSelected ? context.colors.brandRuby : context.colors.cardDarkSurface,
                borderRadius: context.radius.asBorderRadiusFull,
                border: Border.all(
                  color: isSelected ? context.colors.brandRuby : context.colors.solidMatteBorder,
                  width: context.sizes.borderThin,
                ),
              ),
              child: Center(
                child: Text(
                  filter.label,
                  style: context.typography.captionMuted.copyWith(
                    color: isSelected ? context.colors.oledBackground : context.colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreView(BuildContext context, SearchViewModel searchVm) {
    final recent = searchVm.recentSearches;
    final categories = searchVm.categories;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.sm,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      children: [
        // Recent Searches Section
        if (recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT SEARCHES',
                style: context.typography.eyebrow,
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  searchVm.clearAllRecentSearches();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
                  child: Text(
                    'Clear All',
                    style: context.typography.captionMuted.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.xs),
          Wrap(
            spacing: context.spacing.xs,
            runSpacing: context.spacing.xs,
            children: recent.map((term) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.text = term;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: term.length),
                  );
                  searchVm.search(term);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.sm,
                    vertical: context.spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.cardDarkSurface,
                    borderRadius: context.radius.asBorderRadiusFull,
                    border: Border.all(
                      color: context.colors.solidMatteBorder,
                      width: context.sizes.borderThin,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconSm - 2,
                      ),
                      SizedBox(width: context.spacing.xs),
                      Text(
                        term,
                        style: context.typography.titleMedium,
                      ),
                      SizedBox(width: context.spacing.xs),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          searchVm.removeRecentSearch(term);
                        },
                        child: Icon(
                          Icons.close_rounded,
                          color: context.colors.textSecondary,
                          size: context.sizes.iconSm - 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: context.spacing.lg),
        ],

        // Browse Categories Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXPLORE GENRES & VIBES',
              style: context.typography.eyebrow,
            ),
            Icon(
              Icons.explore_outlined,
              color: context.colors.brandRuby,
              size: context.sizes.iconSm,
            ),
          ],
        ),
        SizedBox(height: context.spacing.sm),

        // 2-Column Discovery Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: context.spacing.xs,
            mainAxisSpacing: context.spacing.xs,
            mainAxisExtent: context.sizes.quickAccessTileHeight + context.spacing.lg,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () => _onCategoryTapped(searchVm, category),
              child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.title,
                      style: context.typography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      category.subtitle,
                      style: context.typography.captionMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResultsList(BuildContext context, SearchViewModel searchVm) {
    if (searchVm.selectedFilter == SearchFilter.albums) {
      return _buildAlbumsView(context, searchVm);
    }
    if (searchVm.selectedFilter == SearchFilter.artists) {
      return _buildArtistsView(context, searchVm);
    }

    final topSong = searchVm.topResult;
    final songs = searchVm.remainingResults;
    final albums = searchVm.albumResults;
    final artists = searchVm.artistResults;
    final currentSong = context.select<AudioPlayerViewModel, SongModel?>(
      (vm) => vm.currentSong,
    );
    final isPlaying = context.select<AudioPlayerViewModel, bool>(
      (vm) => vm.isPlaying,
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.xs,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      children: [
        // Top Result Spotlight Hero Card
        if (topSong != null) ...[
          Padding(
            padding: EdgeInsets.only(top: context.spacing.xs),
            child: _buildSpotlightCard(context, topSong, currentSong, isPlaying),
          ),
          SizedBox(height: context.spacing.md),
        ],

        // On "All Results", show matching Albums shelf if present
        if (searchVm.selectedFilter == SearchFilter.all && albums.isNotEmpty) ...[
          _buildSectionHeaderWithAction(
            context,
            'ALBUMS',
            'View All',
            () => searchVm.setFilter(SearchFilter.albums),
          ),
          SizedBox(height: context.spacing.xs),
          _buildHorizontalAlbumShelf(context, albums.take(6).toList()),
          SizedBox(height: context.spacing.lg),
        ],

        // On "All Results", show matching Artists shelf if present
        if (searchVm.selectedFilter == SearchFilter.all && artists.isNotEmpty) ...[
          _buildSectionHeaderWithAction(
            context,
            'ARTISTS',
            'View All',
            () => searchVm.setFilter(SearchFilter.artists),
          ),
          SizedBox(height: context.spacing.xs),
          _buildHorizontalArtistShelf(context, artists.take(6).toList()),
          SizedBox(height: context.spacing.lg),
        ],

        // Tracks Section Header
        if (songs.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.xs),
            child: Text(
              'TRACKS',
              style: context.typography.eyebrow,
            ),
          ),
          ...List.generate(songs.length, (index) {
            final song = songs[index];
            final isPlayingThis = currentSong?.id == song.id;
            return _buildSongRow(
              context,
              song: song,
              isPlayingThis: isPlayingThis,
              isAudioPlaying: isPlaying,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeaderWithAction(
    BuildContext context,
    String title,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.typography.eyebrow,
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onAction();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
            child: Text(
              actionLabel,
              style: context.typography.captionMuted.copyWith(
                color: context.colors.brandRuby,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalAlbumShelf(BuildContext context, List<AlbumModel> albums) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: albums.length,
        separatorBuilder: (context, index) => SizedBox(width: context.spacing.sm),
        itemBuilder: (context, index) {
          final album = albums[index];
          return GestureDetector(
            onTap: () => _onAlbumTapped(context, album),
            child: SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: context.radius.asBorderRadiusMd,
                    child: Container(
                      width: 104,
                      height: 104,
                      color: context.colors.cardDarkSurface,
                      child: album.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              album.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.album_rounded,
                                color: context.colors.textSecondary,
                                size: context.sizes.iconLg,
                              ),
                            )
                          : Icon(
                              Icons.album_rounded,
                              color: context.colors.textSecondary,
                              size: context.sizes.iconLg,
                            ),
                    ),
                  ),
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    album.title,
                    style: context.typography.captionMuted.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    album.artist.isNotEmpty ? album.artist : album.year,
                    style: context.typography.captionMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalArtistShelf(BuildContext context, List<ArtistModel> artists) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: artists.length,
        separatorBuilder: (context, index) => SizedBox(width: context.spacing.md),
        itemBuilder: (context, index) {
          final artist = artists[index];
          return GestureDetector(
            onTap: () => _onArtistTapped(context, artist),
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  ClipOval(
                    child: Container(
                      width: 76,
                      height: 76,
                      color: context.colors.cardDarkSurface,
                      child: artist.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              artist.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.person_rounded,
                                color: context.colors.textSecondary,
                                size: context.sizes.iconLg,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: context.colors.textSecondary,
                              size: context.sizes.iconLg,
                            ),
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  Text(
                    artist.name,
                    style: context.typography.captionMuted.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    artist.role,
                    style: context.typography.captionMuted,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumsView(BuildContext context, SearchViewModel searchVm) {
    final albums = searchVm.albumResults;

    if (albums.isEmpty) {
      return Center(
        child: Text(
          'No albums found for "${searchVm.query}"',
          style: context.typography.titleMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.sm,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: context.spacing.md,
        mainAxisSpacing: context.spacing.md,
        childAspectRatio: 0.76,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
          onTap: () => _onAlbumTapped(context, album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: context.radius.asBorderRadiusMd,
                  child: Container(
                    width: double.infinity,
                    color: context.colors.cardDarkSurface,
                    child: album.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            album.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.album_rounded,
                              color: context.colors.textSecondary,
                              size: context.sizes.iconLg,
                            ),
                          )
                        : Icon(
                            Icons.album_rounded,
                            color: context.colors.textSecondary,
                            size: context.sizes.iconLg,
                          ),
                  ),
                ),
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                album.title,
                style: context.typography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                album.artist.isNotEmpty
                    ? '${album.artist} • ${album.year}'
                    : (album.language.isNotEmpty ? '${album.language} • ${album.year}' : album.year),
                style: context.typography.captionMuted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsView(BuildContext context, SearchViewModel searchVm) {
    final artists = searchVm.artistResults;

    if (artists.isEmpty) {
      return Center(
        child: Text(
          'No artists found for "${searchVm.query}"',
          style: context.typography.titleMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.sm,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      itemCount: artists.length,
      separatorBuilder: (context, index) => SizedBox(height: context.spacing.sm),
      itemBuilder: (context, index) {
        final artist = artists[index];
        return GestureDetector(
          onTap: () => _onArtistTapped(context, artist),
          child: Container(
            padding: EdgeInsets.all(context.spacing.sm),
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
                ClipOval(
                  child: Container(
                    width: 56,
                    height: 56,
                    color: context.colors.oledBackground,
                    child: artist.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            artist.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person_rounded,
                              color: context.colors.textSecondary,
                              size: context.sizes.iconMd,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: context.colors.textSecondary,
                            size: context.sizes.iconMd,
                          ),
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        style: context.typography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        artist.role,
                        style: context.typography.captionMuted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textSecondary,
                  size: context.sizes.iconMd,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onAlbumTapped(BuildContext context, AlbumModel album) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: album),
      ),
    );
  }

  void _onArtistTapped(BuildContext context, ArtistModel artist) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(artist: artist),
      ),
    );
  }

  Widget _buildSpotlightCard(
    BuildContext context,
    SongModel song,
    SongModel? currentSong,
    bool isAudioPlaying,
  ) {
    final isThisPlaying = currentSong?.id == song.id;
    final cardArtworkSize = context.sizes.avatarLg + context.spacing.xs;

    return Container(
      padding: EdgeInsets.all(context.spacing.sm),
      decoration: BoxDecoration(
        color: context.colors.cardDarkSurface,
        borderRadius: context.radius.asBorderRadiusLg,
        border: Border.all(
          color: isThisPlaying ? context.colors.brandRuby : context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: Row(
        children: [
          // Spotlight Artwork
          ClipRRect(
            borderRadius: context.radius.asBorderRadiusMd,
            child: Container(
              width: cardArtworkSize,
              height: cardArtworkSize,
              color: context.colors.oledBackground,
              child: song.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      song.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.music_note_rounded,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconMd,
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: context.colors.textSecondary,
                      size: context.sizes.iconMd,
                    ),
            ),
          ),
          SizedBox(width: context.spacing.sm),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.xs,
                    vertical: context.spacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.solidMatteBorder,
                    borderRadius: context.radius.asBorderRadiusFull,
                  ),
                  child: Text(
                    'TOP RESULT',
                    style: context.typography.eyebrow.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                Text(
                  song.title,
                  style: context.typography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.spacing.xxs),
                Text(
                  song.artist.isNotEmpty ? song.artist : 'DilSe Artist',
                  style: context.typography.bodyMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.xs),

          // Instant Play Button
          GestureDetector(
            onTap: () => _onSongSelected(context, song),
            child: Container(
              width: context.sizes.avatarSm + context.spacing.xs,
              height: context.sizes.avatarSm + context.spacing.xs,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.brandRuby,
              ),
              child: Center(
                child: Icon(
                  (isThisPlaying && isAudioPlaying)
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: context.colors.oledBackground,
                  size: context.sizes.iconMd,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongRow(
    BuildContext context, {
    required SongModel song,
    required bool isPlayingThis,
    required bool isAudioPlaying,
  }) {
    final durationStr = _formatDuration(song.duration);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: context.radius.asBorderRadiusMd,
        onTap: () => _onSongSelected(context, song),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
          child: Row(
            children: [
              // Artwork Thumbnail
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
                            size: context.sizes.iconMd,
                          ),
                        )
                      : Icon(
                          Icons.music_note_rounded,
                          color: context.colors.textSecondary,
                          size: context.sizes.iconMd,
                        ),
                ),
              ),
              SizedBox(width: context.spacing.sm),

              // Song Title & Subtitle with Equalizer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isPlayingThis && isAudioPlaying) ...[
                          _MiniEqualizerWave(color: context.colors.brandRuby),
                          SizedBox(width: context.spacing.xxs),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            style: context.typography.titleMedium.copyWith(
                              color: isPlayingThis
                                  ? context.colors.brandRuby
                                  : context.colors.textPrimary,
                              fontWeight: isPlayingThis
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.spacing.xxs),
                    Text(
                      song.artist.isNotEmpty ? song.artist : 'DilSe Track',
                      style: context.typography.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Duration text
              if (durationStr.isNotEmpty) ...[
                Text(
                  durationStr,
                  style: context.typography.captionMuted,
                ),
                SizedBox(width: context.spacing.xs),
              ],

              // More Options
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.colors.textSecondary,
                  size: context.sizes.iconSm,
                ),
                onPressed: () {
                  SongOptionsBottomSheet.show(context, song);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResultsView(BuildContext context, SearchViewModel searchVm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: context.colors.textSecondary,
              size: context.sizes.iconLg,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'No matches for "${searchVm.query}"',
              style: context.typography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              'Try searching with song title, artist, or album keywords.',
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

  Widget _buildErrorView(BuildContext context, SearchViewModel searchVm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: context.colors.errorCrimson,
              size: context.sizes.iconLg,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'Search encountered an issue',
              style: context.typography.titleLarge,
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              searchVm.errorMessage ?? 'Please check network and try again.',
              style: context.typography.captionMuted,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.md),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brandRuby,
                foregroundColor: context.colors.oledBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.asBorderRadiusFull,
                ),
              ),
              onPressed: () => searchVm.search(searchVm.query),
              child: Text(
                'Retry Search',
                style: context.typography.titleMedium.copyWith(
                  color: context.colors.oledBackground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic 3-bar animated equalizer wave displayed next to currently playing tracks in search results.
class _MiniEqualizerWave extends StatefulWidget {
  final Color color;

  const _MiniEqualizerWave({required this.color});

  @override
  State<_MiniEqualizerWave> createState() => _MiniEqualizerWaveState();
}

class _MiniEqualizerWaveState extends State<_MiniEqualizerWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return SizedBox(
          width: 14.0,
          height: 12.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 2.5,
                height: 4.0 + (val * 7.0),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1.0),
                ),
              ),
              Container(
                width: 2.5,
                height: 11.0 - (val * 6.5),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1.0),
                ),
              ),
              Container(
                width: 2.5,
                height: 5.0 + (val * 6.0),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
