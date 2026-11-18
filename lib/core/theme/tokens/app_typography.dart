import 'package:flutter/material.dart';

@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  final TextStyle displayLarge;
  final TextStyle headlineMedium;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle captionMuted;
  final TextStyle eyebrow;
  final TextStyle playerTitle;
  final TextStyle playerSubtitle;

  const AppTypography({
    required this.displayLarge,
    required this.headlineMedium,
    required this.titleLarge,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.captionMuted,
    required this.eyebrow,
    required this.playerTitle,
    required this.playerSubtitle,
  });

  static const dark = AppTypography(
    displayLarge: TextStyle(
      fontSize: 28.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: Color(0xFFFFFFFF),
    ),
    headlineMedium: TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: Color(0xFFFFFFFF),
    ),
    titleLarge: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFFFFFFFF),
    ),
    titleMedium: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFFFFFFFF),
    ),
    bodyLarge: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF8E8E93),
    ),
    bodyMedium: TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF8E8E93),
    ),
    captionMuted: TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      color: Color(0xFF8E8E93),
    ),
    eyebrow: TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Color(0xFF8E8E93),
    ),
    playerTitle: TextStyle(
      fontSize: 22.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: Color(0xFFFFFFFF),
    ),
    playerSubtitle: TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
      color: Color(0xFF8E8E93),
    ),
  );

  static const light = AppTypography(
    displayLarge: TextStyle(
      fontSize: 28.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: Color(0xFF000000),
    ),
    headlineMedium: TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: Color(0xFF000000),
    ),
    titleLarge: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFF000000),
    ),
    titleMedium: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFF000000),
    ),
    bodyLarge: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF6E6E73),
    ),
    bodyMedium: TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF6E6E73),
    ),
    captionMuted: TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      color: Color(0xFF6E6E73),
    ),
    eyebrow: TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Color(0xFF6E6E73),
    ),
    playerTitle: TextStyle(
      fontSize: 22.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: Color(0xFF000000),
    ),
    playerSubtitle: TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
      color: Color(0xFF6E6E73),
    ),
  );

  static const standard = dark;

  @override
  AppTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? headlineMedium,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? captionMuted,
    TextStyle? eyebrow,
    TextStyle? playerTitle,
    TextStyle? playerSubtitle,
  }) {
    return AppTypography(
      displayLarge: displayLarge ?? this.displayLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      captionMuted: captionMuted ?? this.captionMuted,
      eyebrow: eyebrow ?? this.eyebrow,
      playerTitle: playerTitle ?? this.playerTitle,
      playerSubtitle: playerSubtitle ?? this.playerSubtitle,
    );
  }

  @override
  ThemeExtension<AppTypography> lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      headlineMedium: TextStyle.lerp(headlineMedium, other.headlineMedium, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      captionMuted: TextStyle.lerp(captionMuted, other.captionMuted, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
      playerTitle: TextStyle.lerp(playerTitle, other.playerTitle, t)!,
      playerSubtitle: TextStyle.lerp(playerSubtitle, other.playerSubtitle, t)!,
    );
  }
}
