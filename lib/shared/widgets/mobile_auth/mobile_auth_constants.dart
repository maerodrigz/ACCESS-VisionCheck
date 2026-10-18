import 'package:flutter/material.dart';

/// Mobile sign-in / sign-up chrome (cyan header + white form).
abstract final class MobileAuthConstants {
  static const tagline = 'Beyond Documentation Towards Excellence.';
  /// Registration / sign-up (scrollable body).
  static const headerHeightFactor = 0.30;

  /// Sign-in: taller cyan hero so the white form area does not feel stretched.
  static const signInHeaderHeightFactor = 0.34;
  static const signInHeaderMinHeight = 220.0;
  static const signInHeaderMaxHeight = 268.0;
  /// Minimal chrome above the form when the keyboard is open (excludes status bar).
  static const signInHeaderKeyboardBodyHeight = 40.0;
  static const fieldRadius = 12.0;
  static const buttonRadius = 12.0;

  /// ACCESS brand cyan (matches [kCyan] in theme.dart).
  static const headerCyan = Color(0xFF00C4E8);

  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF5DE4FF),
      headerCyan,
      Color(0xFF00B0D8),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Matches [headerGradient] so Sign In / Register buttons match the hero.
  static const signInGradient = headerGradient;
}
