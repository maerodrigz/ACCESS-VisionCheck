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

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final pendingRequests = requests
      .where((r) => (r['status'] as String? ?? 'Pending').toLowerCase() == 'pending')
      .map(_mapPendingRequest)
      .toList()
    ..sort((a, b) => b.requestedDate.compareTo(a.requestedDate));

  final todayEvents = events.where((e) {
    final d = _parseDate(e['event_date']);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (day != today) return false;
    final status = (e['status'] as String? ?? '').toLowerCase();
    return status != 'cancelled' && status != 'canceled';
  }).map((e) => _mapTodayEvent(e, tasks)).toList()
    ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));

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

  final notifItems = notifications.map(AdminNotificationItem.fromMap).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

  final unread = notifItems.where((n) => n.unread).length;

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
  );
}

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
  );
}

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

  for (final e in evaluations.take(30)) {
    final label = (e['detection_result'] as String? ?? e['ai_result'] as String? ?? '').toLowerCase();
    if (label != 'suspicious' && label != 'ai_generated' && !label.contains('generated')) continue;
    final d = _parseDate(e['evaluated_at'] ?? e['created_at']);
    final score = ((e['overall_score'] as num?)?.toDouble() ?? 0) * 100;
    items.add((
      date: d,
      item: AdminActivityItem(
        kind: 'media',
        title: 'Media integrity flag: ${e['file_name'] ?? e['media_name'] ?? 'file'}',
        subtitle: '${e['member_name'] ?? ''} · ${score.round()}% quality',
        status: 'Integrity',
        time: formatTimeAgo(e['evaluated_at'] ?? e['created_at']),
      ),
    ));
  }

  for (final m in media.take(15)) {
    final label = (m['detection_result'] as String? ?? m['ai_result'] as String? ?? '').toLowerCase();
    if (label != 'suspicious' && label != 'ai_generated' && !label.contains('generated')) continue;
    final d = _parseDate(m['uploaded_at'] ?? m['created_at']);
    items.add((
      date: d,
      item: AdminActivityItem(
        kind: 'media',
        title: 'Integrity review needed: ${m['file_name'] ?? m['title'] ?? 'file'}',
        subtitle: m['uploader_name'] as String? ?? m['member_name'] as String? ?? '',
        status: 'Integrity',
        time: formatTimeAgo(m['uploaded_at'] ?? m['created_at']),
      ),
    ));
  }

  for (final r in requests.where((x) {
    final s = (x['status'] as String? ?? '').toLowerCase();
    return s.contains('approv') || s.contains('reject');
  }).take(10)) {
    final d = _parseDate(r['updated_at'] ?? r['created_at']);
    final status = (r['status'] as String? ?? '').toString();
    items.add((
      date: d,
      item: AdminActivityItem(
        kind: 'request',
        title: 'Request ${status.toLowerCase()}: ${r['event_name'] ?? r['title'] ?? 'Documentation'}',
        subtitle: r['requester_name'] as String? ?? '',
        status: status,
        time: formatTimeAgo(r['updated_at'] ?? r['created_at']),
      ),
    ));
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

String buildLocalDailySummary(HomeDashboardSnapshot snap) {
  final parts = <String>[];
  final o = snap.overview;

  if (o.pendingRequests > 0) {
    parts.add('${o.pendingRequests} documentation request${o.pendingRequests == 1 ? '' : 's'} need${o.pendingRequests == 1 ? 's' : ''} your review.');
  }
  if (o.todayEvents > 0) {
    parts.add('${o.todayEvents} event${o.todayEvents == 1 ? '' : 's'} scheduled today — confirm assignments and coverage.');
  }
  if (o.mediaPendingEvaluation > 0) {
    parts.add('${o.mediaPendingEvaluation} media item${o.mediaPendingEvaluation == 1 ? '' : 's'} await AI evaluation.');
  }
  if (snap.pendingMembers > 0) {
    parts.add('${snap.pendingMembers} member registration${snap.pendingMembers == 1 ? '' : 's'} pending approval.');
  }
  if (o.unreadNotifications > 0) {
    parts.add('You have ${o.unreadNotifications} unread notification${o.unreadNotifications == 1 ? '' : 's'}.');
  }
  if (parts.isEmpty) {
    return 'Operations look clear today. Check Today\'s Schedule and Recent Activity for anything that may need a follow-up.';
  }
  return parts.join(' ');
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

String _formatDate(dynamic raw) {
  final d = _parseDate(raw);
  if (d == null) return '—';
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
