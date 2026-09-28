import 'package:access_mobile/web_admin/features/notifications/notification_models.dart';
import 'package:access_mobile/web_admin/widgets/admin_activity_timeline.dart';

class HomeOverviewStats {
  const HomeOverviewStats({
    required this.pendingRequests,
    required this.todayEvents,
    required this.mediaPendingEvaluation,
    required this.activeMembers,
    required this.unreadNotifications,
  });

  final int pendingRequests;
  final int todayEvents;
  final int mediaPendingEvaluation;
  final int activeMembers;
  final int unreadNotifications;
}

class PendingRequestItem {
  const PendingRequestItem({
    required this.id,
    required this.eventTitle,
    required this.requestor,
    required this.requestedDate,
    required this.status,
  });

  final int id;
  final String eventTitle;
  final String requestor;
  final String requestedDate;
  final String status;
}

class TodayScheduleItem {
  const TodayScheduleItem({
    required this.timeLabel,
    required this.eventName,
    required this.assignedMembers,
    required this.status,
  });

  final String timeLabel;
  final String eventName;
  final String assignedMembers;
  final String status;
}

class MediaQueueSnapshot {
  const MediaQueueSnapshot({
    required this.pendingCount,
    required this.completedToday,
  });

  final int pendingCount;
  final int completedToday;
}

class AnnouncementItem {
  const AnnouncementItem({
    required this.title,
    required this.body,
    required this.dateLabel,
  });

  final String title;
  final String body;
  final String dateLabel;
}

class HomeDashboardSnapshot {
  const HomeDashboardSnapshot({
    required this.overview,
    required this.pendingRequests,
    required this.todaySchedule,
    required this.recentActivity,
    required this.notifications,
    required this.mediaQueue,
    required this.announcements,
    required this.pendingMembers,
  });

  final HomeOverviewStats overview;
  final List<PendingRequestItem> pendingRequests;
  final List<TodayScheduleItem> todaySchedule;
  final List<AdminActivityItem> recentActivity;
  final List<AdminNotificationItem> notifications;
  final MediaQueueSnapshot mediaQueue;
  final List<AnnouncementItem> announcements;
  final int pendingMembers;
}
