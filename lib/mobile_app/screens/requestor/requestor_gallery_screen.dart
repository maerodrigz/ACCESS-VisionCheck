import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/gallery_screen.dart';
import 'package:access_mobile/shared/models/request_status.dart';

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
    RequestorShellNavigation.openRequests?.call(filter: RequestStatus.approved);
  }

  @override
  Widget build(BuildContext context) {
    return GalleryScreen(
      requestorMode: true,
      subtitle:
          'Browse approved photos and videos from your organization\'s documented events.',
      onViewRequests: _openRequests,
      onNotificationsTap: onNotificationsTap,
      onProfileTap: onProfileTap,
    );
  }
}
