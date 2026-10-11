import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/gallery_screen.dart';
/// Requestor gallery — same polished album layout as members, read-only.
class RequestorGalleryScreen extends StatelessWidget {
  const RequestorGalleryScreen({
    super.key,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  void _openRequests() {
    RequestorShellNavigation.openRequests?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GalleryScreen(
      requestorMode: true,
      subtitle: 'Photos and videos from your documented events.',
      purposeBelowTitle: true,
      onViewRequests: _openRequests,
      onNotificationsTap: onNotificationsTap,
      onProfileTap: onProfileTap,
    );
  }
}
