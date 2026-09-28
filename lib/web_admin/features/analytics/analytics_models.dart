import 'package:access_mobile/shared/api/admin_api_service.dart';

/// Snapshot loaded once for all analytics tabs.
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.stats,
    required this.rankings,
    required this.rankingsSummary,
    required this.events,
    required this.feedback,
    required this.media,
    required this.requests,
    required this.evaluations,
    required this.evaluationSummary,
    required this.aiSummary,
  });

  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> rankings;
  final Map<String, dynamic> rankingsSummary;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> feedback;
  final List<Map<String, dynamic>> media;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> evaluations;
  final Map<String, dynamic> evaluationSummary;
  final Map<String, dynamic> aiSummary;

  static Future<AnalyticsSnapshot> fetch() async {
    Map<String, dynamic> evalSummary = {};
    Map<String, dynamic> aiSum = {};
    try {
      evalSummary = await adminApi.evaluationSummary();
    } catch (_) {}
    try {
      aiSum = await adminApi.aiDetectionSummary();
    } catch (_) {}

    final results = await Future.wait([
      adminApi.dashboardStats(),
      adminApi.rankings(),
      adminApi.rankingsSummary(),
      adminApi.allEvents(),
      adminApi.allFeedback(),
      adminApi.allMedia(),
      adminApi.allServiceRequests(),
      adminApi.allEvaluations(),
    ]);

    return AnalyticsSnapshot(
      stats: Map<String, dynamic>.from(results[0] as Map),
      rankings: (results[1] as List).cast<Map<String, dynamic>>(),
      rankingsSummary: Map<String, dynamic>.from(results[2] as Map),
      events: (results[3] as List).cast<Map<String, dynamic>>(),
      feedback: (results[4] as List).cast<Map<String, dynamic>>(),
      media: (results[5] as List).cast<Map<String, dynamic>>(),
      requests: (results[6] as List).cast<Map<String, dynamic>>(),
      evaluations: (results[7] as List).cast<Map<String, dynamic>>(),
      evaluationSummary: evalSummary,
      aiSummary: aiSum,
    );
  }

  double get avgFeedbackRating {
    final v = stats['avg_feedback_rating'];
    if (v == null) return 0;
    return (v as num).toDouble();
  }
}

enum AnalyticsTab { overview, participation, events, rankings, feedback, media }

String analyticsTabLabel(AnalyticsTab tab) => switch (tab) {
      AnalyticsTab.overview => 'Overview',
      AnalyticsTab.participation => 'Participation',
      AnalyticsTab.events => 'Events',
      AnalyticsTab.rankings => 'Rankings',
      AnalyticsTab.feedback => 'Feedback',
      AnalyticsTab.media => 'Media',
    };

AnalyticsTab analyticsTabFromString(String? raw) => switch (raw) {
      'participation' => AnalyticsTab.participation,
      'events' => AnalyticsTab.events,
      'rankings' => AnalyticsTab.rankings,
      'feedback' => AnalyticsTab.feedback,
      'media' => AnalyticsTab.media,
      _ => AnalyticsTab.overview,
    };
