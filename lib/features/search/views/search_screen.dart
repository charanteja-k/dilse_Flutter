import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/song_model.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/song_options_bottom_sheet.dart';
import '../viewmodels/search_viewmodel.dart';

/// Pure View for song search and Google ML queue initiation.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 2: Context-Exposed Design Tokens (strictly zero magic numbers/raw colors).
/// - Invariant 3: Strict MVVM (View contains presentation only, zero business logic).
class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final bool autoFocus;

  const SearchScreen({
    super.key,
    this.onBackToHome,
    this.autoFocus = true,
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
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input Header
            _buildSearchHeader(context, searchVm),

            // Content Area
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
                          ? _buildTrendingSection(context, searchVm)
                          : !searchVm.hasResults
                              ? _buildEmptyResultsView(context, searchVm)
                              : _buildSearchResultsList(context, searchVm),
            ),
          ],
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
      child: Row(
        children: [
          if (widget.onBackToHome != null) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.colors.textPrimary,
                size: context.sizes.iconSm,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _focusNode.unfocus();
                widget.onBackToHome!();
              },
            ),
            SizedBox(width: context.spacing.xxs),
          ],
          Expanded(
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
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(BuildContext context, SearchViewModel searchVm) {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT & TRENDING',
              style: context.typography.eyebrow,
            ),
            Icon(
              Icons.trending_up_rounded,
              color: context.colors.brandRuby,
              size: context.sizes.iconSm,
            ),
          ],
        ),
        SizedBox(height: context.spacing.sm),
        Wrap(
          spacing: context.spacing.xs,
          runSpacing: context.spacing.xs,
          children: searchVm.recentSearches.map((term) {
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
                  horizontal: context.spacing.md,
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
                      size: context.sizes.iconSm,
                    ),
                    SizedBox(width: context.spacing.xs),
                    Text(
                      term,
                      style: context.typography.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList(BuildContext context, SearchViewModel searchVm) {
    final results = searchVm.searchResults;

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.md,
        top: context.spacing.xs,
        bottom: context.sizes.miniPlayerHeight +
            context.sizes.navDockHeight +
            context.spacing.xl,
      ),
      itemCount: results.length,
      separatorBuilder: (context, index) => SizedBox(height: context.spacing.xs),
      itemBuilder: (context, index) {
        final song = results[index];
        final durationStr = _formatDuration(song.duration);

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
            title: Text(
              song.title,
              style: context.typography.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist.isNotEmpty ? song.artist : 'DilSe Track',
              style: context.typography.captionMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (durationStr.isNotEmpty) ...[
                  Text(
                    durationStr,
                    style: context.typography.captionMuted,
                  ),
                  SizedBox(width: context.spacing.xxs),
                ],
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
            onTap: () => _onSongSelected(context, song),
          ),
        );
      },
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
                foregroundColor: context.colors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.asBorderRadiusFull,
                ),
              ),
              onPressed: () => searchVm.search(searchVm.query),
              child: const Text('Retry Search'),
            ),
          ],
        ),
      ),
    );
  }
}

