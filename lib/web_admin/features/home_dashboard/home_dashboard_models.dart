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

/// One day's evaluation count breakdown for the trend chart.
class EvaluationTrendPoint {
  const EvaluationTrendPoint({
    required this.dateLabel,
    required this.evaluated,
    required this.goodQuality,
    required this.needsImprovement,
    required this.aiFlagged,
  });

  final String dateLabel;
  final int evaluated;
  final int goodQuality;
  final int needsImprovement;
  final int aiFlagged;
}

/// Aggregated evaluation stats shown in the Media Evaluation Overview panel.
class EvalOverviewStats {
  const EvalOverviewStats({
    required this.evaluated,
    required this.goodQuality,
    required this.needsImprovement,
    required this.aiFlagged,
    required this.evaluatedTrend,
    required this.goodQualityTrend,
    required this.needsImprovementTrend,
    required this.aiFlaggedTrend,
  });

  final int evaluated;
  final int goodQuality;
  final int needsImprovement;
  final int aiFlagged;
  /// Percentage change vs previous period (positive = up, negative = down).
  final double evaluatedTrend;
  final double goodQualityTrend;
  final double needsImprovementTrend;
  final double aiFlaggedTrend;

  static const zero = EvalOverviewStats(
    evaluated: 0, goodQuality: 0, needsImprovement: 0, aiFlagged: 0,
    evaluatedTrend: 0, goodQualityTrend: 0, needsImprovementTrend: 0, aiFlaggedTrend: 0,
  );
}

/// Competency breakdown for the Active Documenters panel.
class CompetencyBreakdown {
  const CompetencyBreakdown({
    required this.label,
    required this.count,
    required this.percent,
  });

  final String label;
  final int count;
  final double percent;
}

class ActiveDocumenterSnapshot {
  const ActiveDocumenterSnapshot({
    required this.totalActive,
    required this.breakdown,
  });

  final int totalActive;
  final List<CompetencyBreakdown> breakdown;

  static const zero = ActiveDocumenterSnapshot(totalActive: 0, breakdown: []);
}

/// Action center item (replaces PendingRequestItem for the new panel).
class ActionCenterItem {
  const ActionCenterItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.kind, // 'request' | 'integrity' | 'media'
    required this.count,
  });

  final int id;
  final String title;
  final String subtitle;
  final String timeLabel;
  final String kind;
  final int count;
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
    this.location,
    this.documenterCount = 0,
  });

  final String timeLabel;
  final String eventName;
  final String assignedMembers;
  final String status;
  final String? location;
  final int documenterCount;
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
    this.evalOverview = EvalOverviewStats.zero,
    this.evalTrend = const [],
    this.activeDocumenters = ActiveDocumenterSnapshot.zero,
    this.actionCenterItems = const [],
  });

  final HomeOverviewStats overview;
  final List<PendingRequestItem> pendingRequests;
  final List<TodayScheduleItem> todaySchedule;
  final List<AdminActivityItem> recentActivity;
  final List<AdminNotificationItem> notifications;
  final MediaQueueSnapshot mediaQueue;
  final List<AnnouncementItem> announcements;
  final int pendingMembers;
  final EvalOverviewStats evalOverview;
  final List<EvaluationTrendPoint> evalTrend;
  final ActiveDocumenterSnapshot activeDocumenters;
  final List<ActionCenterItem> actionCenterItems;
}
