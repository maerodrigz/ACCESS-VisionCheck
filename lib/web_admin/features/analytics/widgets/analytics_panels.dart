import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/analytics/analytics_models.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/layout/clickable_summary_card.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class AnalyticsOverviewPanel extends StatelessWidget {
  const AnalyticsOverviewPanel({super.key, required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final s = data.stats;
    final rs = data.rankingsSummary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SummaryCardGrid(
            children: [
              ClickableSummaryCard(
                icon: Icons.event_outlined,
                value: '${s['total_events'] ?? 0}',
                label: 'Total events',
                description: 'Scheduled documentation events',
                color: AdminTheme.accentBlue,
              ),
              ClickableSummaryCard(
                icon: Icons.task_alt_outlined,
                value: '${s['completed_tasks'] ?? 0}',
                label: 'Tasks completed',
                description: 'Finished member assignments',
                color: AdminTheme.success,
              ),
              ClickableSummaryCard(
                icon: Icons.people_outline,
                value: '${s['active_members'] ?? 0}',
                label: 'Active members',
                description: 'Approved member accounts',
                color: const Color(0xFF7C3AED),
              ),
              ClickableSummaryCard(
                icon: Icons.perm_media_outlined,
                value: '${s['media_uploads'] ?? 0}',
                label: 'Media uploads',
                description: 'Photos and videos in gallery',
                color: const Color(0xFF0891B2),
              ),
              ClickableSummaryCard(
                icon: Icons.star_outline,
                value: data.avgFeedbackRating > 0 ? data.avgFeedbackRating.toStringAsFixed(1) : '—',
                label: 'Avg feedback',
                description: '${s['feedback_count'] ?? 0} ratings submitted',
                color: const Color(0xFFF59E0B),
              ),
              ClickableSummaryCard(
                icon: Icons.emoji_events_outlined,
                value: (rs['top_performer_name'] ?? '—').toString(),
                label: 'Top performer',
                description: '${rs['top_performer_points'] ?? 0} ranking points',
                color: AdminTheme.accentCyan,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 720;
              final requestChart = _DistributionCard(
                title: 'Documentation requests',
                segments: [
                  _Segment('Pending', s['pending_requests'] ?? 0, AdminTheme.warning),
                  _Segment('Approved', s['approved_requests'] ?? 0, AdminTheme.success),
                  _Segment('Rejected', s['rejected_requests'] ?? 0, AdminTheme.danger),
                  _Segment('Completed', s['completed_requests'] ?? 0, AdminTheme.accentBlue),
                ],
              );
              final mediaChart = _DistributionCard(
                title: 'Media & quality',
                segments: [
                  _Segment('Uploads', s['media_uploads'] ?? 0, const Color(0xFF0891B2)),
                  _Segment('Evaluations', s['total_evaluations'] ?? 0, AdminTheme.accentBlue),
                  _Segment('AI flagged', s['ai_flagged'] ?? 0, AdminTheme.danger),
                ],
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: requestChart),
                    const SizedBox(width: 16),
                    Expanded(child: mediaChart),
                  ],
                );
              }
              return Column(
                children: [
                  requestChart,
                  const SizedBox(height: 16),
                  mediaChart,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _InsightsCard(data: data),
        ],
      ),
    );
  }
}

