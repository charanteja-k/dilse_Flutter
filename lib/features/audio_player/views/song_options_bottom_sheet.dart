import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/theme_viewmodel.dart';
import '../../../data/models/song_model.dart';
import '../viewmodels/audio_player_viewmodel.dart';
import 'equalizer_bottom_sheet.dart';

/// Modal sheet exposing track specs, artwork style toggles, and metadata actions.
class SongOptionsBottomSheet extends StatelessWidget {
  final SongModel song;

  const SongOptionsBottomSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, SongModel song) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SongOptionsBottomSheet(song: song),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerViewModel>();
    final isLiked = player.isLiked(song.id);
    final isVinyl = player.artworkStyle == ArtworkStyle.vinyl;

    return Container(
      padding: EdgeInsets.only(
        top: context.spacing.sm,
        bottom: context.spacing.xl,
      ),
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            Container(
              width: context.sizes.heroCardWidth * 0.15,
              height: context.spacing.xxs,
              decoration: BoxDecoration(
                color: context.colors.textSecondary.withAlpha(80),
                borderRadius: context.radius.asBorderRadiusFull,
              ),
            ),
            SizedBox(height: context.spacing.md),

            // Track Header Card
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: context.radius.asBorderRadiusMd,
                    child: Container(
                      width: context.sizes.avatarLg,
                      height: context.sizes.avatarLg,
                      color: context.colors.cardDarkSurface,
                      child: song.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              song.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
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
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.titleLarge,
                        ),
                        SizedBox(height: context.spacing.xxs),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.bodyMedium,
                        ),
                        SizedBox(height: context.spacing.xxs),
                        Text(
                          '${song.album} • ${_formatDuration(song.duration)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.captionMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.spacing.md),

            // Specs Banner
            Container(
              margin: EdgeInsets.symmetric(horizontal: context.spacing.md),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.md,
                vertical: context.spacing.sm,
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SpecPill(
                    icon: Icons.high_quality_rounded,
                    label: 'Bitrate',
                    value: song.bitrate.isNotEmpty ? song.bitrate : '320kbps',
                  ),
                  _SpecPill(
                    icon: Icons.multitrack_audio_rounded,
                    label: 'Codec',
                    value: 'AAC / MP4',
                  ),
                  _SpecPill(
                    icon: Icons.cloud_done_rounded,
                    label: 'CDN Node',
                    value: 'Cloudflare V8',
                  ),
                ],
              ),
            ),
            SizedBox(height: context.spacing.md),

            // Action: Like / Unlike
            ListTile(
              leading: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? context.colors.textPrimary : context.colors.textSecondary,
                size: context.sizes.iconMd,
              ),
              title: Text(
                isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                style: context.typography.titleMedium,
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AudioPlayerViewModel>().toggleLike(song);
              },
            ),

            // Action: Toggle UI Theme (Dark Mode <-> Light Mode)
            Consumer<ThemeViewModel>(
              builder: (context, themeVm, _) {
                final isDark = themeVm.isDarkMode;
                return ListTile(
                  leading: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: context.colors.textPrimary,
                    size: context.sizes.iconMd,
                  ),
                  title: Text(
                    isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                    style: context.typography.titleMedium,
                  ),
                  subtitle: Text(
                    isDark ? 'Current: OLED Dark Mode' : 'Current: Clean Light Mode',
                    style: context.typography.captionMuted,
                  ),
                  trailing: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        themeVm.toggleTheme();
                      },
                      borderRadius: context.radius.asBorderRadiusFull,
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
                            Text(
                              isDark ? 'Light' : 'Dark',
                              style: context.typography.captionMuted.copyWith(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: context.spacing.xxs),
                            Icon(
                              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                              color: context.colors.textPrimary,
                              size: context.sizes.iconSm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeVm.toggleTheme();
                  },
                );
              },
            ),

            // Action: Switch Queue Mode
            ListTile(
              leading: Icon(
                _getQueueModeIcon(player.queueMode),
                color: context.colors.textPrimary,
                size: context.sizes.iconMd,
              ),
              title: Text(
                'Switch Queue Mode',
                style: context.typography.titleMedium,
              ),
              subtitle: Text(
                'Current: ${_getQueueModeTitle(player.queueMode)} (${_getQueueModeRatio(player.queueMode)})',
                style: context.typography.captionMuted,
              ),
              trailing: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<AudioPlayerViewModel>().cycleQueueMode();
                  },
                  borderRadius: context.radius.asBorderRadiusFull,
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
                        Text(
                          'Switch',
                          style: context.typography.captionMuted.copyWith(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: context.spacing.xxs),
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: context.colors.textPrimary,
                          size: context.sizes.iconSm,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AudioPlayerViewModel>().cycleQueueMode();
              },
            ),

            // Horizontal Mode Pills for quick direct access
            Padding(
              padding: EdgeInsets.only(
                left: context.spacing.md,
                right: context.spacing.md,
                bottom: context.spacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildModeChip(
                      context: context,
                      label: 'Blend Languages',
                      icon: Icons.language_rounded,
                      mode: QueueMode.blend,
                      activeMode: player.queueMode,
                    ),
                    SizedBox(width: context.spacing.xs),
                    _buildModeChip(
                      context: context,
                      label: 'Discover',
                      icon: Icons.explore_rounded,
                      mode: QueueMode.discover,
                      activeMode: player.queueMode,
                    ),
                    SizedBox(width: context.spacing.xs),
                    _buildModeChip(
                      context: context,
                      label: 'Familiar',
                      icon: Icons.favorite_rounded,
                      mode: QueueMode.familiar,
                      activeMode: player.queueMode,
                    ),
                    SizedBox(width: context.spacing.xs),
                    _buildModeChip(
                      context: context,
                      label: 'Single Language',
                      icon: Icons.lock_outline_rounded,
                      mode: QueueMode.singleLanguage,
                      activeMode: player.queueMode,
                    ),
                  ],
                ),
              ),
            ),

            // Action: Toggle Artwork Style
            ListTile(
              leading: Icon(
                isVinyl ? Icons.album_rounded : Icons.image_rounded,
                color: context.colors.textPrimary,
                size: context.sizes.iconMd,
              ),
              title: Text(
                isVinyl ? 'Switch to Card Artwork' : 'Switch to Vinyl Record Mode',
                style: context.typography.titleMedium,
              ),
              subtitle: Text(
                isVinyl ? 'Current: Rotating Vinyl Disc' : 'Current: Classic Card Art',
                style: context.typography.captionMuted,
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AudioPlayerViewModel>().toggleArtworkStyle();
              },
            ),

            // Action: Equalizer
            ListTile(
              leading: Icon(
                Icons.tune_rounded,
                color: context.colors.textPrimary,
                size: context.sizes.iconMd,
              ),
              title: Text(
                'Audio Equalizer',
                style: context.typography.titleMedium,
              ),
              subtitle: Text(
                'Active: ${player.activeEqualizerPreset}',
                style: context.typography.captionMuted,
              ),
              onTap: () {
                Navigator.of(context).maybePop();
                EqualizerBottomSheet.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required QueueMode mode,
    required QueueMode activeMode,
  }) {
    final isActive = mode == activeMode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.read<AudioPlayerViewModel>().setQueueMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xs,
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
                color: isActive
                    ? context.colors.oledBackground
                    : context.colors.textPrimary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getQueueModeIcon(QueueMode mode) {
    switch (mode) {
      case QueueMode.blend:
        return Icons.language_rounded;
      case QueueMode.discover:
        return Icons.explore_rounded;
      case QueueMode.familiar:
        return Icons.favorite_rounded;
      case QueueMode.singleLanguage:
        return Icons.lock_outline_rounded;
    }
  }

  String _getQueueModeTitle(QueueMode mode) {
    switch (mode) {
      case QueueMode.blend:
        return 'Blend Languages';
      case QueueMode.discover:
        return 'Discover';
      case QueueMode.familiar:
        return 'Familiar';
      case QueueMode.singleLanguage:
        return 'Single Language';
    }
  }

  String _getQueueModeRatio(QueueMode mode) {
    switch (mode) {
      case QueueMode.blend:
        return '60/40 Blend';
      case QueueMode.discover:
        return '70/30 Exploration';
      case QueueMode.familiar:
        return '40/60 Comfort';
      case QueueMode.singleLanguage:
        return '100% Strict Match';
    }
  }
}

class _SpecPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpecPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.colors.textPrimary, size: context.sizes.iconSm),
        SizedBox(height: context.spacing.xxs),
        Text(value, style: context.typography.titleMedium.copyWith(fontSize: 12.0)),
        Text(label, style: context.typography.captionMuted.copyWith(fontSize: 10.0)),
      ],
    );
  }
}

