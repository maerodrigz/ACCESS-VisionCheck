import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Maps API notification payloads to in-app [AppNotification] visuals + actions.
AppNotification appNotificationFromApi(Map<String, dynamic> n) {
  final category = (n['category'] as String? ?? 'system_alert').toLowerCase();
  final actionType = n['action_type'] as String?;
  final read = n['is_read'] as bool? ?? false;
  final visuals = notificationVisuals(
    category: category,
    actionType: actionType,
    read: read,
  );
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
    actionType: actionType,
    actionRefId: n['action_ref_id'] as int?,
    createdAt: _formatNotificationTime(iso),
    createdAtDt: dt,
  );
}

/// FCM / tray tap payload (merge with inbox row after sync when [notification_id] is set).
AppNotification appNotificationFromPushData(
  Map<String, dynamic> data, {
  required String title,
  required String body,
}) {
  final category = (data['category'] as String? ?? 'system_alert').toLowerCase();
  final actionType = data['action_type'] as String?;
  final idRaw = data['notification_id'];
  final refRaw = data['action_ref_id'];
  final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
  final refId = refRaw is int ? refRaw : int.tryParse('$refRaw');
  final visuals = notificationDetailVisuals(category: category, actionType: actionType);
  return AppNotification(
    id: id,
    title: title,
    body: body,
    icon: visuals.$1,
    color: visuals.$2,
    category: category,
    actionType: actionType,
    actionRefId: refId,
    read: false,
  );
}

AppNotification resolveNotificationForOpen(AppNotification stub) {
  if (stub.id > 0) {
    for (final n in appState.notifications) {
      if (n.id == stub.id) return n;
    }
  }
  return stub;
}

(String, IconData, Color) notificationPresentation(AppNotification n, {required bool requestor}) {
  final label = notificationCategoryLabel(n, requestor: requestor);
  final visuals = notificationVisuals(
    category: n.category,
    actionType: n.actionType,
    read: n.read,
  );
  return (label, visuals.$1, visuals.$2);
}

/// Detail dialog / floating card — always use semantic colors (not read-grey).
(String, IconData, Color) notificationDetailPresentation(AppNotification n, {required bool requestor}) {
  final label = notificationCategoryLabel(n, requestor: requestor);
  final visuals = notificationDetailVisuals(
    category: n.category,
    actionType: n.actionType,
  );
  return (label, visuals.$1, visuals.$2);
}

(IconData, Color) notificationDetailVisuals({
  required String category,
  required String? actionType,
}) {
  if (actionType == 'milestone') {
    return (Icons.emoji_events_rounded, kAccent);
  }
  if (actionType == 'view_admin_feedback') {
    return (Icons.admin_panel_settings_rounded, kCyan);
  }
  if (category == 'ai_detection') {
    return (Icons.notifications_active_rounded, kCyan);
  }
  return _visualsForCategory(category, read: false);
}

String notificationCategoryLabel(AppNotification n, {required bool requestor}) {
  if (n.actionType == 'milestone') return 'Milestone';
  if (n.actionType == 'view_admin_feedback') return 'Admin review';
  return switch (n.category) {
    'task_assignment' => 'Assignment',
    'documentation_request' => requestor ? 'Request update' : 'Documentation',
    'media_evaluation' => 'Evaluation',
    'ai_detection' => 'Integrity review',
    'feedback' => 'Feedback',
    'announcement' => 'Announcement',
    'system_alert' => 'Announcement',
    _ => 'Alert',
  };
}

(IconData, Color) notificationVisuals({
  required String category,
  required String? actionType,
  required bool read,
}) {
  if (read) return (Icons.notifications_outlined, kTextSecondary);
  if (actionType == 'milestone') {
    return (Icons.emoji_events_outlined, kAccent);
  }
  if (actionType == 'view_admin_feedback') {
    return (Icons.admin_panel_settings_outlined, kCyan);
  }
  return _visualsForCategory(category, read: read);
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
