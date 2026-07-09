import 'package:flutter/material.dart';

/// Central colour palette for Leopard Sightings.
///
/// Nature-inspired, government / public-safety styling: deep forest greens,
/// olive accents, amber highlights, with red reserved for danger/alerts.
/// Use these constants everywhere instead of hard-coded [Color] values so the
/// look stays consistent.
abstract final class AppColors {
  // ── Brand greens ──────────────────────────────────────────────────────────
  /// Primary — deep forest green (matches the app logo background).
  static const Color forestGreen = Color(0xFF1B5E20);
  static const Color forestGreenDark = Color(0xFF0B3D2E);
  static const Color forestGreenLight = Color(0xFF4C8C4A);

  /// Secondary — olive green.
  static const Color olive = Color(0xFF6B8E23);
  static const Color oliveLight = Color(0xFFE7EDD6);

  // ── Accent / semantic ─────────────────────────────────────────────────────
  /// Accent — amber (used sparingly for highlights, admin, warnings).
  static const Color amber = Color(0xFFF9A825);
  static const Color amberLight = Color(0xFFFFF3D6);

  /// Danger — red (alerts, destructive actions, danger radius).
  static const Color danger = Color(0xFFC62828);
  static const Color dangerLight = Color(0xFFFDE7E7);

  /// Success — green (confirmations).
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE3F2E4);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  /// App background — very light grey.
  static const Color background = Color(0xFFF4F6F3);

  /// Card / surface — white.
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1A1C19);
  static const Color textSecondary = Color(0xFF5A6157);
  static const Color border = Color(0xFFE0E4DC);
}
