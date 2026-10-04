import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/notifications/notification_models.dart';
import 'package:access_mobile/web_admin/widgets/admin_activity_timeline.dart';

Future<HomeDashboardSnapshot> fetchHomeDashboard() async {
  final stats = await adminApi.dashboardStats();
  final requests = await adminApi.allServiceRequests();
  final events = await adminApi.allEvents();
  final evaluations = await adminApi.allEvaluations();
  final media = await adminApi.allMedia();
  final notifications = await adminApi.myNotifications();
  final tasks = await adminApi.allTasks();
  final rankings = await adminApi.rankings();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // ── Pending requests ──────────────────────────────────────────────────────
  final pendingRequests = requests
      .where((r) => (r['status'] as String? ?? 'Pending').toLowerCase() == 'pending')
      .map(_mapPendingRequest)
      .toList()
    ..sort((a, b) => b.requestedDate.compareTo(a.requestedDate));

  // ── Today events ──────────────────────────────────────────────────────────
  final todayEvents = events.where((e) {
    final d = _parseDate(e['event_date']);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (day != today) return false;
    final status = (e['status'] as String? ?? '').toLowerCase();
    return status != 'cancelled' && status != 'canceled';
  }).map((e) => _mapTodayEvent(e, tasks)).toList()
    ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));

  // ── Media queue ───────────────────────────────────────────────────────────
  final evaluatedMediaIds = evaluations.map((e) => e['media_id'] as int?).whereType<int>().toSet();
  final pendingMedia = media.where((m) {
    final id = m['id'] as int?;
    return id != null && !evaluatedMediaIds.contains(id);
  }).length;

  final completedToday = evaluations.where((e) {
    final d = _parseDate(e['evaluated_at'] ?? e['created_at']);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return day == today;
  }).length;

  // ── Notifications ─────────────────────────────────────────────────────────
  final notifItems = notifications.map(AdminNotificationItem.fromMap).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

  final unread = notifItems.where((n) => n.unread).length;

  // ── Eval overview + trend (last 7 days) ───────────────────────────────────
  final evalOverview = _buildEvalOverview(evaluations, today);
  final evalTrend = _buildEvalTrend(evaluations, today);

  // ── Active documenters breakdown ──────────────────────────────────────────
  final activeDocumenters = _buildActiveDocumenters(rankings, stats);

  // ── Action center items ───────────────────────────────────────────────────
  final actionItems = _buildActionCenterItems(
    pendingRequests: pendingRequests,
    pendingMedia: pendingMedia,
    evaluations: evaluations,
    media: media,
  );

  return HomeDashboardSnapshot(
    overview: HomeOverviewStats(
      pendingRequests: stats['pending_requests'] as int? ?? pendingRequests.length,
      todayEvents: todayEvents.length,
      mediaPendingEvaluation: pendingMedia,
      activeMembers: stats['active_members'] as int? ?? 0,
      unreadNotifications: unread,
    ),
    pendingRequests: pendingRequests.take(6).toList(),
    todaySchedule: todayEvents.take(5).toList(),
    recentActivity: _buildRecentActivity(requests, media, evaluations, notifications),
    notifications: notifItems.take(5).toList(),
    mediaQueue: MediaQueueSnapshot(
      pendingCount: pendingMedia,
      completedToday: completedToday,
    ),
    announcements: _buildAnnouncements(notifItems),
    pendingMembers: stats['pending_members'] as int? ?? 0,
    evalOverview: evalOverview,
    evalTrend: evalTrend,
    activeDocumenters: activeDocumenters,
    actionCenterItems: actionItems,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

PendingRequestItem _mapPendingRequest(Map<String, dynamic> r) {
  return PendingRequestItem(
    id: r['request_id'] as int? ?? r['id'] as int? ?? 0,
    eventTitle: r['event_name'] as String? ?? r['title'] as String? ?? 'Documentation request',
    requestor: r['requester_name'] as String? ?? r['organization_name'] as String? ?? 'Unknown',
    requestedDate: _formatDate(r['created_at']),
    status: (r['status'] as String? ?? 'Pending').toString(),
  );
}

TodayScheduleItem _mapTodayEvent(Map<String, dynamic> e, List<Map<String, dynamic>> tasks) {
  final eventId = e['id'] as int?;
  final assigned = tasks
      .where((t) => t['event_id'] == eventId)
      .map((t) => t['member_name'] as String? ?? t['assignee_name'] as String? ?? '')
      .where((n) => n.isNotEmpty)
      .toList();

  final start = e['start_time'] as String? ?? e['event_time'] as String?;
  final timeLabel = start != null && start.isNotEmpty ? _formatTime(start) : 'All day';

  return TodayScheduleItem(
    timeLabel: timeLabel,
    eventName: e['title'] as String? ?? e['event_name'] as String? ?? 'Event',
    assignedMembers: assigned.isEmpty ? 'Unassigned' : assigned.join(', '),
    status: _titleCase((e['status'] as String? ?? 'Upcoming').replaceAll('_', ' ')),
    location: e['location'] as String? ?? e['venue'] as String?,
    documenterCount: assigned.length,
  );
}

// ── Eval overview ─────────────────────────────────────────────────────────────

EvalOverviewStats _buildEvalOverview(
  List<Map<String, dynamic>> evaluations,
  DateTime today,
) {
  final last7Start = today.subtract(const Duration(days: 7));
  final prev7Start = today.subtract(const Duration(days: 14));

  int evalCurrent = 0, goodCurrent = 0, needsCurrent = 0, aiCurrent = 0;
  int evalPrev = 0, goodPrev = 0, needsPrev = 0, aiPrev = 0;

  for (final e in evaluations) {
    final d = _parseDate(e['evaluated_at'] ?? e['created_at']);
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);

    final score = ((e['overall_score'] as num?)?.toDouble() ?? 0.0);
    final detection = (e['detection_result'] as String? ?? '').toLowerCase();
    final isFlagged = detection == 'ai_generated' || detection == 'suspicious';
    final isGood = !isFlagged && score >= 0.75;
    final isNeeds = !isFlagged && score < 0.75;

    if (!day.isBefore(last7Start) && day.isBefore(today.add(const Duration(days: 1)))) {
      evalCurrent++;
      if (isFlagged) { aiCurrent++; }
      else if (isGood) { goodCurrent++; }
      else if (isNeeds) { needsCurrent++; }
    } else if (!day.isBefore(prev7Start) && day.isBefore(last7Start)) {
      evalPrev++;
      if (isFlagged) { aiPrev++; }
      else if (isGood) { goodPrev++; }
      else if (isNeeds) { needsPrev++; }
    }
  }

  double trend(int curr, int prev) {
    if (prev == 0) return curr > 0 ? 100.0 : 0.0;
    return ((curr - prev) / prev * 100).roundToDouble();
  }

  return EvalOverviewStats(
    evaluated: evalCurrent,
    goodQuality: goodCurrent,
    needsImprovement: needsCurrent,
    aiFlagged: aiCurrent,
    evaluatedTrend: trend(evalCurrent, evalPrev),
    goodQualityTrend: trend(goodCurrent, goodPrev),
    needsImprovementTrend: trend(needsCurrent, needsPrev),
    aiFlaggedTrend: trend(aiCurrent, aiPrev),
  );
}

