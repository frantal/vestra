import 'package:flutter/material.dart';

/// VESTRA brand color palette.
///
/// Dark, premium aesthetic with a neon cyan accent. All colors are defined
/// once here and consumed exclusively through [AppColors] to keep the design
/// system consistent across the app.
abstract final class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0B0F1A);
  static const Color surface = Color(0xFF131A27);
  static const Color surfaceElevated = Color(0xFF1A2435);

  // Brand
  static const Color primary = Color(0xFF00D4FF);
  static const Color accent = Color(0xFF34E5FF);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA5B4C3);
  static const Color textTertiary = Color(0xFF6B7889);

  // Feedback
  static const Color success = Color(0xFF34E5A8);
  static const Color warning = Color(0xFFFFC453);
  static const Color error = Color(0xFFFF5C7A);

  // Lines / borders
  static const Color border = Color(0x1AFFFFFF); // white @ 10%
  static const Color borderStrong = Color(0x33FFFFFF); // white @ 20%

  // Glass surfaces
  static const Color glass = Color(0x14FFFFFF); // white @ 8%
  static const Color glassStrong = Color(0x1FFFFFFF); // white @ 12%

  /// Primary brand gradient used for buttons and highlights.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle background gradient for full-screen surfaces.
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0B0F1A), Color(0xFF0E1626)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
