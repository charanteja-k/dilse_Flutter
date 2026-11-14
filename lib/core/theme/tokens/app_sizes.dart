import 'dart:ui';
import 'package:flutter/material.dart';

@immutable
class AppSizes extends ThemeExtension<AppSizes> {
  final double miniPlayerHeight;
  final double navDockHeight;
  final double navDockElevation;
  final double iconSm;
  final double iconMd;
  final double iconLg;
  final double avatarSm;
  final double avatarMd;
  final double avatarLg;
  final double heroCardWidth;
  final double heroCardHeight;
  final double songCardSize;
  final double borderThin;
  final double chipHeight;
  final double trackShelfHeight;
  final double thumbnailMd;
  final double quickAccessTileHeight;
  final double badgeDotSize;
  final double progressBarHeight;
  final double playerHeroPlaySize;
  final double playerHeroPlayIconSize;
  final double playerSkipIconSize;
  final double playerArtworkRadius;
  final double playerScrubberHeight;
  final double queueItemHeight;

  const AppSizes({
    required this.miniPlayerHeight,
    required this.navDockHeight,
    required this.navDockElevation,
    required this.iconSm,
    required this.iconMd,
    required this.iconLg,
    required this.avatarSm,
    required this.avatarMd,
    required this.avatarLg,
    required this.heroCardWidth,
    required this.heroCardHeight,
    required this.songCardSize,
    required this.borderThin,
    required this.chipHeight,
    required this.trackShelfHeight,
    required this.thumbnailMd,
    required this.quickAccessTileHeight,
    required this.badgeDotSize,
    required this.progressBarHeight,
    required this.playerHeroPlaySize,
    required this.playerHeroPlayIconSize,
    required this.playerSkipIconSize,
    required this.playerArtworkRadius,
    required this.playerScrubberHeight,
    required this.queueItemHeight,
  });

  static const standard = AppSizes(
    miniPlayerHeight: 64.0,
    navDockHeight: 64.0,
    navDockElevation: 8.0,
    iconSm: 18.0,
    iconMd: 24.0,
    iconLg: 32.0,
    avatarSm: 32.0,
    avatarMd: 44.0,
    avatarLg: 64.0,
    heroCardWidth: 260.0,
    heroCardHeight: 160.0,
    songCardSize: 140.0,
    borderThin: 1.0,
    chipHeight: 38.0,
    trackShelfHeight: 196.0,
    thumbnailMd: 48.0,
    quickAccessTileHeight: 56.0,
    badgeDotSize: 10.0,
    progressBarHeight: 6.0,
    playerHeroPlaySize: 76.0,
    playerHeroPlayIconSize: 52.0,
    playerSkipIconSize: 38.0,
    playerArtworkRadius: 26.0,
    playerScrubberHeight: 44.0,
    queueItemHeight: 64.0,
  );