// ── Eval trend (last 7 days) ──────────────────────────────────────────────────

List<EvaluationTrendPoint> _buildEvalTrend(
  List<Map<String, dynamic>> evaluations,
  DateTime today,
) {
  const days = 7;
  final points = <EvaluationTrendPoint>[];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  for (var i = days - 1; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final label = '${months[dayStart.month - 1]} ${dayStart.day}';

    int evaluated = 0, good = 0, needs = 0, ai = 0;
    for (final e in evaluations) {
      final d = _parseDate(e['evaluated_at'] ?? e['created_at']);
      if (d == null) continue;
      if (d.isBefore(dayStart) || !d.isBefore(dayEnd)) continue;

      final score = ((e['overall_score'] as num?)?.toDouble() ?? 0.0);
      final detection = (e['detection_result'] as String? ?? '').toLowerCase();
      final isFlagged = detection == 'ai_generated' || detection == 'suspicious';

      evaluated++;
      if (isFlagged) { ai++; }
      else if (score >= 0.75) { good++; }
      else { needs++; }
    }

    points.add(EvaluationTrendPoint(
      dateLabel: label,
      evaluated: evaluated,
      goodQuality: good,
      needsImprovement: needs,
      aiFlagged: ai,
    ));
  }
  return points;
}

// ── Active documenters ────────────────────────────────────────────────────────

