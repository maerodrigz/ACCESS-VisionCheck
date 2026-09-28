import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Maps API notification payloads to in-app [AppNotification] visuals + actions.
AppNotification appNotificationFromApi(Map<String, dynamic> n) {
  final category = (n['category'] as String? ?? 'system_alert').toLowerCase();
  final read = n['is_read'] as bool? ?? false;
  final visuals = _visualsForCategory(category, read: read);
  final iso = n['created_at'] as String?;
  final dt = DateTime.tryParse(iso ?? '')?.toLocal();
  return AppNotification(
    id: n['id'] as int? ?? 0,
    title: n['title'] as String? ?? '',
    body: n['message'] as String? ?? '',
    icon: visuals.$1,
    color: visuals.$2,
    read: read,
    category: category,
    actionType: n['action_type'] as String?,
    actionRefId: n['action_ref_id'] as int?,
    createdAt: _formatNotificationTime(iso),
    createdAtDt: dt,
  );
}

String? _formatNotificationTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}

(IconData, Color) _visualsForCategory(String category, {required bool read}) {
  if (read) return (Icons.notifications_outlined, kTextSecondary);
  return switch (category) {
    'documentation_request' => (Icons.description_outlined, kAccent),
    'task_assignment' => (Icons.assignment_outlined, kPurple),
    'media_evaluation' => (Icons.verified_user_outlined, kCyan),
    'ai_detection' => (Icons.smart_toy_outlined, kYellow),
    'feedback' => (Icons.rate_review_outlined, kGreen),
    'announcement' => (Icons.campaign_outlined, kCyan),
    _ => (Icons.notifications_active_outlined, kAccent),
  };
}
