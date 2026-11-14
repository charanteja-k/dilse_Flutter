import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_sizes.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.dark.oledBackground,
      colorScheme: ColorScheme.dark(
        surface: AppColors.dark.oledBackground,
        primary: AppColors.dark.brandRuby,
        secondary: AppColors.dark.successEmerald,
        error: AppColors.dark.errorCrimson,
      ),
      extensions: const [
        AppColors.dark,
        AppSpacing.standard,
        AppRadius.standard,
        AppSizes.standard,
        AppTypography.standard,
      ],
    );
  }
}

