import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../viewmodels/audio_player_viewmodel.dart';

/// Modal bottom sheet displaying the current playing queue with drag-to-reorder,
/// swipe-to-dismiss, and one-tap track jumping.
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

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerViewModel>();
    final queue = player.queue;
    final currentSong = player.currentSong;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: context.colors.floatingDockSurface.withAlpha(248),
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
              vertical: context.spacing.sm,
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        queue.length > 1
                            ? 'Swipe left to remove • Drag ☰ to reorder'
                            : 'Active playback session',
                        style: context.typography.captionMuted,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconLg,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),

          Divider(
            color: context.colors.solidMatteBorder,
            height: context.sizes.borderThin,
          ),

          // Queue List
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
                      final isCurrent = currentSong != null && track.id == currentSong.id;

                      return Dismissible(
                        key: ValueKey('queue_track_${track.id}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: context.spacing.md),
                          color: context.colors.errorCrimson.withAlpha(200),
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
                                    color: context.colors.brandRuby.withAlpha(120),
                                    width: context.sizes.borderThin,
                                  )
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: context.spacing.sm,
                              vertical: context.spacing.xxs,
                            ),
                            leading: ClipRRect(
                              borderRadius: context.radius.asBorderRadiusSm,
                              child: Container(
                                width: context.sizes.avatarMd,
                                height: context.sizes.avatarMd,
                                color: context.colors.surfaceContainer,
                                child: track.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        track.thumbnailUrl,
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
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.titleMedium.copyWith(
                                color: isCurrent
                                    ? context.colors.brandRuby
                                    : context.colors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.bodyMedium,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent)
                                  Icon(
                                    player.isPlaying
                                        ? Icons.equalizer_rounded
                                        : Icons.pause_rounded,
                                    color: context.colors.brandRuby,
                                    size: context.sizes.iconMd,
                                  ),
                                SizedBox(width: context.spacing.xs),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: context.colors.textSecondary,
                                    size: context.sizes.iconMd,
                                  ),
                                ),
                              ],
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
}
