import 'package:flutter/material.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

/// Precache midnight scanner backgrounds so auth routes do not flash on first paint.
Future<void> precacheMobileAuthBackgrounds(BuildContext context) async {
  await Future.wait([
    precacheImage(
      const AssetImage(MobileAuthConstants.signInBackgroundAsset),
      context,
    ),
    precacheImage(
      const AssetImage(MobileAuthConstants.welcomeBackgroundAsset),
      context,
    ),
  ]);
}
