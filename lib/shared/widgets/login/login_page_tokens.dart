import 'package:flutter/material.dart';

/// ACCESS VisionCheck login page design tokens.
abstract final class LoginPageTokens {
  static const primary = Color(0xFF0052D4);
  static const secondary = Color(0xFF0066FF);
  static const accent = Color(0xFF00C4E8);
  static const purple = Color(0xFF5B21B6);
  static const background = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);

  static const maxFormWidth = 420.0;

  /// Dark hero gradient — matches mobile requestor/member shells (no photo).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050C1C),
      Color(0xFF0A1628),
      Color(0xFF0C3340),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const heroGlow = Color(0xFF00C4E8);
}
