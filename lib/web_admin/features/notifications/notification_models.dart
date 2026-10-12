import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum NotificationCategory {
  documentationRequest,
  taskAssignment,
  mediaEvaluation,
  aiDetection,
  feedback,
  systemAlert,
}

enum NotificationPriority { high, normal, low }

enum NotificationFilterTab { all, unread, requests, mediaEvaluation, aiAlerts }

class AdminNotificationItem {
  const AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.createdAt,
    this.unread = true,
    this.category = NotificationCategory.systemAlert,
    this.priority = NotificationPriority.normal,
    this.actionType,
    this.actionRefId,
    this.route,
  });

  final int id;
  final String title;
  final String message;
  final String timeAgo;
  final DateTime? createdAt;
  final bool unread;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String? actionType;
  final int? actionRefId;
  final AdminRoute? route;

  String get priorityLabel => switch (priority) {
        NotificationPriority.high => 'High',
        NotificationPriority.normal => 'Normal',
        NotificationPriority.low => 'Low',
      };

  String get categoryLabel => switch (category) {
        NotificationCategory.documentationRequest => 'Documentation Request',
        NotificationCategory.taskAssignment => 'Task Assignment',
        NotificationCategory.mediaEvaluation => 'Media Integrity',
        NotificationCategory.aiDetection => 'AI Detection',
        NotificationCategory.feedback => 'Requester Feedback',
        NotificationCategory.systemAlert => 'System Alert',
      };

  String? get actionButtonLabel => switch (actionType) {
        'view_request' => 'View Request',
        'review_media' => 'Review Media',
        'view_result' => 'View Result',
        'view_task' => 'View Task',
        'view_feedback' => 'View Feedback',
        _ => null,
      };

  IconData get icon => switch (category) {
        NotificationCategory.documentationRequest => Icons.description_outlined,
        NotificationCategory.taskAssignment => Icons.assignment_outlined,
        NotificationCategory.mediaEvaluation => Icons.verified_user_outlined,
        NotificationCategory.aiDetection => Icons.smart_toy_outlined,
        NotificationCategory.feedback => Icons.rate_review_outlined,
        NotificationCategory.systemAlert => Icons.info_outline,
      };

  Color get accentColor => switch (category) {
        NotificationCategory.documentationRequest => AdminTheme.accentBlue,
        NotificationCategory.taskAssignment => const Color(0xFF7C3AED),
        NotificationCategory.mediaEvaluation => AdminTheme.accentCyan,
        NotificationCategory.aiDetection => const Color(0xFFEA580C),
        NotificationCategory.feedback => const Color(0xFF059669),
        NotificationCategory.systemAlert => AdminTheme.textSecondary,
      };

  bool matchesFilter(NotificationFilterTab tab) {
    return switch (tab) {
      NotificationFilterTab.all => true,
      NotificationFilterTab.unread => unread,
      NotificationFilterTab.requests => category == NotificationCategory.documentationRequest,
      NotificationFilterTab.mediaEvaluation =>
        category == NotificationCategory.mediaEvaluation,
      NotificationFilterTab.aiAlerts =>
        category == NotificationCategory.aiDetection,
    };
  }

  factory AdminNotificationItem.fromMap(Map<String, dynamic> m) {
    return AdminNotificationItem(
      id: m['id'] as int? ?? -1,
      title: m['title'] as String? ?? 'Notification',
      message: m['message'] as String? ?? m['body'] as String? ?? '',
      timeAgo: formatTimeAgo(m['created_at']),
      createdAt: DateTime.tryParse(m['created_at']?.toString() ?? ''),
      unread: m['is_read'] != true,
      category: categoryFromString(m['category'] as String?),
      priority: priorityFromString(m['priority'] as String?),
      actionType: m['action_type'] as String?,
      actionRefId: m['action_ref_id'] as int?,
      route: routeForAction(m['action_type'] as String?, m['category'] as String?),
    );
  }
}

NotificationCategory categoryFromString(String? raw) {
  return switch (raw?.toLowerCase()) {
    'documentation_request' => NotificationCategory.documentationRequest,
    'task_assignment' => NotificationCategory.taskAssignment,
    'media_evaluation' => NotificationCategory.mediaEvaluation,
    'ai_detection' => NotificationCategory.aiDetection,
    'feedback' => NotificationCategory.feedback,
    _ => NotificationCategory.systemAlert,
  };
}

NotificationPriority priorityFromString(String? raw) {
  return switch (raw?.toLowerCase()) {
    'high' => NotificationPriority.high,
    'low' => NotificationPriority.low,
    _ => NotificationPriority.normal,
  };
}

AdminRoute? routeForAction(String? actionType, String? category) {
  return switch (actionType) {
    'view_request' => AdminRoute.docRequests,
    'review_media' => AdminRoute.aiDetection,
    'view_task' => AdminRoute.docRequests,
    'view_feedback' => AdminRoute.feedbackReports,
    'view_result' => AdminRoute.notifications,
    'milestone' => AdminRoute.notifications,
    'view_admin_feedback' => AdminRoute.notifications,
    _ => switch (categoryFromString(category)) {
        NotificationCategory.documentationRequest => AdminRoute.docRequests,
        NotificationCategory.taskAssignment => AdminRoute.docRequests,
        NotificationCategory.mediaEvaluation => AdminRoute.aiDetection,
        NotificationCategory.aiDetection => AdminRoute.aiDetection,
        NotificationCategory.feedback => AdminRoute.feedbackReports,
        _ => AdminRoute.notifications,
      },
  };
}

String formatTimeAgo(dynamic raw) {
  if (raw == null) return 'Recently';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  } catch (_) {
    return 'Recently';
  }
}
