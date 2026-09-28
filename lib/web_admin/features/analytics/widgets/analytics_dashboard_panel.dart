import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/analytics/analytics_compute.dart';
import 'package:access_mobile/web_admin/features/analytics/analytics_models.dart';
import 'package:access_mobile/web_admin/features/analytics/widgets/analytics_fl_charts.dart';
import 'package:access_mobile/web_admin/features/analytics/widgets/analytics_layout.dart';
import 'package:access_mobile/web_admin/widgets/admin_activity_timeline.dart';

/// Analytics dashboard — recreated from reference screenshot with fl_chart.
class AnalyticsDashboardPanel extends StatelessWidget {
  const AnalyticsDashboardPanel({
    super.key,
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    this.onViewAllActivity,
  });

  final AnalyticsSnapshot data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final VoidCallback? onViewAllActivity;

  @override
  Widget build(BuildContext context) {
    final m = computeDashboardMetrics(data, rangeStart: rangeStart, rangeEnd: rangeEnd);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KpiRow(metrics: m),
          analyticsGap(vertical: true),
          _MiddleSection(metrics: m, onViewAll: onViewAllActivity),
          analyticsGap(vertical: true),
          _LowerSection(metrics: m),
          analyticsGap(vertical: true),
          _BottomSection(metrics: m),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      AnalyticsKpiCard(icon: Icons.assignment_outlined, color: AnalyticsChartColors.blue, value: '${metrics.totalRequests}', label: 'Total Requests', trend: metrics.requestsTrend),
      AnalyticsKpiCard(icon: Icons.event_available_outlined, color: AnalyticsChartColors.green, value: '${metrics.completedEvents}', label: 'Completed Events', trend: metrics.eventsTrend),
      AnalyticsKpiCard(icon: Icons.image_outlined, color: AnalyticsChartColors.orange, value: '${metrics.mediaUploaded}', label: 'Media Uploaded', trend: metrics.mediaTrend),
      AnalyticsKpiCard(icon: Icons.star_outline, color: AnalyticsChartColors.blue, value: metrics.avgQualityScore.toStringAsFixed(1), label: 'Avg. Quality Score', trend: metrics.qualityTrendPct, suffix: '/100'),
      AnalyticsKpiCard(icon: Icons.groups_outlined, color: AnalyticsChartColors.purple, value: '${metrics.activeMembers}', label: 'Active Members', trend: metrics.membersTrend),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 560) {
          return SizedBox(
            height: AnalyticsLayout.kpiHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) analyticsGap(), Expanded(child: cards[i])]],
            ),
          );
        }
        return Wrap(
          spacing: AnalyticsLayout.gap,
          runSpacing: AnalyticsLayout.gap,
          children: cards.map((card) => SizedBox(width: (c.maxWidth - AnalyticsLayout.gap) / 2, child: card)).toList(),
        );
      },
    );
  }
}

