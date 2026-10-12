import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_notification_detail_dialog.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Full admin message from a push/in-app notification (before or beside evaluation report).
void showAdminReviewNoticeSheet(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? onViewEvaluation,
}) {
  final body = message.trim();
  if (body.isEmpty && onViewEvaluation == null) return;

  showMemberNotificationFloatingCard(
    context,
    title: title.trim().isEmpty ? 'Administrator message' : title.trim(),
    message: body,
    categoryLabel: 'Admin review',
    icon: Icons.admin_panel_settings_outlined,
    accent: kAccent,
    primaryActionLabel: onViewEvaluation != null ? 'View evaluation' : null,
  ).then((open) {
    if (open && onViewEvaluation != null) {
      onViewEvaluation();
    }
  });
}

/// Prefer text after "Remarks:" from notification body when API remarks are not synced yet.
String adminRemarksFromNotificationFallback(String? notificationBody) {
  final body = notificationBody?.trim() ?? '';
  if (body.isEmpty) return '';
  final lower = body.toLowerCase();
  const marker = 'remarks:';
  final idx = lower.indexOf(marker);
  if (idx >= 0) {
    return body.substring(idx + marker.length).trim();
  }
  return body;
}
