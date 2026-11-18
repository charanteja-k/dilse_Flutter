import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/services/notification_permission_service.dart';
import '../../../core/widgets/dilse_notification.dart';
import '../../../data/models/song_model.dart';
import '../../app_update/viewmodels/update_viewmodel.dart';
import '../../app_update/views/update_top_bar_button.dart';
import '../../audio_player/viewmodels/audio_player_viewmodel.dart';
import '../../audio_player/views/floating_vinyl_disc.dart';
import '../../audio_player/views/mini_player.dart';
import '../../downloads/views/downloads_screen.dart';
import '../../library/views/library_screen.dart';
import '../../search/views/search_screen.dart';
import '../viewmodels/home_viewmodel.dart';
import 'floating_nav_dock.dart';

/// Full DilSe Home Feed presentation recreated faithfully from legacy music_app.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 2: Context-Exposed Design Tokens (strictly zero magic numbers/raw colors).
/// - Invariant 3: Strict MVVM (View contains presentation only, zero business logic).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  bool _isNavVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadHomeFeed();
      context.read<UpdateViewModel>().initialize();
      NotificationPermissionService.promptIfNeeded(context);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING,';
    if (hour < 17) return 'GOOD AFTERNOON,';
    return 'GOOD EVENING,';
  }

  Color _getQuickAccessColor(BuildContext context, String iconKey) {
    switch (iconKey) {
      case 'daily_mix_1':
        return context.colors.mixBlue;
      case 'liked_songs':
        return context.colors.mixPurple;
      case 'daily_mix_2':
        return context.colors.mixTeal;
      case 'nostalgic':
        return context.colors.mixAmber;
      case 'top_charts':
        return context.colors.mixGreen;
      case 'trending':
        return context.colors.mixCrimson;
      default:
        return context.colors.cardDarkSurface;
    }
  }

  IconData _getQuickAccessIcon(String iconKey) {
    switch (iconKey) {
      case 'daily_mix_1':
        return Icons.shuffle_rounded;
      case 'liked_songs':
        return Icons.favorite_rounded;
      case 'daily_mix_2':
        return Icons.graphic_eq_rounded;
      case 'nostalgic':
        return Icons.auto_awesome_rounded;
      case 'top_charts':
        return Icons.trending_up_rounded;
      case 'trending':
        return Icons.whatshot_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeVm = context.watch<HomeViewModel>();
    final audioPlayerVm = context.watch<AudioPlayerViewModel>();
    final currentSong = audioPlayerVm.currentSong;
    final isPlaying = audioPlayerVm.isPlaying;
    final hasActivePlayback = currentSong != null;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    final isDockVisible = _isNavVisible && !isKeyboardOpen;

    return Scaffold(
      backgroundColor: context.colors.oledBackground,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification is UserScrollNotification) {
              if (notification.direction == ScrollDirection.reverse) {
                // User scrolls down the content -> slide down and hide nav bar
                if (_isNavVisible) {
                  setState(() => _isNavVisible = false);
                }
              } else if (notification.direction == ScrollDirection.forward) {
                // User swipes up / scrolls back up -> slide up and reveal nav bar
                if (!_isNavVisible) {
                  setState(() => _isNavVisible = true);
                }
              }
            }

            // Always reveal nav bar if at the very top or bottom edge of any list
            if ((notification.metrics.pixels <= 20 ||
                    (notification.metrics.maxScrollExtent > 100 &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 20)) &&
                !_isNavVisible) {
              setState(() => _isNavVisible = true);
            }
          }
          return false;
        },
        child: Stack(
          children: [
            // Main Body: Home Feed (0), Search (1), Library (2), Downloads (3)
            if (_selectedNavIndex == 1)
              SearchScreen(
                onBackToHome: () => setState(() {
                  _selectedNavIndex = 0;
                  _isNavVisible = true;
                }),
              )
            else if (_selectedNavIndex == 2)
              const LibraryScreen()
            else if (_selectedNavIndex == 3)
              const DownloadsScreen()
            else
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildTopBar(context, homeVm),
                    Expanded(
                      child: homeVm.isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: context.colors.brandRuby,
                              ),
                            )
                          : homeVm.errorMessage != null
                          ? _buildErrorView(context, homeVm)
                          : RefreshIndicator(
                              color: context.colors.brandRuby,
                              backgroundColor: context.colors.cardDarkSurface,
                              onRefresh: () => homeVm.loadHomeFeed(),
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  top: context.spacing.xs,
                                  bottom:
                                      context.sizes.miniPlayerHeight +
                                      context.sizes.navDockHeight +
                                      context.spacing.xl,
                                ),
                                children: [
                                  // 1. Smart Playback Quick Resume Banner (when no active track is loaded)
                                  if (!hasActivePlayback &&
                                      homeVm.quickResumeSong != null)
                                    _buildQuickResumeBanner(
                                      context,
                                      homeVm.quickResumeSong!,
                                      homeVm,
                                    ),

                                  // 2. 2x3 Minimalist Quick Access Grid (Daily Mix 1, Liked Songs, Mix 2, Nostalgic, Charts, Trending)
                                  if (homeVm.quickAccessItems.isNotEmpty)
                                    _buildQuickAccessGrid(context, homeVm),

                                  SizedBox(height: context.spacing.sm),

                                  // 3. Horizontal Mood & Activity Filter Chips
                                  _buildMoodChips(context, homeVm),

                                  SizedBox(height: context.spacing.md),

                                  // 4. Dedicated Vibe Radio Hub vs Standard Home Feed Shelves
                                  if (homeVm.selectedMoodIndex != 0)
                                    _buildVibeRadioView(context, homeVm)
                                  else ...[
                                    // Circadian Time-of-Day Contextual Shelf
                                    if (homeVm.circadianMix.isNotEmpty) ...[
                                      _buildSectionHeader(
                                        context,
                                        '${homeVm.circadianContext.emoji} ${homeVm.circadianContext.title.toUpperCase()}',
                                        homeVm.circadianContext.subtitle,
                                      ),
                                      SizedBox(height: context.spacing.sm),
                                      _buildHorizontalSongShelf(
                                        context,
                                        homeVm.circadianMix,
                                      ),
                                      SizedBox(height: context.spacing.lg),
                                    ],

                                    // TOP CHARTS: INDIA
                                    if (homeVm.topChartsIndia.isNotEmpty) ...[
                                      _buildSectionHeader(
                                        context,
                                        'TOP CHARTS: INDIA',
                                        'Updated Daily • ${homeVm.selectedLanguage}',
                                      ),
                                      SizedBox(height: context.spacing.sm),
                                      _buildHorizontalSongShelf(
                                        context,
                                        homeVm.topChartsIndia,
                                      ),
                                      SizedBox(height: context.spacing.lg),
                                    ],

                                    // BLOCKBUSTER SOUNDTRACKS & ALBUMS
                                    if (homeVm
                                        .blockbusterAlbums
                                        .isNotEmpty) ...[
                                      _buildSectionHeader(
                                        context,
                                        'BLOCKBUSTER SOUNDTRACKS & ALBUMS',
                                        'Original Soundtracks & Compilations',
                                      ),
                                      SizedBox(height: context.spacing.sm),
                                      _buildHorizontalSongShelf(
                                        context,
                                        homeVm.blockbusterAlbums,
                                      ),
                                      SizedBox(height: context.spacing.lg),
                                    ],

                                    // MADE FOR YOU
                                    if (homeVm.madeForYou.isNotEmpty) ...[
                                      _buildSectionHeader(
                                        context,
                                        'MADE FOR YOU',
                                        'Curated for your taste',
                                      ),
                                      SizedBox(height: context.spacing.sm),
                                      _buildHorizontalSongShelf(
                                        context,
                                        homeVm.madeForYou,
                                      ),
                                      SizedBox(height: context.spacing.lg),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),

            // Floating MiniPlayer & Matte Navigation Dock stacked at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                offset: isDockVisible ? Offset.zero : const Offset(0, 1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isDockVisible ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !isDockVisible,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MiniPlayer(),
                        FloatingNavDock(
                          selectedIndex: _selectedNavIndex,
                          onTabSelected: (index) {
                            setState(() {
                              _selectedNavIndex = index;
                              _isNavVisible = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Spinning Vinyl CD Player (Appears when scrolled down and playback is active, draggable between left & right)
            if (hasActivePlayback)
              FloatingVinylDisc(
                isVisible: !isDockVisible,
                song: currentSong,
                isPlaying: isPlaying,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, HomeViewModel homeVm) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting & User Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting(), style: context.typography.eyebrow),
                SizedBox(height: context.spacing.xxs),
                Text(
                  'Charan',
                  style: context.typography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Language Selector Pill, Update & Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                color: context.colors.cardDarkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.asBorderRadiusMd,
                  side: BorderSide(
                    color: context.colors.solidMatteBorder,
                    width: context.sizes.borderThin,
                  ),
                ),
                onSelected: (lang) => homeVm.selectLanguage(lang),
                itemBuilder: (context) => homeVm.availableLanguages
                    .map(
                      (lang) => PopupMenuItem(
                        value: lang,
                        child: Text(
                          lang,
                          style: context.typography.titleMedium.copyWith(
                            color: lang == homeVm.selectedLanguage
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            fontWeight: lang == homeVm.selectedLanguage
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    )
                    .toList(),
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
                    children: [
                      Text(
                        homeVm.selectedLanguage,
                        style: context.typography.titleMedium,
                      ),
                      SizedBox(width: context.spacing.xxs),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconSm,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xs),
              const UpdateTopBarButton(),
              SizedBox(width: context.spacing.xs),
              Container(
                width: context.sizes.avatarSm,
                height: context.sizes.avatarSm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.cardDarkSurface,
                  border: Border.all(
                    color: context.colors.solidMatteBorder,
                    width: context.sizes.borderThin,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: context.colors.textPrimary,
                  size: context.sizes.iconSm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickResumeBanner(
    BuildContext context,
    SongModel song,
    HomeViewModel homeVm,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
      padding: EdgeInsets.all(context.spacing.sm),
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
          // Album Artwork
          ClipRRect(
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
                        Icons.music_note,
                        color: context.colors.textSecondary,
                        size: context.sizes.iconMd,
                      ),
                    )
                  : Icon(
                      Icons.music_note,
                      color: context.colors.textSecondary,
                      size: context.sizes.iconMd,
                    ),
            ),
          ),
          SizedBox(width: context.spacing.sm),

          // Title & Artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: context.sizes.iconSm,
                      color: context.colors.textSecondary,
                    ),
                    SizedBox(width: context.spacing.xxs),
                    Text('JUMP BACK IN', style: context.typography.eyebrow),
                  ],
                ),
                SizedBox(height: context.spacing.xxs),
                Text(
                  song.title,
                  style: context.typography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.artist,
                  style: context.typography.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Resume Play Button
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              context.read<AudioPlayerViewModel>().playSong(song);
            },
            icon: Icon(
              Icons.play_circle_fill_rounded,
              color: context.colors.textPrimary,
              size: context.sizes.iconLg,
            ),
          ),

          // Dismiss Button
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              homeVm.dismissQuickResume();
            },
            icon: Icon(
              Icons.close_rounded,
              color: context.colors.textSecondary,
              size: context.sizes.iconSm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, HomeViewModel homeVm) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: homeVm.quickAccessItems.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: context.spacing.xs,
          crossAxisSpacing: context.spacing.xs,
          mainAxisExtent: context.sizes.quickAccessTileHeight,
        ),
        itemBuilder: (context, index) {
          final item = homeVm.quickAccessItems[index];
          final solidColor = _getQuickAccessColor(context, item.iconKey);
          final iconData = _getQuickAccessIcon(item.iconKey);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (item.songs.isNotEmpty) {
                context.read<AudioPlayerViewModel>().playFromQueue(item.songs);
              } else {
                DilSeNotification.info(
                  context,
                  item.title,
                  subtitle: 'Will sync with your library soon.',
                );
              }
            },
            child: Container(
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
                  // Icon / Thumbnail block
                  Container(
                    width: context.sizes.thumbnailMd,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: solidColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(context.radius.md),
                        bottomLeft: Radius.circular(context.radius.md),
                      ),
                    ),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(context.radius.md),
                              bottomLeft: Radius.circular(context.radius.md),
                            ),
                            child: Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    iconData,
                                    color: context.colors.textPrimary,
                                    size: context.sizes.iconSm,
                                  ),
                            ),
                          )
                        : Icon(
                            iconData,
                            color: context.colors.textPrimary,
                            size: context.sizes.iconSm,
                          ),
                  ),
                  SizedBox(width: context.spacing.xs),

                  // Title & Subtitle
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.spacing.xxs,
                        horizontal: context.spacing.xxs,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: context.typography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.subtitle,
                            style: context.typography.captionMuted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoodChips(BuildContext context, HomeViewModel homeVm) {
    return SizedBox(
      height: context.sizes.chipHeight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: homeVm.availableMoods.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.spacing.xs),
        itemBuilder: (context, index) {
          final mood = homeVm.availableMoods[index];
          final isSelected = index == homeVm.selectedMoodIndex;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              homeVm.selectMood(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.md,
                vertical: context.spacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.brandRuby
                    : context.colors.cardDarkSurface,
                borderRadius: context.radius.asBorderRadiusFull,
                border: Border.all(
                  color: isSelected
                      ? context.colors.brandRuby
                      : context.colors.solidMatteBorder,
                  width: context.sizes.borderThin,
                ),
              ),
              child: Center(
                child: Text(
                  mood,
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

  Widget _buildVibeRadioView(BuildContext context, HomeViewModel homeVm) {
    final activeMood = homeVm.activeMoodCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vibe Hero Card
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          child: Container(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.sm,
                        vertical: context.spacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.brandRuby,
                        borderRadius: context.radius.asBorderRadiusFull,
                      ),
                      child: Text(
                        'VIBE RADIO',
                        style: context.typography.eyebrow.copyWith(
                          color: context.colors.oledBackground,
                        ),
                      ),
                    ),
                    if (!homeVm.isLoadingVibe &&
                        homeVm.vibeRadioTracks.isNotEmpty)
                      Text(
                        '${homeVm.vibeRadioTracks.length} tracks',
                        style: context.typography.captionMuted,
                      ),
                  ],
                ),
                SizedBox(height: context.spacing.sm),
                Text(
                  activeMood.label,
                  style: context.typography.headlineMedium,
                ),
                SizedBox(height: context.spacing.xxs),
                Text(
                  activeMood.description,
                  style: context.typography.bodyMedium,
                ),
                if (!homeVm.isLoadingVibe &&
                    homeVm.vibeRadioTracks.isNotEmpty) ...[
                  SizedBox(height: context.spacing.md),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          size: context.sizes.iconMd,
                          color: context.colors.oledBackground,
                        ),
                        label: Text(
                          'Play Vibe Radio',
                          style: context.typography.titleMedium.copyWith(
                            color: context.colors.oledBackground,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.textPrimary,
                          foregroundColor: context.colors.oledBackground,
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.md,
                            vertical: context.spacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: context.radius.asBorderRadiusMd,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.read<AudioPlayerViewModel>().playFromQueue(
                            homeVm.vibeRadioTracks,
                            initialIndex: 0,
                          );
                        },
                      ),
                      SizedBox(width: context.spacing.sm),
                      OutlinedButton.icon(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: context.sizes.iconSm,
                        ),
                        label: Text(
                          'Shuffle',
                          style: context.typography.titleMedium,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.textPrimary,
                          side: BorderSide(
                            color: context.colors.solidMatteBorder,
                            width: context.sizes.borderThin,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.md,
                            vertical: context.spacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: context.radius.asBorderRadiusMd,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final shuffled = homeVm.buildShuffledVibeQueue();
                          context.read<AudioPlayerViewModel>().playFromQueue(
                            shuffled,
                            initialIndex: 0,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: context.spacing.lg),

        if (homeVm.isLoadingVibe)
          Center(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.lg),
              child: CircularProgressIndicator(color: context.colors.brandRuby),
            ),
          )
        else if (homeVm.vibeRadioTracks.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: context.sizes.iconLg,
                    color: context.colors.textSecondary,
                  ),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    'No tracks found for ${activeMood.label}',
                    style: context.typography.bodyLarge,
                  ),
                  SizedBox(height: context.spacing.xs),
                  TextButton(
                    onPressed: () => homeVm.selectMood(0),
                    child: Text(
                      'Return to All Hits',
                      style: context.typography.titleMedium.copyWith(
                        color: context.colors.brandRuby,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _buildSectionHeader(
            context,
            'HIGHLIGHTS',
            'Top Picks for ${activeMood.label}',
          ),
          SizedBox(height: context.spacing.sm),
          _buildHorizontalSongShelf(context, homeVm.vibeRadioTracks),
          SizedBox(height: context.spacing.lg),
          _buildSectionHeader(
            context,
            'VIBE TRACKLIST',
            '${homeVm.vibeRadioTracks.length} Songs',
          ),
          SizedBox(height: context.spacing.xs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: homeVm.vibeRadioTracks.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: context.spacing.xs),
              itemBuilder: (context, index) {
                final song = homeVm.vibeRadioTracks[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: context.radius.asBorderRadiusSm,
                    child: Container(
                      width: context.sizes.thumbnailMd,
                      height: context.sizes.thumbnailMd,
                      color: context.colors.cardDarkSurface,
                      child: song.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              song.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.music_note,
                                    color: context.colors.textSecondary,
                                  ),
                            )
                          : Icon(
                              Icons.music_note,
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
                    song.artist,
                    style: context.typography.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: context.colors.textSecondary,
                      size: context.sizes.iconMd,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.read<AudioPlayerViewModel>().playFromQueue(
                        homeVm.vibeRadioTracks,
                        initialIndex: index,
                      );
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<AudioPlayerViewModel>().playFromQueue(
                      homeVm.vibeRadioTracks,
                      initialIndex: index,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.typography.titleLarge),
          SizedBox(height: context.spacing.xxs),
          Text(subtitle, style: context.typography.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildHorizontalSongShelf(
    BuildContext context,
    List<SongModel> tracks,
  ) {
    return SizedBox(
      height: context.sizes.trackShelfHeight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tracks.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: context.spacing.md),
        itemBuilder: (context, index) {
          final song = tracks[index];

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<AudioPlayerViewModel>().playFromQueue(
                tracks,
                initialIndex: index,
              );
            },
            child: SizedBox(
              width: context.sizes.songCardSize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square Artwork
                  ClipRRect(
                    borderRadius: context.radius.asBorderRadiusMd,
                    child: Container(
                      width: context.sizes.songCardSize,
                      height: context.sizes.songCardSize,
                      color: context.colors.cardDarkSurface,
                      child: song.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              song.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.music_note,
                                    color: context.colors.textSecondary,
                                    size: context.sizes.iconLg,
                                  ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: context.colors.textSecondary,
                              size: context.sizes.iconLg,
                            ),
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),

                  // Title
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleMedium,
                  ),
                  SizedBox(height: context.spacing.xxs),

                  // Artist
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, HomeViewModel homeVm) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: context.colors.warningAmber,
              size: context.sizes.iconLg,
            ),
            SizedBox(height: context.spacing.md),
            Text(
              'Unable to load feed',
              style: context.typography.headlineMedium,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              homeVm.errorMessage ?? 'Please check your connection and retry.',
              textAlign: TextAlign.center,
              style: context.typography.bodyMedium,
            ),
            SizedBox(height: context.spacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brandRuby,
                foregroundColor: context.colors.oledBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: context.radius.asBorderRadiusCard,
                ),
              ),
              onPressed: () => homeVm.loadHomeFeed(),
              child: Text(
                'Retry',
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
