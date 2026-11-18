import 'package:flutter/material.dart';

/// Pure Monochrome Theme Tokens adhering strictly to AGENTS.md Invariant 4:
/// - Absolute Black & White Palette (Dark & Light Mode Support)
/// - Zero Gradients & Zero Neons across surfaces, buttons, indicators, and docks
/// - High-contrast matte monochrome finishes
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color oledBackground;
  final Color cardDarkSurface;
  final Color surfaceContainer;
  final Color floatingDockSurface;
  final Color solidMatteBorder;
  final Color brandRuby; // In pure monochrome, maps to primary accent (White in dark, Black in light)
  final Color successEmerald;
  final Color warningAmber;
  final Color errorCrimson;
  final Color textPrimary;
  final Color textSecondary;
  final Color mixBlue;
  final Color mixPurple;
  final Color mixTeal;
  final Color mixAmber;
  final Color mixGreen;
  final Color mixCrimson;

  const AppColors({
    required this.oledBackground,
    required this.cardDarkSurface,
    required this.surfaceContainer,
    required this.floatingDockSurface,
    required this.solidMatteBorder,
    required this.brandRuby,
    required this.successEmerald,
    required this.warningAmber,
    required this.errorCrimson,
    required this.textPrimary,
    required this.textSecondary,
    required this.mixBlue,
    required this.mixPurple,
    required this.mixTeal,
    required this.mixAmber,
    required this.mixGreen,
    required this.mixCrimson,
  });

  /// Dark Mode: Pure OLED Black with matte grey surfaces and pure white highlights
  static const dark = AppColors(
    oledBackground: Color(0xFF000000),
    cardDarkSurface: Color(0xFF121214),
    surfaceContainer: Color(0xFF161618),
    floatingDockSurface: Color(0xFF141416),
    solidMatteBorder: Color(0xFF242428),
    brandRuby: Color(0xFFFFFFFF), // Pure white primary accent
    successEmerald: Color(0xFFE5E5EA),
    warningAmber: Color(0xFFD1D1D6),
    errorCrimson: Color(0xFFFF453A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
    // Monochromatic solid matte tiles for quick access & chips
    mixBlue: Color(0xFF18181B),
    mixPurple: Color(0xFF18181B),
    mixTeal: Color(0xFF18181B),
    mixAmber: Color(0xFF18181B),
    mixGreen: Color(0xFF18181B),
    mixCrimson: Color(0xFF18181B),
  );

  /// Light Mode: Clean White with subtle light matte surfaces and pure black text/highlights
  static const light = AppColors(
    oledBackground: Color(0xFFFFFFFF),
    cardDarkSurface: Color(0xFFF5F5F7),
    surfaceContainer: Color(0xFFEFEFF4),
    floatingDockSurface: Color(0xFFFFFFFF),
    solidMatteBorder: Color(0xFFE5E5EA),
    brandRuby: Color(0xFF000000), // Pure black primary accent
    successEmerald: Color(0xFF2C2C2E),
    warningAmber: Color(0xFF3A3A3C),
    errorCrimson: Color(0xFFFF3B30),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF6E6E73),
    // Monochromatic light matte tiles for quick access & chips
    mixBlue: Color(0xFFF5F5F7),
    mixPurple: Color(0xFFF5F5F7),
    mixTeal: Color(0xFFF5F5F7),
    mixAmber: Color(0xFFF5F5F7),
    mixGreen: Color(0xFFF5F5F7),
    mixCrimson: Color(0xFFF5F5F7),
  );

  @override
  AppColors copyWith({
    Color? oledBackground,
    Color? cardDarkSurface,
    Color? surfaceContainer,
    Color? floatingDockSurface,
    Color? solidMatteBorder,
    Color? brandRuby,
    Color? successEmerald,
    Color? warningAmber,
    Color? errorCrimson,
    Color? textPrimary,
    Color? textSecondary,
    Color? mixBlue,
    Color? mixPurple,
    Color? mixTeal,
    Color? mixAmber,
    Color? mixGreen,
    Color? mixCrimson,
  }) {
    return AppColors(
      oledBackground: oledBackground ?? this.oledBackground,
      cardDarkSurface: cardDarkSurface ?? this.cardDarkSurface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      floatingDockSurface: floatingDockSurface ?? this.floatingDockSurface,
      solidMatteBorder: solidMatteBorder ?? this.solidMatteBorder,
      brandRuby: brandRuby ?? this.brandRuby,
      successEmerald: successEmerald ?? this.successEmerald,
      warningAmber: warningAmber ?? this.warningAmber,
      errorCrimson: errorCrimson ?? this.errorCrimson,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      mixBlue: mixBlue ?? this.mixBlue,
      mixPurple: mixPurple ?? this.mixPurple,
      mixTeal: mixTeal ?? this.mixTeal,
      mixAmber: mixAmber ?? this.mixAmber,
      mixGreen: mixGreen ?? this.mixGreen,
      mixCrimson: mixCrimson ?? this.mixCrimson,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      oledBackground: Color.lerp(oledBackground, other.oledBackground, t)!,
      cardDarkSurface: Color.lerp(cardDarkSurface, other.cardDarkSurface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      floatingDockSurface: Color.lerp(floatingDockSurface, other.floatingDockSurface, t)!,
      solidMatteBorder: Color.lerp(solidMatteBorder, other.solidMatteBorder, t)!,
      brandRuby: Color.lerp(brandRuby, other.brandRuby, t)!,
      successEmerald: Color.lerp(successEmerald, other.successEmerald, t)!,
      warningAmber: Color.lerp(warningAmber, other.warningAmber, t)!,
      errorCrimson: Color.lerp(errorCrimson, other.errorCrimson, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      mixBlue: Color.lerp(mixBlue, other.mixBlue, t)!,
      mixPurple: Color.lerp(mixPurple, other.mixPurple, t)!,
      mixTeal: Color.lerp(mixTeal, other.mixTeal, t)!,
      mixAmber: Color.lerp(mixAmber, other.mixAmber, t)!,
      mixGreen: Color.lerp(mixGreen, other.mixGreen, t)!,
      mixCrimson: Color.lerp(mixCrimson, other.mixCrimson, t)!,
    );
  }
}
