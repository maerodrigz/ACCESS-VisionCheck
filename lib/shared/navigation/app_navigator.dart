import 'package:flutter/material.dart';

/// Root [MaterialApp] navigator — used to return to sign-in after logout.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void popToAppRoot() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  });
}