class _MiddleSection extends StatelessWidget {
  const _MiddleSection({required this.metrics, this.onViewAll});
  final AnalyticsDashboardMetrics metrics;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return AnalyticsResponsiveBlock(
      wideMinWidth: 880,
      wide: AnalyticsGridRow(
        height: AnalyticsLayout.middleRowHeight,
        flexes: const [2, 1, 1],
        children: [
          _LineChartCard(metrics: metrics),
          _MediaQualityCard(metrics: metrics),
          _ActivityCard(metrics: metrics, onViewAll: onViewAll),
        ],
      ),
      narrow: Column(
        children: [
          SizedBox(height: AnalyticsLayout.middleRowHeight, child: _LineChartCard(metrics: metrics)),
          analyticsGap(vertical: true),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MediaQualityCard(metrics: metrics)),
                analyticsGap(),
                Expanded(child: _ActivityCard(metrics: metrics, onViewAll: onViewAll)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LowerSection extends StatelessWidget {
  const _LowerSection({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsResponsiveBlock(
      wideMinWidth: 920,
      wide: AnalyticsGridRow(
        height: AnalyticsLayout.lowerRowHeight,
        flexes: const [1, 1, 1, 1],
        children: [
          _RequestStatusCard(metrics: metrics),
          _CategoryBarsCard(metrics: metrics),
          _TopMembersTable(metrics: metrics),
          _SkillLevelCard(metrics: metrics),
        ],
      ),
      narrow: Column(
        children: [
          SizedBox(height: 260, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: _RequestStatusCard(metrics: metrics)), analyticsGap(), Expanded(child: _CategoryBarsCard(metrics: metrics))])),
          analyticsGap(vertical: true),
          SizedBox(height: 260, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: _TopMembersTable(metrics: metrics)), analyticsGap(), Expanded(child: _SkillLevelCard(metrics: metrics))])),
        ],
      ),
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsResponsiveBlock(
      wideMinWidth: 760,
      wide: AnalyticsGridRow(
        height: AnalyticsLayout.bottomRowHeight,
        flexes: const [3, 2],
        children: [
          _QualityTrendCard(metrics: metrics),
          _InsightsCard(insights: metrics.insights),
        ],
      ),
      narrow: Column(
        children: [
          SizedBox(height: AnalyticsLayout.bottomRowHeight, child: _QualityTrendCard(metrics: metrics)),
          analyticsGap(vertical: true),
          SizedBox(height: 200, child: _InsightsCard(insights: metrics.insights)),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Requests and Completions Over Time',
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnalyticsLegendDot(color: AnalyticsChartColors.blue, label: 'Requests'),
          SizedBox(width: 12),
          AnalyticsLegendDot(color: AnalyticsChartColors.green, label: 'Completed Events'),
        ],
      ),
      child: FlRequestsLineChart(
        requests: metrics.requestsOverTime,
        completions: metrics.completionsOverTime,
      ),
    );
  }
}

class _MediaQualityCard extends StatelessWidget {
  const _MediaQualityCard({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final total = metrics.mediaEvaluatedTotal;
    return AnalyticsChartCard(
      title: 'Media Quality Distribution',
      child: Center(
        child: FlMediaQualityPanel(
          segments: metrics.mediaQualitySegments,
          centerValue: total > 0 ? '$total' : '${metrics.mediaUploaded}',
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.metrics, this.onViewAll});
  final AnalyticsDashboardMetrics metrics;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Recent System Activity',
      trailing: TextButton(
        onPressed: onViewAll,
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AnalyticsChartColors.blue)),
      ),
      child: _ActivityList(items: metrics.activity),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items});
  final List<AdminActivityItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No recent activity', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = items[i];
        final (icon, bg, fg) = _styleFor(i, item.kind);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF334155)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(item.time, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        );
      },
    );
  }

  (IconData, Color, Color) _styleFor(int i, String kind) => switch (kind) {
        'media' => (Icons.cloud_upload_outlined, const Color(0xFFDBEAFE), AnalyticsChartColors.blue),
        'member' => (Icons.person_outline, const Color(0xFFF3E8FF), AnalyticsChartColors.purple),
        _ when i == 0 => (Icons.check, const Color(0xFFDCFCE7), AnalyticsChartColors.green),
        _ => (Icons.description_outlined, const Color(0xFFE0E7FF), AnalyticsChartColors.blue),
      };
}

class _RequestStatusCard extends StatelessWidget {
  const _RequestStatusCard({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Requests by Status',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FlDonutChart(
            segments: metrics.requestStatusSegments,
            centerValue: '${metrics.totalRequests}',
            centerLabel: 'Total',
            size: 82,
            compactCenter: true,
          ),
          const SizedBox(height: 8),
          FlChartLegend(segments: metrics.requestStatusSegments),
        ],
      ),
    );
  }
}

class _CategoryBarsCard extends StatelessWidget {
  const _CategoryBarsCard({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Requests by Category',
      child: FlCategoryBarChartWithLabels(bars: metrics.categoryBars),
    );
  }
}

