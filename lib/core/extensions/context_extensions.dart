import 'package:flutter/material.dart';
import '../theme/tokens/app_colors.dart';
import '../theme/tokens/app_radius.dart';
import '../theme/tokens/app_sizes.dart';
import '../theme/tokens/app_spacing.dart';
import '../theme/tokens/app_typography.dart';

extension ThemeContextExtensions on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;

  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? AppSpacing.standard;

  AppRadius get radius =>
      Theme.of(this).extension<AppRadius>() ?? AppRadius.standard;

  AppSizes get sizes =>
      Theme.of(this).extension<AppSizes>() ?? AppSizes.standard;

  AppTypography get typography =>
      Theme.of(this).extension<AppTypography>() ?? AppTypography.standard;
}

