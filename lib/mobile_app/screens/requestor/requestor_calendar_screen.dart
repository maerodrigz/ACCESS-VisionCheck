import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/screens/calendar_screen.dart';

/// Requestor calendar — same UI as the member calendar, with requestor filters
/// and plan-request actions.
class RequestorCalendarScreen extends StatelessWidget {
  const RequestorCalendarScreen({
    super.key,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onPlanRequest,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  /// Opens the create-request form with the selected day pre-filled.
  final void Function(DateTime day)? onPlanRequest;

  @override
  Widget build(BuildContext context) {
    return CalendarScreen(
      forRequestor: true,
      onProfileTap: onProfileTap,
      onPlanRequest: onPlanRequest,
    );
  }
}