ActiveDocumenterSnapshot _buildActiveDocumenters(
  List<Map<String, dynamic>> rankings,
  Map<String, dynamic> stats,
) {
  int advanced = 0, developing = 0, amateur = 0;

  for (final r in rankings) {
    final level = (r['skill_level'] as String? ?? r['competency_level'] as String? ?? '').toLowerCase();
    if (level.contains('advanced') || level.contains('expert')) { advanced++; }
    else if (level.contains('developing') || level.contains('intermediate')) { developing++; }
    else { amateur++; }
  }

  final total = advanced + developing + amateur;
  if (total == 0) {
    final active = stats['active_members'] as int? ?? 0;
    return ActiveDocumenterSnapshot(
      totalActive: active,
      breakdown: active == 0 ? [] : [
        CompetencyBreakdown(label: 'Advanced', count: 0, percent: 0),
        CompetencyBreakdown(label: 'Developing', count: 0, percent: 0),
        CompetencyBreakdown(label: 'Amateur', count: active, percent: 100),
      ],
    );
  }

  pct(int n) => total > 0 ? (n / total * 100).roundToDouble() : 0.0;

  return ActiveDocumenterSnapshot(
    totalActive: total,
    breakdown: [
      CompetencyBreakdown(label: 'Advanced', count: advanced, percent: pct(advanced)),
      CompetencyBreakdown(label: 'Developing', count: developing, percent: pct(developing)),
      CompetencyBreakdown(label: 'Amateur', count: amateur, percent: pct(amateur)),
    ],
  );
}

// ── Action center items ───────────────────────────────────────────────────────

List<ActionCenterItem> _buildActionCenterItems({
  required List<PendingRequestItem> pendingRequests,
  required int pendingMedia,
  required List<Map<String, dynamic>> evaluations,
  required List<Map<String, dynamic>> media,
}) {
  final items = <ActionCenterItem>[];

  // 1. Pending documentation requests
  if (pendingRequests.isNotEmpty) {
    final org = pendingRequests.first.requestor;
    items.add(ActionCenterItem(
      id: pendingRequests.first.id,
      title: '${pendingRequests.length} documentation request${pendingRequests.length == 1 ? '' : 's'} need${pendingRequests.length == 1 ? 's' : ''} approval',
      subtitle: 'New request from $org',
      timeLabel: 'Just now',
      kind: 'request',
      count: pendingRequests.length,
    ));
  }

  // 2. Media integrity flags
  final flaggedCount = evaluations.where((e) {
    final d = (e['detection_result'] as String? ?? '').toLowerCase();
    return d == 'suspicious' || d == 'ai_generated';
  }).length + media.where((m) {
    final d = (m['detection_result'] as String? ?? m['ai_result'] as String? ?? '').toLowerCase();
    return d == 'suspicious' || d == 'ai_generated';
  }).length;

  if (flaggedCount > 0) {
    items.add(ActionCenterItem(
      id: -1,
      title: '$flaggedCount media item${flaggedCount == 1 ? '' : 's'} flagged for integrity review',
      subtitle: 'Suspicious content detected by AI',
      timeLabel: '10 minutes ago',
      kind: 'integrity',
      count: flaggedCount,
    ));
  }

  // 3. Media awaiting evaluation
  if (pendingMedia > 0) {
    items.add(ActionCenterItem(
      id: -2,
      title: '$pendingMedia media item${pendingMedia == 1 ? '' : 's'} awaiting evaluation',
      subtitle: 'Recently uploaded by team members',
      timeLabel: '1 hour ago',
      kind: 'media',
      count: pendingMedia,
    ));
  }

  return items;
}

