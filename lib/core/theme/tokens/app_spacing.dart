import 'dart:ui';
import 'package:flutter/material.dart';

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const AppSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const standard = AppSpacing(
    xxs: 2.0,
    xs: 4.0,
    sm: 8.0,
    md: 16.0,
    lg: 24.0,
    xl: 32.0,
    xxl: 48.0,
  );

  EdgeInsets get insetsXxs => EdgeInsets.all(xxs);
  EdgeInsets get insetsXs => EdgeInsets.all(xs);
  EdgeInsets get insetsSm => EdgeInsets.all(sm);
  EdgeInsets get insetsMd => EdgeInsets.all(md);
  EdgeInsets get insetsLg => EdgeInsets.all(lg);
  EdgeInsets get insetsXl => EdgeInsets.all(xl);
  EdgeInsets get insetsXxl => EdgeInsets.all(xxl);

  EdgeInsets insetsHorizontal(double value) =>
      EdgeInsets.symmetric(horizontal: value);
  EdgeInsets insetsVertical(double value) =>
      EdgeInsets.symmetric(vertical: value);
  EdgeInsets insetsSymmetric({
    required double horizontal,
    required double vertical,
  }) => EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);

  @override
  AppSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return AppSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}
