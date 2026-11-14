import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/context_extensions.dart';
import '../viewmodels/audio_player_viewmodel.dart';

/// Modal bottom sheet providing 5-band audio equalizer controls and acoustic presets.
/// Strictly follows Invariant 1 (Provider injection) and Invariant 2 (tokenized context delivery).
class EqualizerBottomSheet extends StatelessWidget {
  const EqualizerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const EqualizerBottomSheet(),
    );
  }

  static const List<String> _bandLabels = [
    '60 Hz',
    '230 Hz',
    '910 Hz',
    '3.6 kHz',
    '14 kHz',
  ];

  static const List<String> _bandSubtitles = [
    'Sub-Bass',
    'Bass',
    'Mids',
    'Presence',
    'Treble',
  ];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerViewModel>();
    final activePreset = player.activeEqualizerPreset;
    final bands = player.equalizerBands;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: context.sizes.heroCardWidth * 0.15,
                height: context.spacing.xxs,
                decoration: BoxDecoration(
                  color: context.colors.textSecondary.withAlpha(80),
                  borderRadius: context.radius.asBorderRadiusFull,
                ),
              ),
            ),
            SizedBox(height: context.spacing.sm),

            // Header Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Equalizer',
                        style: context.typography.headlineMedium,
                      ),
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        'Acoustic profile: $activePreset',
                        style: context.typography.captionMuted,
                      ),
                    ],
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
            SizedBox(height: context.spacing.sm),

            // Presets Horizontal Shelf
            SizedBox(
              height: context.sizes.chipHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
                itemCount: AudioPlayerViewModel.equalizerPresets.length,
                separatorBuilder: (context, index) => SizedBox(width: context.spacing.xs),
                itemBuilder: (context, index) {
                  final preset = AudioPlayerViewModel.equalizerPresets[index];
                  final isSelected = activePreset == preset;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<AudioPlayerViewModel>().setEqualizerPreset(preset);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.sm,
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
                          preset,
                          style: context.typography.bodyMedium.copyWith(
                            color: isSelected
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: context.spacing.lg),

            // 5 Band Sliders
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final gain = index < bands.length ? bands[index] : 0.0;

                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB',
                          style: context.typography.captionMuted.copyWith(
                            fontSize: 10.0,
                            color: gain != 0
                                ? context.colors.brandRuby
                                : context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: context.spacing.xs),
                        SizedBox(
                          height: 140,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: context.spacing.xxs,
                                activeTrackColor: context.colors.brandRuby,
                                inactiveTrackColor: context.colors.solidMatteBorder,
                                thumbColor: context.colors.textPrimary,
                                overlayColor: context.colors.brandRuby.withAlpha(40),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: gain.clamp(-10.0, 10.0),
                                min: -10.0,
                                max: 10.0,
                                onChanged: (val) {
                                  context.read<AudioPlayerViewModel>().setEqualizerBand(index, val);
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: context.spacing.xs),
                        Text(
                          _bandLabels[index],
                          style: context.typography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.0,
                          ),
                        ),
                        Text(
                          _bandSubtitles[index],
                          style: context.typography.captionMuted.copyWith(
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

