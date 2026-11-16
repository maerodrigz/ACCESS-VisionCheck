import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';

/// Summary metrics derived from `/member/participation` and evaluation history.
class MemberEvaluationSummaryData {
  const MemberEvaluationSummaryData({
    required this.completedCount,
    required this.skillEligibleCount,
    this.averageScorePercent,
  });

  /// Total completed practice evaluations (`evaluations_count` from participation API).
  final int completedCount;

  /// Evaluations that count toward skill tier (released, eligible quality).
  final int skillEligibleCount;

  /// Average score as 0–100 percent, when available from the backend.
  final int? averageScorePercent;

  factory MemberEvaluationSummaryData.fromAppState() {
    var count = appState.profileEvaluationsCount;
    if (count <= 0) {
      final scored = appState.evaluations.where((e) => e.score > 0).length;
      if (scored > 0) count = scored;
    }

    var skillEligible = appState.profileSkillEligibleEvaluationsCount;
    if (skillEligible <= 0) {
      skillEligible = skillEligibleEvaluations(appState.evaluations).length;
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
      skillEligibleCount: skillEligible,
      averageScorePercent: avgPercent,
    );
  }

  String get skillEligibleFootnote {
    if (completedCount <= 0 && skillEligibleCount <= 0) {
      return '';
    }
    if (skillEligibleCount == completedCount) {
      return 'All completed evaluations count toward your skill level.';
    }
    final excluded = completedCount - skillEligibleCount;
    if (excluded > 0) {
      return '$skillEligibleCount of $completedCount count toward skill level. '
          'Pending or withheld uploads are excluded until released.';
    }
    return '$skillEligibleCount eligible for skill level '
        '(total completed count still loading).';
  }
}

const _kProfileSectionTitle = 18.0;
const _kProfileCardRadius = 18.0;
const _kProfileCardPad = 14.0;
const _kProfileBtnHeight = 46.0;

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
            label: summary.completedCount == 1 ? 'Total evaluation' : 'Total evaluations',
            icon: Icons.fact_check_outlined,
          ),
          _SummaryMetric(
            value: '${summary.skillEligibleCount}',
            label: summary.skillEligibleCount == 1
                ? 'Skill-eligible'
                : 'Skill-eligible',
            icon: Icons.verified_outlined,
          ),
          if (summary.averageScorePercent != null)
            _SummaryMetric(
              value: '${summary.averageScorePercent}%',
              label: 'Average score',
              icon: Icons.insights_outlined,
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evaluation summary',
              style: memberDashboardSectionTitleStyle.copyWith(
                fontSize: _kProfileSectionTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(_kProfileCardPad),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(_kProfileCardRadius),
                boxShadow: memberDashboardCardShadows(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final threeCol = constraints.maxWidth >= 280 && metrics.length >= 3;
                      if (threeCol) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < metrics.length; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  height: 52,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  color: kBorder.withValues(alpha: 0.55),
                                ),
                              Expanded(child: _MetricTile(metric: metrics[i])),
                            ],
                          ],
                        );
                      }
                      return Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          for (final metric in metrics)
                            SizedBox(
                              width: (constraints.maxWidth - 10) / 2,
                              child: _MetricTile(metric: metric),
                            ),
                        ],
                      );
                    },
                  ),
                  if (summary.skillEligibleFootnote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      summary.skillEligibleFootnote,
                      style: memberDashboardMetaStyle.copyWith(fontSize: 11.5, height: 1.35),
                    ),
                  ],
                  if (summary.completedCount == 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Complete a practice evaluation to see your average score here.',
                      style: memberDashboardMetaStyle.copyWith(fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  MemberDashboardPrimaryButton(
                    label: 'View Evaluations',
                    icon: Icons.analytics_rounded,
                    onPressed: onViewEvaluations,
                    color: kMemberPrimary,
                    minHeight: _kProfileBtnHeight,
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
        Icon(metric.icon, size: 18, color: kMemberPrimary),
        const SizedBox(height: 4),
        Text(
          metric.value,
          style: memberDashboardSectionTitleStyle.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          style: memberDashboardMetaStyle.copyWith(fontSize: 11.5, height: 1.2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