class _Segment {
  const _Segment(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.title, required this.segments});

  final String title;
  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 14),
          if (total == 0)
            const Text('No data yet.', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final seg in segments)
                      if (seg.value > 0)
                        Expanded(
                          flex: seg.value,
                          child: Container(color: seg.color),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...segments.map(
              (seg) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(seg.label, style: const TextStyle(fontSize: 13))),
                    Text(
                      '${seg.value}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      total > 0 ? '${((seg.value / total) * 100).round()}%' : '0%',
                      style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final rs = data.rankingsSummary;
    final insights = <String>[
      '${rs['total_ranked'] ?? 0} members ranked on participation and quality scores.',
      'Most active uploader: ${rs['most_active_uploader_name'] ?? '—'} (${rs['most_active_uploads'] ?? 0} uploads).',
      '${rs['needs_improvement_count'] ?? 0} members flagged for improvement or inactive participation.',
      '${data.events.length} events on calendar · ${data.feedback.length} feedback records · ${data.media.length} media files tracked.',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AdminTheme.accentBlue),
              SizedBox(width: 8),
              Text('Key insights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AdminTheme.accentBlue, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(line, style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsParticipationPanel extends StatelessWidget {
  const AnalyticsParticipationPanel({super.key, required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final rows = data.rankings.map(_participationRow).toList();

    return DataTableCard(
      title: 'Member participation',
      shownCount: rows.length,
      totalCount: rows.length,
      emptyTitle: 'No participation data',
      emptyMessage: 'Rankings appear after members complete tasks and upload media.',
      minHeight: 280,
      child: AdminDataTableTheme(
        child: ResponsiveTableScroll(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Tasks')),
              DataColumn(label: Text('Uploads')),
              DataColumn(label: Text('Participation')),
              DataColumn(label: Text('Avg quality')),
              DataColumn(label: Text('Status')),
            ],
            rows: rows
                .map((row) => DataRow(cells: row.map((c) => DataCell(Text(c))).toList()))
                .toList(),
          ),
        ),
      ),
    );
  }

  List<String> _participationRow(Map<String, dynamic> r) {
    final status = (r['participation_status'] as String? ?? 'active').replaceAll('_', ' ');
    final label = status.isEmpty ? 'Active' : '${status[0].toUpperCase()}${status.substring(1)}';
    return [
      (r['member_name'] ?? r['name'] ?? '—').toString(),
      '${r['completed_tasks'] ?? 0}',
      '${r['uploads'] ?? r['total_uploads'] ?? 0}',
      '${((r['task_participation_score'] as num? ?? 0) * 100).round()}%',
      (r['avg_score'] ?? r['average_quality_score'] ?? '—').toString(),
      label.contains('needs') ? 'Needs improvement' : label,
    ];
  }
}

class AnalyticsEventsPanel extends StatelessWidget {
  const AnalyticsEventsPanel({super.key, required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final events = data.events;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var upcoming = 0;
    var completed = 0;
    for (final e in events) {
      final status = (e['status'] as String? ?? '').toLowerCase();
      if (status == 'completed') completed++;
      final d = DateTime.tryParse(e['event_date'] as String? ?? '');
      if (d != null && !d.isBefore(today) && status != 'completed' && status != 'cancelled') upcoming++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryCardGrid(
          compact: true,
          children: [
            ClickableSummaryCard(
              compact: true,
              icon: Icons.calendar_month_outlined,
              value: '${events.length}',
              label: 'All events',
              description: 'Total on calendar',
              color: AdminTheme.accentBlue,
            ),
            ClickableSummaryCard(
              compact: true,
              icon: Icons.upcoming_outlined,
              value: '$upcoming',
              label: 'Upcoming',
              description: 'Scheduled ahead',
              color: AdminTheme.accentCyan,
            ),
            ClickableSummaryCard(
              compact: true,
              icon: Icons.check_circle_outline,
              value: '$completed',
              label: 'Completed',
              description: 'Finished events',
              color: AdminTheme.success,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableCard(
            title: 'Event schedule report',
            shownCount: events.length,
            totalCount: events.length,
            emptyTitle: 'No events',
            emptyMessage: 'Events from approved requests and manual entries appear here.',
            minHeight: 240,
            child: AdminDataTableTheme(
              child: ResponsiveTableScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Assigned')),
                    DataColumn(label: Text('Location')),
                  ],
                  rows: events.map((e) {
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          (e['title'] ?? '—').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text((e['event_date'] ?? '—').toString())),
                        DataCell(Text((e['status'] ?? '—').toString())),
                        DataCell(Text((e['assigned_member_name'] ?? '—').toString())),
                        DataCell(Text((e['location'] ?? e['venue'] ?? '—').toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsRankingsPanel extends StatelessWidget {
  const AnalyticsRankingsPanel({super.key, required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final rs = data.rankingsSummary;
    final top = data.rankings.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryCardGrid(
          compact: true,
          children: [
            ClickableSummaryCard(
              compact: true,
              icon: Icons.leaderboard_outlined,
              value: '${rs['total_ranked'] ?? 0}',
              label: 'Ranked members',
              description: 'Active leaderboard',
              color: AdminTheme.accentBlue,
            ),
            ClickableSummaryCard(
              compact: true,
              icon: Icons.military_tech_outlined,
              value: (rs['top_performer_name'] ?? '—').toString(),
              label: 'Top performer',
              description: '${rs['top_performer_points'] ?? 0} pts',
              color: const Color(0xFFF59E0B),
            ),
            ClickableSummaryCard(
              compact: true,
              icon: Icons.warning_amber_outlined,
              value: '${rs['needs_improvement_count'] ?? 0}',
              label: 'Needs support',
              description: 'Improvement or inactive',
              color: AdminTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableCard(
            title: 'Leaderboard',
            shownCount: top.length,
            totalCount: data.rankings.length,
            minHeight: 240,
            child: AdminDataTableTheme(
              child: ResponsiveTableScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Rank')),
                    DataColumn(label: Text('Member')),
                    DataColumn(label: Text('Points')),
                    DataColumn(label: Text('Skill score')),
                    DataColumn(label: Text('Uploads')),
                    DataColumn(label: Text('Tasks')),
                  ],
                  rows: top.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text('#${r['rank'] ?? r['rank_position'] ?? '—'}')),
                        DataCell(Text(
                          (r['member_name'] ?? '—').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text('${r['points'] ?? 0}')),
                        DataCell(Text('${r['skill_score'] ?? '—'}')),
                        DataCell(Text('${r['uploads'] ?? 0}')),
                        DataCell(Text('${r['completed_tasks'] ?? 0}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsFeedbackPanel extends StatelessWidget {
  const AnalyticsFeedbackPanel({super.key, required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final rows = data.feedback;
    final avg = data.avgFeedbackRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClickableSummaryCard(
                compact: true,
                icon: Icons.forum_outlined,
                value: '${rows.length}',
                label: 'Total feedback',
                description: 'Submitted ratings',
                color: AdminTheme.accentBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClickableSummaryCard(
                compact: true,
                icon: Icons.star_rate_outlined,
                value: avg > 0 ? avg.toStringAsFixed(1) : '—',
                label: 'Average rating',
                description: 'Out of 5 stars',
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableCard(
            title: 'Feedback report',
            shownCount: rows.length,
            totalCount: rows.length,
            emptyTitle: 'No feedback yet',
            emptyMessage: 'Ratings from event documentation will appear here.',
            minHeight: 240,
            child: AdminDataTableTheme(
              child: ResponsiveTableScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Member')),
                    DataColumn(label: Text('Rating')),
                    DataColumn(label: Text('Comment')),
                    DataColumn(label: Text('Submitted')),
                  ],
                  rows: rows.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text((r['event_title'] ?? r['event_name'] ?? '—').toString())),
                        DataCell(Text((r['member_name'] ?? r['user_name'] ?? '—').toString())),
                        DataCell(Text('${r['rating'] ?? '—'}')),
                        DataCell(Text((r['comment'] ?? r['feedback'] ?? '—').toString())),
                        DataCell(Text((r['created_at'] ?? '—').toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsMediaPanel extends StatelessWidget {
  const AnalyticsMediaPanel({super.key, required this.data});

  final AnalyticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final s = data.stats;
    final ev = data.evaluationSummary;
    final ai = data.aiSummary;
    final media = data.media;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryCardGrid(
          compact: true,
          children: [
            ClickableSummaryCard(
              compact: true,
              icon: Icons.photo_library_outlined,
              value: '${s['media_uploads'] ?? media.length}',
              label: 'Uploads',
              description: 'Gallery files',
              color: const Color(0xFF0891B2),
            ),
            ClickableSummaryCard(
              compact: true,
              icon: Icons.high_quality_outlined,
              value: '${ev['total'] ?? s['total_evaluations'] ?? 0}',
              label: 'Evaluations',
              description: 'Quality reviews',
              color: AdminTheme.accentBlue,
            ),
            ClickableSummaryCard(
              compact: true,
              icon: Icons.smart_toy_outlined,
              value: '${ai['ai_generated'] ?? s['ai_flagged'] ?? 0}',
              label: 'AI flagged',
              description: 'Needs review',
              color: AdminTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableCard(
            title: 'Recent uploads',
            shownCount: media.length.clamp(0, 20),
            totalCount: media.length,
            emptyTitle: 'No media uploaded',
            emptyMessage: 'Member uploads will appear in this report.',
            minHeight: 240,
            child: AdminDataTableTheme(
              child: ResponsiveTableScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Uploader')),
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Uploaded')),
                  ],
                  rows: media.take(20).map((m) {
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          (m['title'] ?? m['filename'] ?? '—').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text((m['uploader_name'] ?? m['member_name'] ?? '—').toString())),
                        DataCell(Text((m['event_title'] ?? '—').toString())),
                        DataCell(Text((m['media_type'] ?? m['type'] ?? '—').toString())),
                        DataCell(Text((m['created_at'] ?? m['uploaded_at'] ?? '—').toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
