import 'package:flutter/material.dart';

import 'package:access_mobile/shared/themes/theme.dart';

/// Semantic icon colors for requestor list/detail/calendar meta rows.
Color requestorMetaIconColor(IconData icon, {bool muted = false}) {
  if (muted) return kIconInactive;
  return switch (icon) {
    Icons.event_rounded ||
    Icons.calendar_month_rounded ||
    Icons.calendar_today_outlined ||
    Icons.event_note_rounded ||
    Icons.event_available_rounded ||
    Icons.description_outlined =>
      kAccent,
    Icons.schedule_rounded || Icons.schedule_outlined => kYellow,
    Icons.location_on_outlined || Icons.location_on_rounded => kCyan,
    Icons.groups_outlined || Icons.groups_rounded => kGreen,
    Icons.info_outline_rounded || Icons.info_outlined => kYellow,
    Icons.notes_rounded || Icons.assignment_outlined => kAccent,
    Icons.tips_and_updates_outlined || Icons.lightbulb_outline_rounded => kYellow,
    Icons.photo_camera_outlined ||
    Icons.photo_camera_rounded ||
    Icons.photo_library_outlined ||
    Icons.photo_library_rounded =>
      kAccent,
    Icons.videocam_outlined || Icons.videocam_rounded => kCyan,
    Icons.rate_review_outlined => kAccent,
    _ => kAccent,
  };
}
