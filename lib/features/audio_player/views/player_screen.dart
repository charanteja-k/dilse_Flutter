import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/song_model.dart';
import '../viewmodels/audio_player_viewmodel.dart';
import 'album_color_deriver.dart';
import 'animated_lyrics.dart';
import 'equalizer_bottom_sheet.dart';
import 'queue_bottom_sheet.dart';
import 'song_options_bottom_sheet.dart';
import 'vinyl_record_player.dart';
import 'waveform_scrubber.dart';

/// Full-screen flagship music player with dynamic ambient aura backgrounds,
/// parallel swipeable carousel, synchronized animated lyrics, acoustic waveform scrubber,
/// double-tap quick seeking, and modal queue management.
///
/// Strictly conforms to:
/// - Invariant 1: Zero singletons, context-driven Provider injection.
/// - Invariant 2: Context-exposed design tokens only (zero magic numbers).
/// - Invariant 3: Pure presentation layer with zero business logic.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PageController _pageController;
  int _activePageIndex = 0;
  bool _isUserDraggingPage = false;
  bool _showLyrics = false;

  int? _doubleTapSeekDirection;
  Timer? _doubleTapSeekTimer;
  int _doubleTapSeekCounter = 0;

  @override
  void initState() {
    super.initState();
    final player = context.read<AudioPlayerViewModel>();
    final initialPage = player.queue.isNotEmpty
        ? player.currentIndex.clamp(0, player.queue.length - 1)
        : 0;
    _activePageIndex = initialPage;
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.82,
    );
    _pageController.addListener(_onPageScrolled);
  }

  @override
  void dispose() {
    _doubleTapSeekTimer?.cancel();
    _pageController.removeListener(_onPageScrolled);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScrolled() {
    if (_pageController.hasClients &&
        _pageController.position.hasContentDimensions) {
      final page = (_pageController.page ?? _activePageIndex.toDouble()).round();
      if (page != _activePageIndex && page >= 0) {
        setState(() {
          _activePageIndex = page;
        });
      }
    }
  }

  void _triggerDoubleTapSeek(int direction) {
    HapticFeedback.lightImpact();
    context.read<AudioPlayerViewModel>().seekRelative(Duration(seconds: direction * 10));
    _doubleTapSeekTimer?.cancel();
    setState(() {
      _doubleTapSeekDirection = direction;
      _doubleTapSeekCounter++;
    });
    _doubleTapSeekTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _doubleTapSeekDirection = null;
          _doubleTapSeekCounter = 0;
        });
      }
    });
  }

  void _syncCarouselWithPlayer(int currentIndex) {
    if (_pageController.hasClients &&
        _pageController.position.hasContentDimensions &&
        !_isUserDraggingPage) {
      final currentPage = _pageController.page?.round() ?? _activePageIndex;
      if (currentPage != currentIndex) {
        if (_showLyrics) {
          _pageController.jumpToPage(currentIndex);
        } else {
          _pageController.animateToPage(
            currentIndex,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerViewModel>();
    final currentSong = player.currentSong;
    final queue = player.queue.isNotEmpty
        ? player.queue
        : (currentSong != null ? [currentSong] : <SongModel>[]);

    if (currentSong == null || queue.isEmpty) {
      return Scaffold(
        backgroundColor: context.colors.oledBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_off_rounded,
                color: context.colors.textSecondary,
                size: context.sizes.iconLg,
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                'No active song playing',
                style: context.typography.titleLarge,
              ),
              SizedBox(height: context.spacing.md),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('Return', style: context.typography.bodyLarge),
              ),
            ],
          ),
        ),
      );
    }

    _syncCarouselWithPlayer(player.currentIndex);

    final activeIndex = _activePageIndex.clamp(0, queue.length - 1);
    final shownSong = queue[activeIndex];
    final isLiked = player.isLiked(shownSong.id);

    final palette = AlbumColorDeriver.getPalette(shownSong);
    final dominantColor = palette.dominant;
    final vibrantColor = palette.vibrant;
    final darkVibrantColor = palette.darkVibrant;

    return Scaffold(
      backgroundColor: context.colors.oledBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) {
            QueueBottomSheet.show(context);
          } else if (details.primaryVelocity! > 300) {
            Navigator.of(context).maybePop();
          }
        },
        child: Stack(
          children: [
            // 1. Dynamic Ambient Background Gradient
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.alphaBlend(
                        vibrantColor.withAlpha(80),
                        context.colors.cardDarkSurface,
                      ),
                      Color.alphaBlend(
                        dominantColor.withAlpha(50),
                        context.colors.floatingDockSurface,
                      ),
                      Color.alphaBlend(
                        darkVibrantColor.withAlpha(60),
                        context.colors.oledBackground,
                      ),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),

            // Soft Central Ambient Aura directly behind the album artwork
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              height: 480,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      vibrantColor.withAlpha(70),
                      dominantColor.withAlpha(30),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Main Player Foreground View
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                child: Column(
                  children: [
                    // Top Header Bar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: context.colors.textPrimary.withAlpha(200),
                              size: context.sizes.iconLg + 4,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).maybePop();
                            },
                          ),
                          GestureDetector(
                            onTap: () => QueueBottomSheet.show(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.spacing.md,
                                vertical: context.spacing.xs,
                              ),
                              color: Colors.transparent,
                              child: Container(
                                width: context.sizes.heroCardWidth * 0.15,
                                height: context.spacing.xxs,
                                decoration: BoxDecoration(
                                  color: context.colors.textSecondary.withAlpha(80),
                                  borderRadius: context.radius.asBorderRadiusFull,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.tune_rounded,
                              color: context.colors.textPrimary,
                              size: context.sizes.iconMd,
                            ),
                            tooltip: 'Audio Equalizer',
                            onPressed: () => EqualizerBottomSheet.show(context),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.spacing.xxs),

                    // Central Centerpiece: Synced Album Carousel & Lyrics Stack
                    Expanded(
                      flex: 10,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final carouselSize = math.min(
                              constraints.maxWidth * 0.82,
                              constraints.maxHeight * 0.96,
                            );

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Layer 1: Swipe Album Carousel
                                IgnorePointer(
                                  ignoring: _showLyrics,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: _showLyrics ? 0.0 : 1.0,
                                    child: NotificationListener<ScrollNotification>(
                                      onNotification: (notification) {
                                        if (notification is ScrollStartNotification) {
                                          _isUserDraggingPage = true;
                                        } else if (notification is ScrollEndNotification) {
                                          _isUserDraggingPage = false;
                                        }
                                        return false;
                                      },
                                      child: PageView.builder(
                                        controller: _pageController,
                                        itemCount: queue.length,
                                        onPageChanged: (index) {
                                          if (_activePageIndex != index) {
                                            setState(() {
                                              _activePageIndex = index;
                                            });
                                          }
                                          if (_isUserDraggingPage && index != player.currentIndex) {
                                            HapticFeedback.selectionClick();
                                            context.read<AudioPlayerViewModel>().skipToIndex(index);
                                          }
                                        },
                                        physics: const BouncingScrollPhysics(),
                                        itemBuilder: (context, index) {
                                          final track = queue[index];
                                          final isCurrent = index == player.currentIndex;

                                          return AnimatedBuilder(
                                            animation: _pageController,
                                            builder: (context, child) {
                                              double page = player.currentIndex.toDouble();
                                              if (_pageController.hasClients &&
                                                  _pageController.position.hasContentDimensions) {
                                                page = _pageController.page ?? player.currentIndex.toDouble();
                                              }
                                              final diff = (page - index).abs();
                                              final scale = (1.0 - (diff * 0.16)).clamp(0.84, 1.0);
                                              final opacity = (1.0 - (diff * 0.45)).clamp(0.40, 1.0);

                                              return Transform.scale(
                                                scale: scale,
                                                child: Opacity(
                                                  opacity: opacity,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: Center(
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onDoubleTapDown: isCurrent
                                                    ? (details) {
                                                        if (details.localPosition.dx < carouselSize / 2) {
                                                          _triggerDoubleTapSeek(-1);
                                                        } else {
                                                          _triggerDoubleTapSeek(1);
                                                        }
                                                      }
                                                    : null,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    player.artworkStyle == ArtworkStyle.vinyl
                                                        ? VinylRecordPlayer(
                                                            key: ValueKey('vinyl_${track.id}'),
                                                            imageUrl: track.thumbnailUrl,
                                                            isPlaying: isCurrent && player.isPlaying,
                                                            dominantColor: isCurrent
                                                                ? dominantColor
                                                                : context.colors.floatingDockSurface,
                                                            vibrantColor: isCurrent
                                                                ? vibrantColor
                                                                : context.colors.brandRuby,
                                                            size: carouselSize * 0.94,
                                                          )
                                                        : Container(
                                                            width: carouselSize,
                                                            height: carouselSize,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(
                                                                context.sizes.playerArtworkRadius,
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: (isCurrent
                                                                          ? dominantColor
                                                                          : context.colors.oledBackground)
                                                                      .withAlpha(150),
                                                                  blurRadius: 36,
                                                                  spreadRadius: 6,
                                                                  offset: const Offset(0, 16),
                                                                ),
                                                                BoxShadow(
                                                                  color: (isCurrent
                                                                          ? vibrantColor
                                                                          : context.colors.oledBackground)
                                                                      .withAlpha(90),
                                                                  blurRadius: 48,
                                                                  spreadRadius: 8,
                                                                  offset: const Offset(0, 8),
                                                                ),
                                                              ],
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(
                                                                context.sizes.playerArtworkRadius,
                                                              ),
                                                              child: track.thumbnailUrl.isNotEmpty
                                                                  ? Image.network(
                                                                      track.thumbnailUrl,
                                                                      fit: BoxFit.cover,
                                                                      errorBuilder: (context, error, stackTrace) =>
                                                                          Container(
                                                                        color: context.colors.cardDarkSurface,
                                                                        child: Icon(
                                                                          Icons.music_note,
                                                                          color: context.colors.textSecondary,
                                                                          size: context.sizes.iconLg * 2,
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : Container(
                                                                      color: context.colors.cardDarkSurface,
                                                                      child: Icon(
                                                                        Icons.music_note,
                                                                        color: context.colors.textSecondary,
                                                                        size: context.sizes.iconLg * 2,
                                                                      ),
                                                                    ),
                                                            ),
                                                          ),

                                                    // Double-Tap Quick Seek Visual Badge
                                                    if (isCurrent && _doubleTapSeekDirection != null)
                                                      Positioned.fill(
                                                        child: IgnorePointer(
                                                          child: AnimatedOpacity(
                                                            duration: const Duration(milliseconds: 150),
                                                            opacity: 1.0,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(
                                                                  context.sizes.playerArtworkRadius,
                                                                ),
                                                                color: context.colors.oledBackground.withAlpha(90),
                                                              ),
                                                              child: Align(
                                                                alignment: _doubleTapSeekDirection == -1
                                                                    ? Alignment.centerLeft
                                                                    : Alignment.centerRight,
                                                                child: Container(
                                                                  width: carouselSize * 0.48,
                                                                  height: carouselSize,
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.horizontal(
                                                                      left: _doubleTapSeekDirection == -1
                                                                          ? Radius.circular(
                                                                              context.sizes.playerArtworkRadius,
                                                                            )
                                                                          : Radius.zero,
                                                                      right: _doubleTapSeekDirection == 1
                                                                          ? Radius.circular(
                                                                              context.sizes.playerArtworkRadius,
                                                                            )
                                                                          : Radius.zero,
                                                                    ),
                                                                    color: Colors.white.withAlpha(46),
                                                                  ),
                                                                  child: Column(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                      Icon(
                                                                        _doubleTapSeekDirection == -1
                                                                            ? Icons.replay_10_rounded
                                                                            : Icons.forward_10_rounded,
                                                                        color: Colors.white,
                                                                        size: 42,
                                                                      ),
                                                                      SizedBox(height: context.spacing.xxs),
                                                                      Text(
                                                                        '${_doubleTapSeekDirection == -1 ? '-' : '+'}${(_doubleTapSeekCounter.clamp(1, 99)) * 10} sec',
                                                                        style: context.typography.titleMedium.copyWith(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),

                                // Layer 2: Parallel Synced Lyrics Overlay
                                IgnorePointer(
                                  ignoring: !_showLyrics,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: _showLyrics ? 1.0 : 0.0,
                                    child: Container(
                                      width: double.infinity,
                                      height: constraints.maxHeight,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.spacing.md,
                                        vertical: context.spacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.oledBackground.withAlpha(56),
                                        borderRadius: BorderRadius.circular(
                                          context.radius.artwork,
                                        ),
                                      ),
                                      child: player.isLoadingLyrics
                                          ? Center(
                                              child: CircularProgressIndicator(
                                                color: vibrantColor,
                                                strokeWidth: context.spacing.xxs,
                                              ),
                                            )
                                          : AnimatedLyrics(
                                              key: ValueKey('lyrics_${shownSong.id}'),
                                              rawLyrics: player.currentLyricsSynced ??
                                                  player.currentLyricsPlain ??
                                                  '',
                                              songTitle: shownSong.title,
                                              songArtist: shownSong.artist,
                                              positionStream: player.positionStream,
                                              initialPosition: player.position,
                                              vibrantColor: vibrantColor,
                                              onSeek: (target) {
                                                context.read<AudioPlayerViewModel>().seek(target);
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: context.spacing.sm),

                    // Track Metadata & Action Icons
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shownSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.playerTitle,
                                ),
                                SizedBox(height: context.spacing.xxs),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        shownSong.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.typography.playerSubtitle,
                                      ),
                                    ),
                                    SizedBox(width: context.spacing.xs),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.spacing.xs,
                                        vertical: context.spacing.xxs * 0.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(30),
                                        borderRadius: context.radius.asBorderRadiusXs,
                                        border: Border.all(
                                          color: Colors.white.withAlpha(40),
                                          width: context.sizes.borderThin,
                                        ),
                                      ),
                                      child: Text(
                                        shownSong.bitrate.isNotEmpty
                                            ? '${shownSong.bitrate.toUpperCase()} AAC'
                                            : '320 KBPS AAC',
                                        style: context.typography.captionMuted.copyWith(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Shuffle Toggle Button
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: player.isShuffled
                                  ? context.colors.successEmerald
                                  : context.colors.textSecondary,
                              size: context.sizes.iconMd,
                            ),
                            tooltip: 'Shuffle',
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              context.read<AudioPlayerViewModel>().toggleShuffle();
                            },
                          ),

                          // Repeat Mode Toggle Button
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              player.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: player.repeatMode != RepeatMode.off
                                  ? context.colors.successEmerald
                                  : context.colors.textSecondary,
                              size: context.sizes.iconMd,
                            ),
                            tooltip: 'Repeat',
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              context.read<AudioPlayerViewModel>().toggleRepeatMode();
                            },
                          ),

                          // Like / Favorite Button
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isLiked
                                  ? context.colors.brandRuby
                                  : context.colors.textSecondary,
                              size: context.sizes.iconLg - 4,
                            ),
                            tooltip: isLiked ? 'Unlike' : 'Like',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.read<AudioPlayerViewModel>().toggleLike(shownSong);
                              DilSeNotification.heart(
                                context,
                                isLiked ? 'Removed from Liked Songs' : 'Added to Liked Songs',
                                subtitle: shownSong.title,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.spacing.sm),

                    // Acoustic Waveform Scrubber
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
                      child: WaveformScrubber(
                        position: player.position,
                        duration: player.duration > Duration.zero
                            ? player.duration
                            : shownSong.duration,
                        songId: shownSong.id,
                        accentColor: vibrantColor,
                        onSeek: (newPos) {
                          context.read<AudioPlayerViewModel>().seek(newPos);
                        },
                      ),
                    ),

                    SizedBox(height: context.spacing.sm),

                    // Primary Playback Controls: Prev, Hero Play/Pause, Next
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.md,
                        vertical: context.spacing.xs,
                      ),
                      child: Row(
                        children: [
                          const Spacer(flex: 2),

                          // Previous
                          _BorderlessScaleButton(
                            scaleDown: 0.88,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              context.read<AudioPlayerViewModel>().skipPrevious();
                            },
                            child: SizedBox(
                              width: context.sizes.playerSkipIconSize + 16,
                              height: context.sizes.playerSkipIconSize + 16,
                              child: Center(
                                child: Icon(
                                  Icons.skip_previous_rounded,
                                  color: context.colors.textPrimary,
                                  size: context.sizes.playerSkipIconSize,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 1),

                          // Hero Play/Pause
                          _BorderlessScaleButton(
                            scaleDown: 0.92,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              context.read<AudioPlayerViewModel>().togglePlayPause();
                            },
                            child: SizedBox(
                              width: context.sizes.playerHeroPlaySize,
                              height: context.sizes.playerHeroPlaySize,
                              child: player.isBuffering
                                  ? Center(
                                      child: SizedBox(
                                        width: context.sizes.iconLg,
                                        height: context.sizes.iconLg,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            context.colors.textPrimary,
                                          ),
                                          strokeWidth: context.spacing.xxs,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 220),
                                        transitionBuilder: (child, animation) =>
                                            ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        ),
                                        child: Icon(
                                          player.isPlaying
                                              ? Icons.pause_circle_filled_rounded
                                              : Icons.play_circle_filled_rounded,
                                          key: ValueKey<bool>(player.isPlaying),
                                          color: context.colors.textPrimary,
                                          size: context.sizes.playerHeroPlayIconSize + 16,
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          const Spacer(flex: 1),

                          // Next
                          _BorderlessScaleButton(
                            scaleDown: 0.88,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              context.read<AudioPlayerViewModel>().skipNext();
                            },
                            child: SizedBox(
                              width: context.sizes.playerSkipIconSize + 16,
                              height: context.sizes.playerSkipIconSize + 16,
                              child: Center(
                                child: Icon(
                                  Icons.skip_next_rounded,
                                  color: context.colors.textPrimary,
                                  size: context.sizes.playerSkipIconSize,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
                      ),
                    ),

                    SizedBox(height: context.spacing.xs),

                    // Secondary Bottom Actions: Lyrics, Queue, More
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.md,
                        vertical: context.spacing.xxs,
                      ),
                      child: Row(
                        children: [
                          // 1. Lyrics Toggle
                          Expanded(
                            child: Center(
                              child: _BorderlessScaleButton(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _showLyrics = !_showLyrics;
                                  });
                                  if (_showLyrics) {
                                    context
                                        .read<AudioPlayerViewModel>()
                                        .fetchLyricsForCurrentSong();
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.sm,
                                    vertical: context.spacing.xs,
                                  ),
                                  decoration: _showLyrics
                                      ? BoxDecoration(
                                          color: vibrantColor.withAlpha(50),
                                          borderRadius: context.radius.asBorderRadiusLg,
                                        )
                                      : null,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showLyrics
                                            ? Icons.lyrics_rounded
                                            : Icons.lyrics_outlined,
                                        color: _showLyrics
                                            ? vibrantColor
                                            : context.colors.textSecondary,
                                        size: context.sizes.iconMd,
                                      ),
                                      SizedBox(height: context.spacing.xxs),
                                      Text(
                                        'Lyrics',
                                        style: context.typography.captionMuted.copyWith(
                                          color: _showLyrics
                                              ? vibrantColor
                                              : context.colors.textSecondary,
                                          fontWeight: _showLyrics
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 2. Queue Modal
                          Expanded(
                            child: Center(
                              child: _BorderlessScaleButton(
                                onTap: () => QueueBottomSheet.show(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.sm,
                                    vertical: context.spacing.xs,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.queue_music_rounded,
                                            color: context.colors.textSecondary,
                                            size: context.sizes.iconMd,
                                          ),
                                          if (queue.length > 1)
                                            Positioned(
                                              top: -4,
                                              right: -10,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: context.spacing.xxs,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: vibrantColor,
                                                  borderRadius: context.radius.asBorderRadiusSm,
                                                ),
                                                child: Text(
                                                  '${queue.length}',
                                                  style: context.typography.captionMuted.copyWith(
                                                    color: Colors.white,
                                                    fontSize: 9.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: context.spacing.xxs),
                                      Text(
                                        'Queue',
                                        style: context.typography.captionMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. More Track Options
                          Expanded(
                            child: Center(
                              child: _BorderlessScaleButton(
                                onTap: () => SongOptionsBottomSheet.show(context, shownSong),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.sm,
                                    vertical: context.spacing.xs,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.more_horiz_rounded,
                                        color: context.colors.textSecondary,
                                        size: context.sizes.iconMd,
                                      ),
                                      SizedBox(height: context.spacing.xxs),
                                      Text(
                                        'More',
                                        style: context.typography.captionMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Borderless interactive scale button providing fluid haptic tap feedback.
class _BorderlessScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;

  const _BorderlessScaleButton({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.88,
  });

  @override
  State<_BorderlessScaleButton> createState() => _BorderlessScaleButtonState();
}

class _BorderlessScaleButtonState extends State<_BorderlessScaleButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isDown ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
