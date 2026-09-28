import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/notifications/notification_models.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum NotificationModuleFilter {
  all,
  unread,
  requests,
  members,
  media,
  integrity,
  feedback,
  system;

  String get label => switch (this) {
        NotificationModuleFilter.all => 'All',
        NotificationModuleFilter.unread => 'Unread',
        NotificationModuleFilter.requests => 'Requests',
        NotificationModuleFilter.members => 'Members',
        NotificationModuleFilter.media => 'Media',
        NotificationModuleFilter.integrity => 'Integrity',
        NotificationModuleFilter.feedback => 'Feedback',
        NotificationModuleFilter.system => 'System',
      };
}

enum NotificationModule {
  requests,
  members,
  mediaLibrary,
  mediaIntegrity,
  competency,
  feedback,
  system;

  String get label => switch (this) {
        NotificationModule.requests => 'Documentation Requests',
        NotificationModule.members => 'Members',
        NotificationModule.mediaLibrary => 'Media Library',
        NotificationModule.mediaIntegrity => 'Media Integrity',
        NotificationModule.competency => 'Competency Management',
        NotificationModule.feedback => 'Requester Feedback',
        NotificationModule.system => 'System',
      };

  IconData get icon => switch (this) {
        NotificationModule.requests => Icons.description_outlined,
        NotificationModule.members => Icons.groups_outlined,
        NotificationModule.mediaLibrary => Icons.photo_library_outlined,
        NotificationModule.mediaIntegrity => Icons.verified_user_outlined,
        NotificationModule.competency => Icons.workspace_premium_outlined,
        NotificationModule.feedback => Icons.rate_review_outlined,
        NotificationModule.system => Icons.settings_suggest_outlined,
      };
}

enum NotificationDisplayPriority {
  information,
  success,
  warning,
  critical;

  String get label => switch (this) {
        NotificationDisplayPriority.information => 'Information',
        NotificationDisplayPriority.success => 'Success',
        NotificationDisplayPriority.warning => 'Warning',
        NotificationDisplayPriority.critical => 'Critical',
      };

  Color get color => switch (this) {
        NotificationDisplayPriority.information => AdminTheme.accentBlue,
        NotificationDisplayPriority.success => AdminTheme.success,
        NotificationDisplayPriority.warning => AdminTheme.warning,
        NotificationDisplayPriority.critical => AdminTheme.danger,
      };

  IconData get icon => switch (this) {
        NotificationDisplayPriority.information => Icons.info_outline,
        NotificationDisplayPriority.success => Icons.check_circle_outline,
        NotificationDisplayPriority.warning => Icons.warning_amber_rounded,
        NotificationDisplayPriority.critical => Icons.error_outline,
      };
}

enum NotificationTimelineGroup {
  today,
  yesterday,
  earlier;

  String get label => switch (this) {
        NotificationTimelineGroup.today => 'Today',
        NotificationTimelineGroup.yesterday => 'Yesterday',
        NotificationTimelineGroup.earlier => 'Earlier',
      };
}

class NotificationCenterStats {
  const NotificationCenterStats({
    required this.unread,
    required this.today,
    required this.highPriority,
    required this.system,
  });

  final int unread;
  final int today;
  final int highPriority;
  final int system;
}

class CenterNotificationItem {
  const CenterNotificationItem({
    required this.source,
    required this.module,
    required this.displayPriority,
    required this.requiresAction,
    required this.actionLabel,
    required this.route,
    required this.timelineGroup,
  });

  final AdminNotificationItem source;
  final NotificationModule module;
  final NotificationDisplayPriority displayPriority;
  final bool requiresAction;
  final String actionLabel;
  final AdminRoute route;
  final NotificationTimelineGroup timelineGroup;

  int get id => source.id;
  String get title => source.title;
  String get message => source.message;
  bool get unread => source.unread;
  DateTime? get createdAt => source.createdAt;
  String get timeLabel => formatNotificationDateTime(source.createdAt);

  bool matchesFilter(NotificationModuleFilter filter) {
    return switch (filter) {
      NotificationModuleFilter.all => true,
      NotificationModuleFilter.unread => unread,
      NotificationModuleFilter.requests => module == NotificationModule.requests,
      NotificationModuleFilter.members => module == NotificationModule.members,
      NotificationModuleFilter.media => module == NotificationModule.mediaLibrary,
      NotificationModuleFilter.integrity => module == NotificationModule.mediaIntegrity,
      NotificationModuleFilter.feedback => module == NotificationModule.feedback,
      NotificationModuleFilter.system => module == NotificationModule.system,
    };
  }

  bool matchesSearch(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        message.toLowerCase().contains(q) ||
        module.label.toLowerCase().contains(q) ||
        displayPriority.label.toLowerCase().contains(q) ||
        timeLabel.toLowerCase().contains(q);
  }
}

class NotificationCenterData {
  const NotificationCenterData({
    required this.all,
    required this.stats,
  });

  final List<CenterNotificationItem> all;
  final NotificationCenterStats stats;

  List<CenterNotificationItem> get actionRequired => all.where((n) => n.requiresAction).toList();

  List<CenterNotificationItem> get recentActivity => all.where((n) => !n.requiresAction).toList();
}

String formatNotificationDateTime(DateTime? dt) {
  if (dt == null) return 'Recently';
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ap = local.hour >= 12 ? 'PM' : 'AM';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $h:$m $ap';
}

NotificationTimelineGroup timelineGroupFor(DateTime? dt) {
  if (dt == null) return NotificationTimelineGroup.earlier;
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return NotificationTimelineGroup.today;
  if (diff == 1) return NotificationTimelineGroup.yesterday;
  return NotificationTimelineGroup.earlier;
}