class _TopMembersTable extends StatelessWidget {
  const _TopMembersTable({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  static const _avatarColors = [AnalyticsChartColors.blue, AnalyticsChartColors.green, AnalyticsChartColors.purple, AnalyticsChartColors.orange, AnalyticsChartColors.red];

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Top Performing Members',
      child: metrics.topMembers.isEmpty
          ? const Center(child: Text('No data', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))))
          : Column(
              children: [
                const Row(
                  children: [
                    Expanded(flex: 5, child: Text('Member', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                    Expanded(flex: 3, child: Text('Avg. Quality Score', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('Tasks Completed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), textAlign: TextAlign.end)),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: metrics.topMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final row = metrics.topMembers[i];
                      final q = row.avgQuality <= 1 ? row.avgQuality * 100 : row.avgQuality;
                      return Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _avatarColors[i % _avatarColors.length].withValues(alpha: 0.15),
                                  child: Text(row.initials, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _avatarColors[i % _avatarColors.length])),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(row.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          Expanded(flex: 3, child: Text(q.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                          Expanded(flex: 2, child: Text('${row.tasksCompleted}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SkillLevelCard extends StatelessWidget {
  const _SkillLevelCard({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Skill Level Distribution',
      child: Center(
        child: FlSkillLevelPanel(
          segments: metrics.skillLevelSegments,
          centerValue: '${metrics.activeMembers}',
        ),
      ),
    );
  }
}

class _QualityTrendCard extends StatelessWidget {
  const _QualityTrendCard({required this.metrics});
  final AnalyticsDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Average Quality Score Trend',
      child: metrics.qualityScoreTrend.isEmpty
          ? Center(child: Text(metrics.avgQualityScore > 0 ? '${metrics.avgQualityScore.toStringAsFixed(1)}/100' : 'No evaluations yet', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))))
          : _QualityTrendWithLabels(points: metrics.qualityScoreTrend),
    );
  }
}

class _QualityTrendWithLabels extends StatelessWidget {
  const _QualityTrendWithLabels({required this.points});
  final List<(DateTime, double)> points;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FlQualityAreaChart(points: points),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < points.length; i++)
                  if (i == 0 || i == points.length - 1 || i == points.length ~/ 2)
                    Text(
                      points[i].$2.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AnalyticsChartColors.blue),
                    )
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return AnalyticsChartCard(
      title: 'Insights Summary',
      backgroundColor: AnalyticsChartColors.insightsBg,
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.lightbulb_outline, color: AnalyticsChartColors.purple, size: 18),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: insights.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, size: 16, color: AnalyticsChartColors.purple),
            const SizedBox(width: 10),
            Expanded(child: Text(insights[i], style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF334155)))),
          ],
        ),
      ),
    );
  }
}

String buildAnalyticsExportCsv(AnalyticsSnapshot data, DateTime rangeStart, DateTime rangeEnd) {
  final m = computeDashboardMetrics(data, rangeStart: rangeStart, rangeEnd: rangeEnd);
  final buf = StringBuffer();
  buf.writeln('ACCESS VisionCheck — Analytics Report');
  buf.writeln('Period,${formatMonthRange(rangeStart, rangeEnd)}');
  buf.writeln();
  buf.writeln('Metric,Value,Trend %');
  buf.writeln('Total Requests,${m.totalRequests},${m.requestsTrend.toStringAsFixed(1)}');
  buf.writeln('Completed Events,${m.completedEvents},${m.eventsTrend.toStringAsFixed(1)}');
  buf.writeln('Media Uploaded,${m.mediaUploaded},${m.mediaTrend.toStringAsFixed(1)}');
  buf.writeln('Avg Quality Score,${m.avgQualityScore.toStringAsFixed(1)},${m.qualityTrendPct.toStringAsFixed(1)}');
  buf.writeln('Active Members,${m.activeMembers},${m.membersTrend.toStringAsFixed(1)}');
  buf.writeln();
  buf.writeln('Top Members,Tasks,Avg Quality');
  for (final row in m.topMembers) {
    final q = row.avgQuality <= 1 ? row.avgQuality * 100 : row.avgQuality;
    buf.writeln('"${row.name}",${row.tasksCompleted},${q.toStringAsFixed(1)}');
  }
  buf.writeln();
  buf.writeln('Insights');
  for (final i in m.insights) {
    buf.writeln('"$i"');
  }
  return buf.toString();
}