  @override
  AppSizes copyWith({
    double? miniPlayerHeight,
    double? navDockHeight,
    double? navDockElevation,
    double? iconSm,
    double? iconMd,
    double? iconLg,
    double? avatarSm,
    double? avatarMd,
    double? avatarLg,
    double? heroCardWidth,
    double? heroCardHeight,
    double? songCardSize,
    double? borderThin,
    double? chipHeight,
    double? trackShelfHeight,
    double? thumbnailMd,
    double? quickAccessTileHeight,
    double? badgeDotSize,
    double? progressBarHeight,
    double? playerHeroPlaySize,
    double? playerHeroPlayIconSize,
    double? playerSkipIconSize,
    double? playerArtworkRadius,
    double? playerScrubberHeight,
    double? queueItemHeight,
  }) {
    return AppSizes(
      miniPlayerHeight: miniPlayerHeight ?? this.miniPlayerHeight,
      navDockHeight: navDockHeight ?? this.navDockHeight,
      navDockElevation: navDockElevation ?? this.navDockElevation,
      iconSm: iconSm ?? this.iconSm,
      iconMd: iconMd ?? this.iconMd,
      iconLg: iconLg ?? this.iconLg,
      avatarSm: avatarSm ?? this.avatarSm,
      avatarMd: avatarMd ?? this.avatarMd,
      avatarLg: avatarLg ?? this.avatarLg,
      heroCardWidth: heroCardWidth ?? this.heroCardWidth,
      heroCardHeight: heroCardHeight ?? this.heroCardHeight,
      songCardSize: songCardSize ?? this.songCardSize,
      borderThin: borderThin ?? this.borderThin,
      chipHeight: chipHeight ?? this.chipHeight,
      trackShelfHeight: trackShelfHeight ?? this.trackShelfHeight,
      thumbnailMd: thumbnailMd ?? this.thumbnailMd,
      quickAccessTileHeight: quickAccessTileHeight ?? this.quickAccessTileHeight,
      badgeDotSize: badgeDotSize ?? this.badgeDotSize,
      progressBarHeight: progressBarHeight ?? this.progressBarHeight,
      playerHeroPlaySize: playerHeroPlaySize ?? this.playerHeroPlaySize,
      playerHeroPlayIconSize: playerHeroPlayIconSize ?? this.playerHeroPlayIconSize,
      playerSkipIconSize: playerSkipIconSize ?? this.playerSkipIconSize,
      playerArtworkRadius: playerArtworkRadius ?? this.playerArtworkRadius,
      playerScrubberHeight: playerScrubberHeight ?? this.playerScrubberHeight,
      queueItemHeight: queueItemHeight ?? this.queueItemHeight,
    );
  }

  @override
  AppSizes lerp(ThemeExtension<AppSizes>? other, double t) {
    if (other is! AppSizes) return this;
    return AppSizes(
      miniPlayerHeight: lerpDouble(miniPlayerHeight, other.miniPlayerHeight, t)!,
      navDockHeight: lerpDouble(navDockHeight, other.navDockHeight, t)!,
      navDockElevation: lerpDouble(navDockElevation, other.navDockElevation, t)!,
      iconSm: lerpDouble(iconSm, other.iconSm, t)!,
      iconMd: lerpDouble(iconMd, other.iconMd, t)!,
      iconLg: lerpDouble(iconLg, other.iconLg, t)!,
      avatarSm: lerpDouble(avatarSm, other.avatarSm, t)!,
      avatarMd: lerpDouble(avatarMd, other.avatarMd, t)!,
      avatarLg: lerpDouble(avatarLg, other.avatarLg, t)!,
      heroCardWidth: lerpDouble(heroCardWidth, other.heroCardWidth, t)!,
      heroCardHeight: lerpDouble(heroCardHeight, other.heroCardHeight, t)!,
      songCardSize: lerpDouble(songCardSize, other.songCardSize, t)!,
      borderThin: lerpDouble(borderThin, other.borderThin, t)!,
      chipHeight: lerpDouble(chipHeight, other.chipHeight, t)!,
      trackShelfHeight: lerpDouble(trackShelfHeight, other.trackShelfHeight, t)!,
      thumbnailMd: lerpDouble(thumbnailMd, other.thumbnailMd, t)!,
      quickAccessTileHeight: lerpDouble(quickAccessTileHeight, other.quickAccessTileHeight, t)!,
      badgeDotSize: lerpDouble(badgeDotSize, other.badgeDotSize, t)!,
      progressBarHeight: lerpDouble(progressBarHeight, other.progressBarHeight, t)!,
      playerHeroPlaySize: lerpDouble(playerHeroPlaySize, other.playerHeroPlaySize, t)!,
      playerHeroPlayIconSize: lerpDouble(playerHeroPlayIconSize, other.playerHeroPlayIconSize, t)!,
      playerSkipIconSize: lerpDouble(playerSkipIconSize, other.playerSkipIconSize, t)!,
      playerArtworkRadius: lerpDouble(playerArtworkRadius, other.playerArtworkRadius, t)!,
      playerScrubberHeight: lerpDouble(playerScrubberHeight, other.playerScrubberHeight, t)!,
      queueItemHeight: lerpDouble(queueItemHeight, other.queueItemHeight, t)!,
    );
  }
}