// ── Recent activity (unchanged) ───────────────────────────────────────────────

List<AdminActivityItem> _buildRecentActivity(
  List<Map<String, dynamic>> requests,
  List<Map<String, dynamic>> media,
  List<Map<String, dynamic>> evaluations,
  List<Map<String, dynamic>> notifications,
) {
  final items = <({DateTime? date, AdminActivityItem item})>[];

  for (final r in requests) {
    final d = _parseDate(r['created_at']);
    final status = (r['status'] as String? ?? 'Pending').toString();
    items.add((
      date: d,
      item: AdminActivityItem(
        kind: 'request',
        title: _activityTitleForRequest(status, r),
        subtitle: r['requester_name'] as String? ?? '',
        status: status,
        time: formatTimeAgo(r['created_at']),
      ),
    ));
  }

  for (final n in notifications.take(20)) {
    final d = _parseDate(n['created_at']);
    final cat = (n['category'] as String? ?? '').toLowerCase();
    final title = n['title'] as String? ?? 'Notification';
    if (cat == 'ai_detection') {
      items.add((
        date: d,
        item: AdminActivityItem(
          kind: 'media',
          title: title,
          subtitle: n['message'] as String? ?? n['body'] as String? ?? '',
          status: 'Integrity',
          time: formatTimeAgo(n['created_at']),
        ),
      ));
      continue;
    }
    if (cat == 'documentation_request' || cat == 'task_assignment' || cat == 'feedback') {
      items.add((
        date: d,
        item: AdminActivityItem(
          kind: cat == 'documentation_request' ? 'request' : 'media',
          title: title,
          subtitle: n['message'] as String? ?? n['body'] as String? ?? '',
          status: _titleCase(cat.replaceAll('_', ' ')),
          time: formatTimeAgo(n['created_at']),
        ),
      ));
      continue;
    }
    if (cat.contains('facebook') || title.toLowerCase().contains('facebook')) {
      items.add((
        date: d,
        item: AdminActivityItem(
          kind: 'media',
          title: title,
          subtitle: n['message'] as String? ?? n['body'] as String? ?? '',
          status: 'Published',
          time: formatTimeAgo(n['created_at']),
        ),
      ));
    }
  }

  items.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
  return items.take(8).map((e) => e.item).toList();
}

String _activityTitleForRequest(String status, Map<String, dynamic> r) {
  final title = r['event_name'] as String? ?? r['title'] as String? ?? 'Documentation request';
  final s = status.toLowerCase();
  if (s.contains('approv')) return 'Request approved: $title';
  if (s.contains('reject')) return 'Request rejected: $title';
  return 'New request: $title';
}

List<AnnouncementItem> _buildAnnouncements(List<AdminNotificationItem> notifications) {
  final system = notifications
      .where((n) => n.category == NotificationCategory.systemAlert || n.title.toLowerCase().contains('announce'))
      .take(3)
      .map((n) => AnnouncementItem(title: n.title, body: n.message, dateLabel: n.timeAgo))
      .toList();

  if (system.isNotEmpty) return system;

  return const [
    AnnouncementItem(
      title: 'Welcome to ACCESS VisionCheck',
      body: 'Review pending documentation requests daily and assign members before event dates.',
      dateLabel: 'System',
    ),
    AnnouncementItem(
      title: 'Media integrity reminder',
      body: 'Potentially AI-generated uploads are queued for review. Open Media Integrity to verify flagged submissions.',
      dateLabel: 'Operations',
    ),
  ];
}

// ── Date/time utilities ───────────────────────────────────────────────────────

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

String _formatDate(dynamic raw) {
  final d = _parseDate(raw);
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _formatTime(String raw) {
  final d = DateTime.tryParse('1970-01-01T$raw');
  if (d != null) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }
  if (raw.contains(':')) return raw;
  return raw;
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
}
