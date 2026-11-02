import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/utils/skill_progress_trend.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';

enum _MediaFilter { all, photo, video }

/// Eligible released practice quality over time (Home / Profile / Rankings).
class MemberSkillProgressSection extends StatefulWidget {
  const MemberSkillProgressSection({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<MemberSkillProgressSection> createState() => _MemberSkillProgressSectionState();
}

class _MemberSkillProgressSectionState extends State<MemberSkillProgressSection> {
  _MediaFilter _filter = _MediaFilter.all;

  bool? get _videoFilter => switch (_filter) {
        _MediaFilter.all => null,
        _MediaFilter.photo => false,
        _MediaFilter.video => true,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final chronological = chronologicalEligibleEvaluations(
          appState.evaluations,
          videoOnly: _videoFilter,
        );
        final trend = computeSkillProgressTrend(chronological);
        final compare = latestVersusPrevious(chronological);
        final pendingCount = appState.evaluations
            .where((e) => MemberReviewStatus.isReviewPending(e.reviewStatus) || e.isPending)
            .length;
        final withheldCount = appState.evaluations
            .where((e) => !evaluationEligibleForSkillProgress(e))
            .where((e) => !MemberReviewStatus.isReviewPending(e.reviewStatus))
            .length;
        final historyLoading = appState.evaluations.isEmpty &&
            !memberDataController.evaluationsTabSynced &&
            memberDataController.evaluationsTabError == null;
        final historyError = memberDataController.evaluationsTabError;

        final emptyCopy = _emptyStateCopy();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality progress',
              style: widget.compact
                  ? memberDashboardSectionTitleStyle.copyWith(fontSize: 14)
                  : memberDashboardSectionTitleStyle,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _MediaFilter.all,
                  onTap: () => setState(() => _filter = _MediaFilter.all),
                ),
                _FilterChip(
                  label: 'Photo',
                  selected: _filter == _MediaFilter.photo,
                  onTap: () => setState(() => _filter = _MediaFilter.photo),
                ),
                _FilterChip(
                  label: 'Video',
                  selected: _filter == _MediaFilter.video,
                  onTap: () => setState(() => _filter = _MediaFilter.video),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'See how your released practice scores trend over time.',
              style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.35),
            ),
            if (pendingCount > 0 || withheldCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                _pendingWithheldSummary(pendingCount, withheldCount),
                style: memberDashboardMetaStyle.copyWith(
                  fontSize: 11,
                  color: kOrange,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _TrendBadge(trend: trend),
            const SizedBox(height: 10),
            if (compare.latest != null) _LatestCompareRow(compare: compare),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return _buildChartArea(
                  historyError: historyError,
                  historyLoading: historyLoading,
                  chronological: chronological,
                  emptyHeading: emptyCopy.heading,
                  emptyDescription: emptyCopy.description,
                  maxWidth: constraints.maxWidth,
                );
              },
            ),
            if (compare.latest?.feedback.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                'Latest feedback',
                style: memberDashboardCardTitleStyle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                compare.latest!.feedback.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: memberDashboardBodyStyle.copyWith(fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  ({String heading, String description}) _emptyStateCopy() {
    return switch (_filter) {
      _MediaFilter.video => (
          heading: 'Not enough video evaluations yet',
          description: 'Complete at least 2 eligible video evaluations to see your progress.',
        ),
      _MediaFilter.photo => (
          heading: 'Not enough photo evaluations yet',
          description: 'Complete at least 2 eligible photo evaluations to see your progress.',
        ),
      _MediaFilter.all => (
          heading: 'Not enough evaluations yet',
          description: 'Complete at least 2 eligible practice evaluations to see your progress.',
        ),
    };
  }

  String _pendingWithheldSummary(int pendingCount, int withheldCount) {
    final parts = <String>[];
    if (pendingCount > 0) {
      parts.add('$pendingCount pending');
    }
    if (withheldCount > 0) {
      parts.add('$withheldCount withheld');
    }
    return '${parts.join(' · ')} (not shown in chart yet)';
  }

  Widget _buildChartArea({
    required String? historyError,
    required bool historyLoading,
    required List<Evaluation> chronological,
    required String emptyHeading,
    required String emptyDescription,
    required double maxWidth,
  }) {
    if (historyError != null && appState.evaluations.isEmpty) {
      return _SkillProgressMessageCard(
        icon: Icons.cloud_off_outlined,
        heading: 'Could not load history',
        description: 'Pull to refresh or open Evaluations.',
        iconColor: kOrange,
        compact: widget.compact,
      );
    }

    if (historyLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: widget.compact ? 28 : 36),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Loading evaluation history…',
                style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (chronological.length < 2) {
      return _SkillProgressMessageCard(
        icon: Icons.show_chart_rounded,
        heading: emptyHeading,
        description: emptyDescription,
        iconColor: kAccent,
        compact: widget.compact,
      );
    }

    final width = maxWidth > 0 ? maxWidth : 320.0;
    final height = (width * 0.48).clamp(140.0, widget.compact ? 210.0 : 260.0);
    return SizedBox(
      height: height,
      width: width,
      child: _QualityLineChart(points: chronological),
    );
  }
}

/// Empty / error panel with natural height (no fixed outer clip).
class _SkillProgressMessageCard extends StatelessWidget {
  const _SkillProgressMessageCard({
    required this.icon,
    required this.heading,
    required this.description,
    required this.iconColor,
    required this.compact,
  });

  final IconData icon;
  final String heading;
  final String description;
  final Color iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 52.0 : 64.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 18 : 24,
      ),
      decoration: memberDashboardCardDecoration(backgroundColor: kDashCardBg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize * 0.46, color: iconColor),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: memberDashboardCardTitleStyle.copyWith(fontSize: compact ? 13 : 14),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: memberDashboardBodyStyle.copyWith(
              fontSize: compact ? 12 : 13,
              color: kDashTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kAccent.withValues(alpha: 0.12) : kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? kAccent : kBorder),
          ),
          child: Text(
            label,
            style: dashText(TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? kAccent : kTextSecondary,
            )),
          ),
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final SkillProgressTrend trend;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (trend) {
      SkillProgressTrend.improving => (kGreen.withValues(alpha: 0.12), kGreen, Icons.trending_up_rounded),
      SkillProgressTrend.declining => (kOrange.withValues(alpha: 0.12), kOrange, Icons.trending_down_rounded),
      SkillProgressTrend.stable => (kAccent.withValues(alpha: 0.1), kAccent, Icons.trending_flat_rounded),
      SkillProgressTrend.insufficientData => (kBorder.withValues(alpha: 0.5), kTextSecondary, Icons.help_outline_rounded),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          Text(
            trend.label,
            style: dashText(TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
          ),
          Text(
            '(±${SkillProgressTrendThresholds.improvingMinDelta.toStringAsFixed(0)} pts)',
            style: dashText(TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.85))),
          ),
        ],
      ),
    );
  }
}

