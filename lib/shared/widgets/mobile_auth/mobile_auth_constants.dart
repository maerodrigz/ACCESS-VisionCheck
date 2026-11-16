import 'package:flutter/material.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';

/// Mobile sign-in / sign-up chrome (cyan header + white form).
abstract final class MobileAuthConstants {
  static const tagline = AppConstants.tagline;

  static const signInBackgroundAsset = 'assets/images/signin_background.png';
  static const welcomeBackgroundAsset = 'assets/images/welcome_background.png';

  /// Midnight Scanner wordmark cyan (Sign In / Sign Up headers).
  static const visionCheckBrightCyan = Color(0xFF35D8F2);

  /// Image-backed header branding (logo diameter scales with screen width).
  static double headerLogoSize(double screenWidth) {
    if (screenWidth < 340) return 41;
    if (screenWidth < 400) return 45;
    return 47;
  }

  static double headerAccessFontSize(double screenWidth) =>
      screenWidth < 360 ? 15.0 : 16.0;

  static double headerVisionCheckFontSize(double screenWidth) =>
      screenWidth < 360 ? 17.5 : 18.5;

  static double headerTaglineFontSize(double screenWidth) =>
      screenWidth < 360 ? 9.5 : 10.0;

  /// Upper-middle of navy header (Sign In / Sign Up); not flush to status bar.
  static const imageBackedBrandAlignment = Alignment(-1, -0.14);

  /// Registration / sign-up (scrollable body, non-image legacy).
  static const headerHeightFactor = 0.30;

  /// Sign-in and image-backed sign-up: navy header height (matches background art).
  static const signInHeaderHeightFactor = 0.30;
  static const signInHeaderMinHeight = 198.0;
  static const signInHeaderMaxHeight = 248.0;

  /// Scaffold / navigator fallback during auth transitions (matches sign-in art navy).
  static const midnightScaffoldColor = Color(0xFF0C2236);
  /// Minimal chrome above the form when the keyboard is open (excludes status bar).
  static const signInHeaderKeyboardBodyHeight = 28.0;
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
