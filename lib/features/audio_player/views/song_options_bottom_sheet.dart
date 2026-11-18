import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
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
                isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isLiked
                    ? context.colors.brandRuby
                    : context.colors.textPrimary,
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

            // Action: Toggle Artwork Style
            ListTile(
              leading: Icon(
                isVinyl ? Icons.album_rounded : Icons.image_rounded,
                color: context.colors.brandRuby,
                size: context.sizes.iconMd,
              ),
              title: Text(
                isVinyl
                    ? 'Switch to Card Artwork'
                    : 'Switch to Vinyl Record Mode',
                style: context.typography.titleMedium,
              ),
              subtitle: Text(
                isVinyl
                    ? 'Current: Rotating Vinyl Disc'
                    : 'Current: Classic Card Art',
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
        Icon(icon, color: context.colors.brandRuby, size: context.sizes.iconSm),
        SizedBox(height: context.spacing.xxs),
        Text(
          value,
          style: context.typography.titleMedium.copyWith(fontSize: 12.0),
        ),
        Text(
          label,
          style: context.typography.captionMuted.copyWith(fontSize: 10.0),
        ),
      ],
    );
  }
}
