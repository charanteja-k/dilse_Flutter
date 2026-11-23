import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../viewmodels/audio_player_viewmodel.dart';

/// Modal bottom sheet displaying the current playing queue with a pinned Now Playing
/// master card, Queue Mode tuning dock, contextual taste badges, and reorderable list.
/// Follows AGENTS.md Invariants: zero singletons, design tokens only, strict monochrome.
class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const QueueBottomSheet(),
    );
  }

  String _formatTotalDuration(List<Duration> durations) {
    final totalSeconds = durations.fold<int>(0, (sum, d) => sum + d.inSeconds);
    if (totalSeconds == 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  String _badgeLabel(QueueTrackBadge badge) {
    switch (badge) {
      case QueueTrackBadge.topArtist:
        return 'Top Artist';
      case QueueTrackBadge.inLibrary:
        return 'In Library';
      case QueueTrackBadge.discovery:
        return 'Discovery';
      case QueueTrackBadge.similarVibe:
        return 'Similar Vibe';
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerViewModel>();
    final queue = player.queue;
    final currentSong = player.currentSong;
    final currentIndex = player.currentIndex;
    final queueMode = player.queueMode;

    // Upcoming queue calculation
    final upcomingTracks = currentIndex >= 0 && currentIndex + 1 < queue.length
        ? queue.sublist(currentIndex + 1)
        : <dynamic>[];
    final totalUpcomingDuration = _formatTotalDuration(
      upcomingTracks.map((t) => t.duration as Duration).toList(),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.colors.oledBackground,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radius.sheet),
        ),
        border: Border.all(
          color: context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: context.spacing.sm),

          // Drag handle pill
          Container(
            width: context.sizes.heroCardWidth * 0.15,
            height: context.spacing.xxs,
            decoration: BoxDecoration(
              color: context.colors.textSecondary.withAlpha(80),
              borderRadius: context.radius.asBorderRadiusFull,
            ),
          ),

          // Header Row
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.md,
              vertical: context.spacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Playing Queue',
                            style: context.typography.headlineMedium,
                          ),
                          SizedBox(width: context.spacing.xs),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacing.xs,
                              vertical: context.spacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.cardDarkSurface,
                              borderRadius: context.radius.asBorderRadiusSm,
                              border: Border.all(
                                color: context.colors.solidMatteBorder,
                                width: context.sizes.borderThin,
                              ),
                            ),
                            child: Text(
                              '${queue.length}',
                              style: context.typography.captionMuted.copyWith(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        'Playing from Radio',
                        style: context.typography.captionMuted.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action: Save as Playlist
                IconButton(
                  tooltip: 'Save as Playlist',
                  icon: Icon(
                    Icons.playlist_add_rounded,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconMd,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Queue saved to your playlists',
                          style: context.typography.bodyMedium.copyWith(
                            color: context.colors.oledBackground,
                          ),
                        ),
                        backgroundColor: context.colors.textPrimary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                // Action: Close Sheet
                IconButton(
                  tooltip: 'Close Queue',
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconMd,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),

          // Pinned Master Now Playing Card
          if (currentSong != null)
            Container(
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
                  ClipRRect(
                    borderRadius: context.radius.asBorderRadiusSm,
                    child: Container(
                      width: context.sizes.avatarLg,
                      height: context.sizes.avatarLg,
                      color: context.colors.floatingDockSurface,
                      child: currentSong.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              currentSong.thumbnailUrl,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOW PLAYING • 320 KBPS',
                          style: context.typography.captionMuted.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: context.spacing.xxs),
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.titleMedium.copyWith(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: context.spacing.xxs),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.bodyMedium.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    player.isPlaying
                        ? Icons.equalizer_rounded
                        : Icons.pause_rounded,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconMd,
                  ),
                ],
              ),
            ),

          // Queue Mode Tuning Dock Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.md,
              vertical: context.spacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QUEUE MODE',
                  style: context.typography.captionMuted.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<AudioPlayerViewModel>().clearUpcomingQueue();
                  },
                  child: Text(
                    'Clear Queue',
                    style: context.typography.captionMuted.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Tuning Pills
          SizedBox(
            height: context.sizes.iconLg * 1.3,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              children: [
                _buildModePill(
                  context: context,
                  label: 'Blend Languages',
                  icon: Icons.language_rounded,
                  mode: QueueMode.blend,
                  activeMode: queueMode,
                ),
                SizedBox(width: context.spacing.xs),
                _buildModePill(
                  context: context,
                  label: 'Discover',
                  icon: Icons.explore_rounded,
                  mode: QueueMode.discover,
                  activeMode: queueMode,
                ),
                SizedBox(width: context.spacing.xs),
                _buildModePill(
                  context: context,
                  label: 'Familiar',
                  icon: Icons.favorite_rounded,
                  mode: QueueMode.familiar,
                  activeMode: queueMode,
                ),
                SizedBox(width: context.spacing.xs),
                _buildModePill(
                  context: context,
                  label: 'Single Language',
                  icon: Icons.lock_outline_rounded,
                  mode: QueueMode.singleLanguage,
                  activeMode: queueMode,
                ),
              ],
            ),
          ),

          SizedBox(height: context.spacing.xs),

          // Up Next Section Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.md,
              vertical: context.spacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  'UP NEXT',
                  style: context.typography.captionMuted.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: context.spacing.xs),
                Text(
                  '•',
                  style: context.typography.captionMuted.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(width: context.spacing.xs),
                Text(
                  '${queue.length} tracks • $totalUpcomingDuration',
                  style: context.typography.captionMuted.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: context.colors.solidMatteBorder,
            height: context.sizes.borderThin,
          ),

          // Scrollable Reorderable Queue List
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Text(
                      'Queue is empty',
                      style: context.typography.bodyLarge,
                    ),
                  )
                : ReorderableListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      vertical: context.spacing.xs,
                      horizontal: context.spacing.xs,
                    ),
                    itemCount: queue.length,
                    onReorderItem: (oldIndex, newIndex) {
                      HapticFeedback.selectionClick();
                      context.read<AudioPlayerViewModel>().reorderQueue(
                            oldIndex,
                            oldIndex < newIndex ? newIndex + 1 : newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isCurrent = currentIndex == index;
                      final badge = player.getTrackBadge(track.id);

                      return Dismissible(
                        key: ValueKey('queue_track_${track.id}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: context.spacing.md),
                          color: context.colors.cardDarkSurface,
                          child: Icon(
                            Icons.delete_sweep_rounded,
                            color: context.colors.textPrimary,
                            size: context.sizes.iconMd,
                          ),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.lightImpact();
                          context.read<AudioPlayerViewModel>().removeQueueTrack(index);
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: context.spacing.xs,
                            vertical: context.spacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? context.colors.cardDarkSurface
                                : Colors.transparent,
                            borderRadius: context.radius.asBorderRadiusMd,
                            border: isCurrent
                                ? Border.all(
                                    color: context.colors.solidMatteBorder,
                                    width: context.sizes.borderThin,
                                  )
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: context.spacing.sm,
                              vertical: context.spacing.xxs,
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: context.sizes.avatarSm * 0.7,
                                  child: Text(
                                    (index + 1).toString().padLeft(2, '0'),
                                    style: context.typography.captionMuted.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.spacing.xs),
                                ClipRRect(
                                  borderRadius: context.radius.asBorderRadiusSm,
                                  child: Container(
                                    width: context.sizes.avatarMd,
                                    height: context.sizes.avatarMd,
                                    color: context.colors.floatingDockSurface,
                                    child: track.thumbnailUrl.isNotEmpty
                                        ? Image.network(
                                            track.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Icon(
                                              Icons.music_note,
                                              color: context.colors.textSecondary,
                                              size: context.sizes.iconSm,
                                            ),
                                          )
                                        : Icon(
                                            Icons.music_note,
                                            color: context.colors.textSecondary,
                                            size: context.sizes.iconSm,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.typography.titleMedium.copyWith(
                                      color: context.colors.textPrimary,
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.spacing.xs),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.spacing.xs * 0.8,
                                    vertical: context.spacing.xxs * 0.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.cardDarkSurface,
                                    borderRadius: context.radius.asBorderRadiusSm,
                                    border: Border.all(
                                      color: context.colors.solidMatteBorder,
                                      width: context.sizes.borderThin,
                                    ),
                                  ),
                                  child: Text(
                                    _badgeLabel(badge),
                                    style: context.typography.captionMuted.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: badge == QueueTrackBadge.topArtist || badge == QueueTrackBadge.inLibrary
                                          ? context.colors.textPrimary
                                          : context.colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.bodyMedium.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: EdgeInsets.all(context.spacing.xs),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: context.colors.textSecondary,
                                  size: context.sizes.iconMd,
                                ),
                              ),
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.read<AudioPlayerViewModel>().skipToIndex(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill({
    required BuildContext context,
    required String label,
    required IconData icon,
    required QueueMode mode,
    required QueueMode activeMode,
  }) {
    final isActive = mode == activeMode;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<AudioPlayerViewModel>().setQueueMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? context.colors.textPrimary
              : context.colors.cardDarkSurface,
          borderRadius: context.radius.asBorderRadiusFull,
          border: Border.all(
            color: isActive
                ? context.colors.textPrimary
                : context.colors.solidMatteBorder,
            width: context.sizes.borderThin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.sizes.iconSm,
              color: isActive
                  ? context.colors.oledBackground
                  : context.colors.textSecondary,
            ),
            SizedBox(width: context.spacing.xxs),
            Text(
              label,
              style: context.typography.captionMuted.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive
                    ? context.colors.oledBackground
                    : context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
