import 'dart:ui';
import 'package:flutter/material.dart';

@immutable
class AppRadius extends ThemeExtension<AppRadius> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double card;
  final double dock;
  final double full;

  const AppRadius({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.card,
    required this.dock,
    required this.full,
  });

  static const standard = AppRadius(
    xs: 4.0,
    sm: 8.0,
    md: 12.0,
    lg: 16.0,
    card: 20.0,
    dock: 32.0,
    full: 999.0,
  );

  BorderRadius get asBorderRadiusXs => BorderRadius.circular(xs);
  BorderRadius get asBorderRadiusSm => BorderRadius.circular(sm);
  BorderRadius get asBorderRadiusMd => BorderRadius.circular(md);
  BorderRadius get asBorderRadiusLg => BorderRadius.circular(lg);
  BorderRadius get asBorderRadiusCard => BorderRadius.circular(card);
  BorderRadius get asBorderRadiusDock => BorderRadius.circular(dock);
  BorderRadius get asBorderRadiusFull => BorderRadius.circular(full);

  @override
  AppRadius copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? card,
    double? dock,
    double? full,
  }) {
    return AppRadius(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      card: card ?? this.card,
      dock: dock ?? this.dock,
      full: full ?? this.full,
    );
  }

  @override
  AppRadius lerp(ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) return this;
    return AppRadius(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      card: lerpDouble(card, other.card, t)!,
      dock: lerpDouble(dock, other.dock, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}

