import 'package:access_mobile/web_admin/features/analytics/analytics_models.dart';
import 'package:access_mobile/web_admin/widgets/admin_activity_timeline.dart';

class ChartSegment {
  const ChartSegment(this.label, this.value, this.color);
  final String label;
  final double value;
  final int color; // ARGB
}

class TopMemberRow {
  const TopMemberRow({
    required this.name,
    required this.initials,
    required this.avgQuality,
    required this.tasksCompleted,
  });
  final String name;
  final String initials;
  final double avgQuality;
  final int tasksCompleted;
}

class AnalyticsDashboardMetrics {
  const AnalyticsDashboardMetrics({
    required this.totalRequests,
    required this.completedEvents,
    required this.mediaUploaded,
    required this.avgQualityScore,
    required this.activeMembers,
    required this.requestsTrend,
    required this.eventsTrend,
    required this.mediaTrend,
    required this.qualityTrendPct,
    required this.membersTrend,
    required this.prevPeriodLabel,
    required this.requestsOverTime,
    required this.completionsOverTime,
    required this.mediaQualitySegments,
    required this.mediaEvaluatedTotal,
    required this.requestStatusSegments,
    required this.categoryBars,
    required this.skillLevelSegments,
    required this.qualityScoreTrend,
    required this.topMembers,
    required this.activity,
    required this.insights,
  });

  final int totalRequests;
  final int completedEvents;
  final int mediaUploaded;
  final double avgQualityScore;
  final int activeMembers;
  final double requestsTrend;
  final double eventsTrend;
  final double mediaTrend;
  final double qualityTrendPct;
  final double membersTrend;
  final String prevPeriodLabel;
  final List<(DateTime, int)> requestsOverTime;
  final List<(DateTime, int)> completionsOverTime;
  final List<ChartSegment> mediaQualitySegments;
  final int mediaEvaluatedTotal;
  final List<ChartSegment> requestStatusSegments;
  final List<(String, int)> categoryBars;
  final List<ChartSegment> skillLevelSegments;
  final List<(DateTime, double)> qualityScoreTrend;
  final List<TopMemberRow> topMembers;
  final List<AdminActivityItem> activity;
  final List<String> insights;
}

