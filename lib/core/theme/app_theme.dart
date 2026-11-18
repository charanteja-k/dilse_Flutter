import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_sizes.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

/// Pure Monochrome Theme System strictly adhering to AGENTS.md Invariant 4:
/// - Dark Mode: Absolute OLED black (#000000), deep matte surfaces, pure white text
/// - Light Mode: Clean White (#FFFFFF), subtle light matte surfaces, pure black text
/// - Zero Gradients & Zero Neons across all UI layers
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.dark.oledBackground,
      colorScheme: ColorScheme.dark(
        surface: AppColors.dark.oledBackground,
        primary: AppColors.dark.textPrimary,
        secondary: AppColors.dark.textSecondary,
        error: AppColors.dark.errorCrimson,
      ),
      extensions: const [
        AppColors.dark,
        AppSpacing.standard,
        AppRadius.standard,
        AppSizes.standard,
        AppTypography.dark,
      ],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.light.oledBackground,
      colorScheme: ColorScheme.light(
        surface: AppColors.light.oledBackground,
        primary: AppColors.light.textPrimary,
        secondary: AppColors.light.textSecondary,
        error: AppColors.light.errorCrimson,
      ),
      extensions: const [
        AppColors.light,
        AppSpacing.standard,
        AppRadius.standard,
        AppSizes.standard,
        AppTypography.light,
      ],
    );
  }
}
