import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

/// Summary metrics derived from `/member/participation` and evaluation history.
class MemberEvaluationSummaryData {
  const MemberEvaluationSummaryData({
    required this.completedCount,
    this.averageScorePercent,
  });

  /// Total completed evaluations (`evaluations_count` from participation API).
  final int completedCount;

  /// Average score as 0–100 percent, when available from the backend.
  final int? averageScorePercent;

  factory MemberEvaluationSummaryData.fromAppState() {
    var count = appState.profileEvaluationsCount;
    if (count <= 0) {
      final scored = appState.evaluations.where((e) => e.score > 0).length;
      if (scored > 0) count = scored;
    }

    int? avgPercent;
    var avg = appState.profileAverageScore;
    if (avg <= 0 && appState.evaluations.isNotEmpty) {
      final scored = appState.evaluations.where((e) => e.score > 0).toList();
      if (scored.isNotEmpty) {
        avg = scored.fold<double>(0, (sum, e) => sum + e.displayScore) /
            scored.length;
      }
    }
    if (avg > 0) {
      avgPercent = avg <= 1 ? (avg * 100).round() : avg.round().clamp(0, 100);
    }

    return MemberEvaluationSummaryData(
      completedCount: count,
      averageScorePercent: avgPercent,
    );
  }
}

/// Compact evaluation activity summary for the member Profile tab.
class MemberProfileEvaluationSummarySection extends StatelessWidget {
  const MemberProfileEvaluationSummarySection({
    super.key,
    this.onViewEvaluations,
  });

  final VoidCallback? onViewEvaluations;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final summary = MemberEvaluationSummaryData.fromAppState();
        final metrics = <_SummaryMetric>[
          _SummaryMetric(
            value: '${summary.completedCount}',
            label: summary.completedCount == 1 ? 'Evaluation' : 'Evaluations',
            icon: Icons.fact_check_outlined,
          ),
          if (summary.averageScorePercent != null)
            _SummaryMetric(
              value: '${summary.averageScorePercent}%',
              label: 'Average Score',
              icon: Icons.insights_outlined,
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccessSectionHeader(title: 'Evaluation Summary'),
            const SizedBox(height: kMemberDashboardSectionTitleGap),
            MemberDashboardCard(
              showAccentStrip: true,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: kDashBorder,
                          ),
                        Expanded(child: _MetricTile(metric: metrics[i])),
                      ],
                    ],
                  ),
                  if (summary.completedCount == 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Complete an evaluation to see your average score here.',
                      style: memberDashboardMetaStyle,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: kMobileMinTouch,
                    child: OutlinedButton.icon(
                      onPressed: onViewEvaluations,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kMemberPrimary,
                        side: BorderSide(
                          color: kMemberPrimary.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(kMemberDashboardButtonRadius),
                        ),
                        textStyle: dashText(const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                      ),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('View Evaluations'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(metric.icon, size: 16, color: kMemberCyan),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                metric.label,
                style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          metric.value,
          style: memberDashboardSectionTitleStyle.copyWith(
            fontSize: 28,
            letterSpacing: -0.5,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}
