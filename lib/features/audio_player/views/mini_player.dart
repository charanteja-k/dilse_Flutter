import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../viewmodels/audio_player_viewmodel.dart';
import 'player_screen.dart';

/// MiniPlayer widget that docks at the bottom of the screen.
/// Follows AGENTS.md Invariant 2 (Zero magic numbers, context-exposed tokens only)
/// and Invariant 3 (Strict MVVM, pure presentation).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerViewModel>();
    final song = player.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final durationMs = player.duration.inMilliseconds;
    final positionMs = player.position.inMilliseconds;
    final progress = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      height: context.sizes.miniPlayerHeight,
      decoration: BoxDecoration(
        color: context.colors.floatingDockSurface,
        borderRadius: context.radius.asBorderRadiusCard,
        border: Border.all(
          color: context.colors.solidMatteBorder,
          width: context.sizes.borderThin,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.oledBackground.withAlpha(120),
            blurRadius: context.spacing.sm,
            offset: Offset(0, context.spacing.xs),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.radius.asBorderRadiusCard,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                child: Row(
                  children: [
                    // Tappable Area: Artwork + Song Title & Artist
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openFullPlayer(context),
                        child: Row(
                          children: [
                            // Artwork
                            ClipRRect(
                              borderRadius: context.radius.asBorderRadiusSm,
                              child: Container(
                                width: context.sizes.avatarMd,
                                height: context.sizes.avatarMd,
                                color: context.colors.cardDarkSurface,
                                child: song.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        song.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.music_note,
                                                  color: context
                                                      .colors
                                                      .textSecondary,
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

                            // Song Title & Artist
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.typography.titleMedium,
                                  ),
                                  SizedBox(height: context.spacing.xxs),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.typography.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Skip Previous
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: context.colors.textPrimary,
                        size: context.sizes.iconMd,
                      ),
                      onPressed: () =>
                          context.read<AudioPlayerViewModel>().skipPrevious(),
                    ),

                    // Play / Pause / Buffering Indicator
                    if (player.isBuffering)
                      Padding(
                        padding: EdgeInsets.all(context.spacing.xs),
                        child: SizedBox(
                          width: context.sizes.iconMd,
                          height: context.sizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: context.spacing.xxs,
                            color: context.colors.brandRuby,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: context.colors.brandRuby,
                          size: context.sizes.iconLg,
                        ),
                        onPressed: () => context
                            .read<AudioPlayerViewModel>()
                            .togglePlayPause(),
                      ),

                    // Skip Next
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: context.colors.textPrimary,
                        size: context.sizes.iconMd,
                      ),
                      onPressed: () =>
                          context.read<AudioPlayerViewModel>().skipNext(),
                    ),
                  ],
                ),
              ),
            ),

            // Micro Linear Progress Bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colors.cardDarkSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.colors.brandRuby,
              ),
              minHeight: context.spacing.xxs,
            ),
          ],
        ),
      ),
    );
  }
}
