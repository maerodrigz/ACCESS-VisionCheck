import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

ThemeData _mobileAuthRouteTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    scaffoldBackgroundColor: MobileAuthConstants.midnightScaffoldColor,
    canvasColor: MobileAuthConstants.midnightScaffoldColor,
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: kSurface,
    ),
  );
}

/// Auth stack routes: opaque midnight shell, no slide/fade (avoids background scale shift).
Future<T?> pushMobileAuthPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: true,
      barrierColor: MobileAuthConstants.midnightScaffoldColor,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Theme(
          data: _mobileAuthRouteTheme(context),
          child: ColoredBox(
            color: MobileAuthConstants.midnightScaffoldColor,
            child: page,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}
