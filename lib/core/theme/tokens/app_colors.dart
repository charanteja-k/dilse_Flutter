import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color oledBackground;
  final Color cardDarkSurface;
  final Color surfaceContainer;
  final Color floatingDockSurface;
  final Color solidMatteBorder;
  final Color brandRuby;
  final Color successEmerald;
  final Color warningAmber;
  final Color errorCrimson;
  final Color textPrimary;
  final Color textSecondary;

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
  });

  static const dark = AppColors(
    oledBackground: Color(0xFF000000),
    cardDarkSurface: Color(0xFF18181B),
    surfaceContainer: Color(0xFF181818),
    floatingDockSurface: Color(0xFF161618),
    solidMatteBorder: Color(0xFF2E2E32),
    brandRuby: Color(0xFFFA2D48),
    successEmerald: Color(0xFF1DB954),
    warningAmber: Color(0xFFF59E0B),
    errorCrimson: Color(0xFFEF4444),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
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
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
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
    );
  }
}