AnalyticsDashboardMetrics computeDashboardMetrics(
  AnalyticsSnapshot data, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final prevStart = DateTime(rangeStart.year, rangeStart.month - 1, rangeStart.day);
  final prevEnd = DateTime(rangeStart.year, rangeStart.month, 0);

  final requests = data.requests.where((r) => _inRange(_parseDate(r['created_at']), rangeStart, rangeEnd)).toList();
  final prevRequests = data.requests.where((r) => _inRange(_parseDate(r['created_at']), prevStart, prevEnd)).toList();

  final events = data.events.where((e) {
    final d = _parseDate(e['event_date']);
    return d != null && _inRange(d, rangeStart, rangeEnd);
  }).toList();
  final prevEvents = data.events.where((e) {
    final d = _parseDate(e['event_date']);
    return d != null && _inRange(d, prevStart, prevEnd);
  }).toList();

  final media = data.media.where((m) => _inRange(_parseDate(m['uploaded_at']), rangeStart, rangeEnd)).toList();
  final prevMedia = data.media.where((m) => _inRange(_parseDate(m['uploaded_at']), prevStart, prevEnd)).toList();

  final evaluations = data.evaluations.where((e) => _inRange(_parseDate(e['evaluated_at'] ?? e['created_at']), rangeStart, rangeEnd)).toList();
  final prevEvaluations = data.evaluations.where((e) => _inRange(_parseDate(e['evaluated_at'] ?? e['created_at']), prevStart, prevEnd)).toList();

  final completedEvents = events.where((e) => (e['status'] as String? ?? '').toLowerCase() == 'completed').length;
  final prevCompleted = prevEvents.where((e) => (e['status'] as String? ?? '').toLowerCase() == 'completed').length;

  final avgQuality = _avgScore(evaluations);
  final prevAvgQuality = _avgScore(prevEvaluations);

  final activeMembers = data.stats['active_members'] as int? ?? data.rankings.length;

  final requestsOverTime = _dailyCounts(requests, 'created_at', rangeStart, rangeEnd);
  final completionsOverTime = _dailyCounts(
    events.where((e) => (e['status'] as String? ?? '').toLowerCase() == 'completed').toList(),
    'event_date',
    rangeStart,
    rangeEnd,
  );

  var high = 0, medium = 0, low = 0;
  for (final e in evaluations) {
    final s = (e['overall_score'] as num?)?.toDouble() ?? 0;
    if (s >= 0.8) {
      high++;
    } else if (s >= 0.5) {
      medium++;
    } else {
      low++;
    }
  }
  final mediaTotal = high + medium + low;

  final statusCounts = <String, int>{};
  for (final r in requests) {
    final st = _normalizeRequestStatus((r['status'] as String? ?? 'Pending').toString());
    statusCounts[st] = (statusCounts[st] ?? 0) + 1;
  }

  final categoryCounts = <String, int>{};
  for (final r in requests) {
    final title = (r['event_name'] ?? r['title'] ?? 'Other').toString().toLowerCase();
    final cat = _inferCategory(title);
    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
  }
  final categoryBars = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final skillCounts = <String, int>{'Advanced': 0, 'Intermediate': 0, 'Beginner': 0};
  for (final r in data.rankings) {
    final level = (r['skill_level'] as String? ?? 'Beginner').toString();
    if (level.toLowerCase().contains('expert') || level.toLowerCase().contains('advanced')) {
      skillCounts['Advanced'] = skillCounts['Advanced']! + 1;
    } else if (level.toLowerCase().contains('intermediate')) {
      skillCounts['Intermediate'] = skillCounts['Intermediate']! + 1;
    } else {
      skillCounts['Beginner'] = skillCounts['Beginner']! + 1;
    }
  }

  final qualityTrend = _qualityTrendByWeek(evaluations, rangeStart, rangeEnd);

  final topMembers = data.rankings.take(5).map((r) {
    final name = (r['member_name'] ?? r['name'] ?? 'Member').toString();
    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return TopMemberRow(
      name: name,
      initials: initials,
      avgQuality: ((r['average_quality_score'] ?? r['avg_score'] ?? 0) as num).toDouble(),
      tasksCompleted: r['completed_tasks'] as int? ?? 0,
    );
  }).toList();

  final activity = _buildActivity(data, rangeStart, rangeEnd);

  final topCategory = categoryBars.isNotEmpty ? categoryBars.first.key : null;

  final insights = <String>[
    if (requests.length != prevRequests.length)
      'Requests ${requests.length >= prevRequests.length ? 'increased' : 'decreased'} by ${_pctChange(requests.length, prevRequests.length).abs().toStringAsFixed(0)}% compared to last month.',
    if (evaluations.isNotEmpty)
      'Average media quality ${avgQuality >= prevAvgQuality ? 'improved' : 'changed'} by ${_pctChange((avgQuality * 100).round(), (prevAvgQuality * 100).round()).abs().toStringAsFixed(0)}%.',
    if (topCategory != null) '$topCategory remains the top request category.',
    if (data.rankings.isNotEmpty) 'Member engagement is steadily growing.',
  ];
  if (insights.isEmpty) {
    insights.add('Analytics will populate as requests, media, and evaluations are recorded.');
  }

  return AnalyticsDashboardMetrics(
    totalRequests: requests.length,
    completedEvents: completedEvents,
    mediaUploaded: media.length,
    avgQualityScore: avgQuality * 100,
    activeMembers: activeMembers,
    requestsTrend: _pctChange(requests.length, prevRequests.length),
    eventsTrend: _pctChange(completedEvents, prevCompleted),
    mediaTrend: _pctChange(media.length, prevMedia.length),
    qualityTrendPct: _pctChange((avgQuality * 100).round(), (prevAvgQuality * 100).round()),
    membersTrend: _pctChange(activeMembers, data.stats['active_members_prev'] as int? ?? activeMembers),
    prevPeriodLabel: formatMonthRange(prevStart, prevEnd),
    requestsOverTime: requestsOverTime,
    completionsOverTime: completionsOverTime,
    mediaQualitySegments: [
      ChartSegment('High Quality (>= 80)', high.toDouble(), 0xFF22C55E),
      ChartSegment('Medium Quality (50 - 79)', medium.toDouble(), 0xFF3B82F6),
      ChartSegment('Low Quality (< 50)', low.toDouble(), 0xFFEF4444),
    ],
    mediaEvaluatedTotal: mediaTotal,
    requestStatusSegments: [
      ChartSegment('Pending', (statusCounts['Pending'] ?? 0).toDouble(), 0xFF3B82F6),
      ChartSegment('Approved', (statusCounts['Approved'] ?? 0).toDouble(), 0xFF22C55E),
      ChartSegment('In Progress', (statusCounts['In Progress'] ?? 0).toDouble(), 0xFF8B5CF6),
      ChartSegment('Completed', (statusCounts['Completed'] ?? 0).toDouble(), 0xFFEF4444),
    ],
    categoryBars: categoryBars.take(5).map((e) => (e.key, e.value)).toList(),
    skillLevelSegments: [
      ChartSegment('Advanced', skillCounts['Advanced']!.toDouble(), 0xFF22C55E),
      ChartSegment('Intermediate', skillCounts['Intermediate']!.toDouble(), 0xFF3B82F6),
      ChartSegment('Beginner', skillCounts['Beginner']!.toDouble(), 0xFFF59E0B),
    ],
    qualityScoreTrend: qualityTrend,
    topMembers: topMembers,
    activity: activity,
    insights: insights,
  );
}

