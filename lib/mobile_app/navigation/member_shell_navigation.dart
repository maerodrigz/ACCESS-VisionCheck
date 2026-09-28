import 'package:flutter/foundation.dart';

/// Static hooks for navigating within the member [MainShell] from notifications
/// and other screens that sit outside the shell widget tree.
class MemberShellNavigation {
  MemberShellNavigation._();

  static void Function({int? requestId})? openGallery;
  static VoidCallback? openHome;

  static void clear() {
    openGallery = null;
    openHome = null;
  }
}
