import 'package:flutter/material.dart';

/// Rule #9: Minimalist Matte & Solid Color Design Standard.
/// Strictly flat/solid palette tones with crisp typography and subtle borders.
/// Zero bright neon glow effects, flashy radial/linear gradients, or rainbow accents.
class AppPalette {
  AppPalette._();

  // Backgrounds & Surfaces
  static const Color obsidianBackground = Color(0xFF161618);
  static const Color obsidianSurface = Color(0xFF18181B);
  static const Color obsidianCard = Color(0xFF222226);
  static const Color obsidianElevated = Color(0xFF242428);

  // Borders & Dividers
  static const Color matteBorder = Color(0xFF2E2E32);
  static const Color subtleDivider = Color(0xFF26262B);

  // Functional Solid Accents
  static const Color solidEmerald = Color(
    0xFF1DB954,
  ); // Success, bitrates, downloaded
  static const Color solidRuby = Color(
    0xFFFA2D48,
  ); // Brand, favorites, active player
  static const Color solidAmber = Color(
    0xFFF59E0B,
  ); // Warnings, offline indicator
  static const Color solidCrimson = Color(
    0xFFEF4444,
  ); // Errors, dismiss/delete actions

  // Typography & Neutrals
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}