class _LatestCompareRow extends StatelessWidget {
  const _LatestCompareRow({required this.compare});

  final ({Evaluation? latest, Evaluation? previous, double? deltaPoints}) compare;

  @override
  Widget build(BuildContext context) {
    final latest = compare.latest!;
    final prev = compare.previous;
    final delta = compare.deltaPoints;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latest', style: memberDashboardMetaStyle.copyWith(fontSize: 10)),
                Text(
                  '${latest.displayPercent}%',
                  style: dashText(const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          if (prev != null && delta != null) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Previous', style: memberDashboardMetaStyle.copyWith(fontSize: 10)),
                  Text(
                    '${prev.displayPercent}%',
                    style: dashText(const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Text(
              delta >= 0 ? '+${delta.round()} pts' : '${delta.round()} pts',
              style: dashText(TextStyle(
                fontWeight: FontWeight.w800,
                color: delta >= SkillProgressTrendThresholds.improvingMinDelta
                    ? kGreen
                    : delta <= SkillProgressTrendThresholds.decliningMaxDelta
                        ? kOrange
                        : kAccent,
              )),
            ),
          ],
        ],
      ),
    );
  }
}

class _QualityLineChart extends StatelessWidget {
  const _QualityLineChart({required this.points});

  final List<Evaluation> points;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].displayPercent.toDouble()),
    ];
    final maxY = (spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b) + 5)
        .clamp(40.0, 100.0);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) => FlLine(color: kBorder, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 20,
              getTitlesWidget: (v, _) => Text(
                '${v.round()}',
                style: dashText(TextStyle(fontSize: 10, color: kTextSecondary)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Text(
                  '${i + 1}',
                  style: dashText(TextStyle(fontSize: 10, color: kTextSecondary)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: kAccent,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: kAccent,
                strokeWidth: 2,
                strokeColor: kSurface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: kAccent.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