String _normalizeRequestStatus(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.contains('pending')) return 'Pending';
  if (s.contains('approv')) return 'Approved';
  if (s.contains('complete')) return 'Completed';
  if (s.contains('progress') || s.contains('assign') || s.contains('active')) return 'In Progress';
  if (s.contains('reject')) return 'Rejected';
  return raw.isEmpty ? 'Pending' : raw;
}

String _inferCategory(String title) {
  if (title.contains('train') || title.contains('workshop')) return 'Training / Workshop';
  if (title.contains('meet')) return 'Meetings';
  if (title.contains('promo') || title.contains('marketing')) return 'Promotion / Marketing';
  if (title.contains('event') || title.contains('coverage') || title.contains('summit') || title.contains('day')) {
    return 'Events Coverage';
  }
  return 'Other';
}

double _avgScore(List<Map<String, dynamic>> evals) {
  if (evals.isEmpty) return 0;
  final sum = evals.fold<double>(0, (s, e) => s + ((e['overall_score'] as num?)?.toDouble() ?? 0));
  return sum / evals.length;
}

double _pctChange(int current, int previous) {
  if (previous == 0) return current > 0 ? 100 : 0;
  return ((current - previous) / previous) * 100;
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

bool _inRange(DateTime? d, DateTime start, DateTime end) {
  if (d == null) return false;
  final day = DateTime(d.year, d.month, d.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !day.isBefore(s) && !day.isAfter(e);
}

List<(DateTime, int)> _dailyCounts(
  List<Map<String, dynamic>> rows,
  String dateKey,
  DateTime start,
  DateTime end,
) {
  final map = <DateTime, int>{};
  var cursor = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!cursor.isAfter(last)) {
    map[cursor] = 0;
    cursor = cursor.add(const Duration(days: 1));
  }
  for (final r in rows) {
    final d = _parseDate(r[dateKey]);
    if (d == null) continue;
    final key = DateTime(d.year, d.month, d.day);
    if (map.containsKey(key)) map[key] = (map[key] ?? 0) + 1;
  }
  return map.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => a.$1.compareTo(b.$1));
}

List<(DateTime, double)> _qualityTrendByWeek(
  List<Map<String, dynamic>> evals,
  DateTime start,
  DateTime end,
) {
  if (evals.isEmpty) return [];
  final sorted = [...evals]..sort((a, b) {
      final da = _parseDate(a['evaluated_at'] ?? a['created_at']);
      final db = _parseDate(b['evaluated_at'] ?? b['created_at']);
      return (da ?? DateTime(2000)).compareTo(db ?? DateTime(2000));
    });
  final points = <(DateTime, double)>[];
  for (var i = 0; i < sorted.length; i++) {
    final slice = sorted.sublist(0, i + 1);
    final avg = _avgScore(slice);
    final d = _parseDate(sorted[i]['evaluated_at'] ?? sorted[i]['created_at']);
    if (d != null) points.add((d, avg * 100));
  }
  return points.length > 8 ? points.sublist(points.length - 8) : points;
}

List<AdminActivityItem> _buildActivity(AnalyticsSnapshot data, DateTime start, DateTime end) {
  final items = <({DateTime? date, AdminActivityItem item})>[];

  for (final r in data.requests) {
    final d = _parseDate(r['created_at']);
    if (!_inRange(d, start, end)) continue;
    items.add((
      date: d,
      item: AdminActivityItem(
        kind: 'request',
        title: 'Request "${r['event_name'] ?? r['title'] ?? 'Documentation'}" ${r['status'] ?? ''}',
        subtitle: r['requester_name'] as String? ?? '',
        status: (r['status'] as String? ?? 'Pending').toString(),
        time: _timeAgo(d),
      ),
    ));
  }

  for (final e in data.evaluations.take(30)) {
    final label = (e['detection_result'] as String? ?? e['ai_result'] as String? ?? '').toLowerCase();
    if (label != 'suspicious' && label != 'ai_generated' && !label.contains('generated')) continue;
    final d = _parseDate(e['evaluated_at'] ?? e['created_at']);
    if (!_inRange(d, start, end)) continue;
    final score = ((e['overall_score'] as num?)?.toDouble() ?? 0) * 100;
    items.add((
      date: d,
      item: AdminActivityItem(
        kind: 'media',
        title: 'Media integrity flag: ${e['file_name'] ?? e['media_name'] ?? 'file'}',
        subtitle: '${e['member_name'] ?? ''} · ${score.round()}% quality',
        status: 'integrity',
        time: _timeAgo(d),
      ),
    ));
  }

  items.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
  return items.take(6).map((e) => e.item).toList();
}

String _timeAgo(DateTime? d) {
  if (d == null) return 'Recently';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 48) return '${diff.inHours} hr ago';
  return '${diff.inDays} days ago';
}

String formatMonthRange(DateTime start, DateTime end) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${end.year}';
}

(DateTime, DateTime) currentMonthRange([DateTime? now]) {
  final n = now ?? DateTime.now();
  final start = DateTime(n.year, n.month, 1);
  final end = DateTime(n.year, n.month + 1, 0);
  return (start, end);
}
