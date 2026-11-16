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

/// Presentation for [MemberSkillProgressSection].
enum MemberSkillProgressLayout {
  /// Profile: filters + expanded chart sections.
  standard,

  /// Member Home: one compact Performance Overview card (View Details).
  homeOverview,
}

const _kOverviewNavy = Color(0xFF103E56);
const _kOverviewMuted = Color(0xFF617F91);
const _kOverviewBorder = Color(0xFFD0EBF5);
const _kOverviewRadius = 15.0;

/// Eligible released practice quality over time (Home / Profile / Rankings).
class MemberSkillProgressSection extends StatefulWidget {
  const MemberSkillProgressSection({
    super.key,
    this.compact = false,
    this.layout = MemberSkillProgressLayout.standard,
    this.onViewDetails,
  });

  final bool compact;

  /// Home uses [MemberSkillProgressLayout.homeOverview] for the consolidated card.
  final MemberSkillProgressLayout layout;

  /// Opens the existing evaluation / performance surface (Member Home View Details).
  final VoidCallback? onViewDetails;

  @override
  State<MemberSkillProgressSection> createState() =>
      _MemberSkillProgressSectionState();
}

class _MemberSkillProgressSectionState extends State<MemberSkillProgressSection> {
  _MediaFilter _filter = _MediaFilter.all;

  bool get _isHomeOverview =>
      widget.layout == MemberSkillProgressLayout.homeOverview;

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
        // Home overview always uses All; Photo/Video filters stay on Profile.
        final videoOnly = _isHomeOverview ? null : _videoFilter;
        final chronological = chronologicalEligibleEvaluations(
          appState.evaluations,
          videoOnly: videoOnly,
        );
        final trend = computeSkillProgressTrend(chronological);
        final compare = latestVersusPrevious(chronological);
        final pendingCount = appState.evaluations
            .where((e) =>
                MemberReviewStatus.isReviewPending(e.reviewStatus) || e.isPending)
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

        if (_isHomeOverview) {
          return _buildHomeOverviewCard(
            chronological: chronological,
            trend: trend,
            compare: compare,
            historyError: historyError,
            historyLoading: historyLoading,
            emptyHeading: emptyCopy.heading,
            emptyDescription: emptyCopy.description,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.compact ? 'Quality trend' : 'Practice quality over time',
              style: widget.compact
                  ? memberDashboardSectionTitleStyle.copyWith(fontSize: 14)
                  : memberDashboardSectionTitleStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
            ),
            const SizedBox(height: 4),
            if (!widget.compact)
              Text(
                'Historical scores from eligible released practice',
                style: memberDashboardMetaStyle.copyWith(fontSize: 11.5, height: 1.35),
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
                  nestedCard: true,
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

  Widget _buildHomeOverviewCard({
    required List<Evaluation> chronological,
    required SkillProgressTrend trend,
    required ({Evaluation? latest, Evaluation? previous, double? deltaPoints})
        compare,
    required String? historyError,
    required bool historyLoading,
    required String emptyHeading,
    required String emptyDescription,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kOverviewRadius),
        border: Border.all(color: _kOverviewBorder),
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 15,
                  color: kCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Performance Overview',
                  style: dashText(const TextStyle(
                    color: _kOverviewNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  )),
                ),
              ),
              if (widget.onViewDetails != null)
                TextButton(
                  onPressed: widget.onViewDetails,
                  style: TextButton.styleFrom(
                    foregroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: const Size(40, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Details',
                    style: dashText(const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _OverviewQualitySummary(compare: compare),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return _buildChartArea(
                historyError: historyError,
                historyLoading: historyLoading,
                chronological: chronological,
                emptyHeading: emptyHeading,
                emptyDescription: emptyDescription,
                maxWidth: constraints.maxWidth,
                nestedCard: false,
                compactHome: true,
              );
            },
          ),
          const SizedBox(height: 8),
          _TrendBadge(trend: trend, homeCopy: true),
          if (compare.latest?.feedback.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Latest feedback',
              style: dashText(const TextStyle(
                color: _kOverviewNavy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
            ),
            const SizedBox(height: 3),
            Text(
              compare.latest!.feedback.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: dashText(const TextStyle(
                color: _kOverviewMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              )),
            ),
          ],
        ],
      ),
    );
  }

  ({String heading, String description}) _emptyStateCopy() {
    return switch (_filter) {
      _MediaFilter.video => (
          heading: 'Not enough video evaluations yet',
          description:
              'Complete at least 2 eligible video evaluations to see your progress.',
        ),
      _MediaFilter.photo => (
          heading: 'Not enough photo evaluations yet',
          description:
              'Complete at least 2 eligible photo evaluations to see your progress.',
        ),
      _MediaFilter.all => (
          heading: 'Not enough evaluations yet',
          description:
              'Complete at least 2 eligible practice evaluations to see your progress.',
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
    return '${parts.join(' · ')}. These are not shown in the chart yet.';
  }

  Widget _buildChartArea({
    required String? historyError,
    required bool historyLoading,
    required List<Evaluation> chronological,
    required String emptyHeading,
    required String emptyDescription,
    required double maxWidth,
    required bool nestedCard,
    bool compactHome = false,
  }) {
    if (historyError != null && appState.evaluations.isEmpty) {
      return _SkillProgressMessageCard(
        icon: Icons.cloud_off_outlined,
        heading: 'Could not load history',
        description: 'Pull to refresh or open Evaluations.',
        iconColor: kOrange,
        compact: widget.compact || compactHome,
      );
    }

    if (historyLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compactHome ? 22 : (widget.compact ? 28 : 36)),
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
        compact: widget.compact || compactHome,
      );
    }

    final width = maxWidth > 0 ? maxWidth : 320.0;
    final height = compactHome
        ? (width * 0.32).clamp(108.0, 148.0)
        : (width * 0.48).clamp(140.0, widget.compact ? 210.0 : 260.0);

    if (!nestedCard) {
      return SizedBox(
        height: height,
        width: width,
        child: _QualityLineChart(points: chronological),
      );
    }

    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        boxShadow: memberDashboardCardShadows(),
      ),
      child: _QualityLineChart(points: chronological),
    );
  }
}

class _OverviewQualitySummary extends StatelessWidget {
  const _OverviewQualitySummary({required this.compare});

  final ({Evaluation? latest, Evaluation? previous, double? deltaPoints}) compare;

  @override
  Widget build(BuildContext context) {
    final latest = compare.latest;
    final previous = compare.previous;
    final delta = compare.deltaPoints;

    String deltaLabel;
    Color deltaColor;
    if (latest == null) {
      deltaLabel = 'N/A';
      deltaColor = _kOverviewMuted;
    } else if (previous == null || delta == null) {
      deltaLabel = 'N/A';
      deltaColor = _kOverviewMuted;
    } else if (delta == 0) {
      deltaLabel = '0 pts';
      deltaColor = kAccent;
    } else if (delta > 0) {
      deltaLabel = '+${delta.round()} pts';
      deltaColor = delta >= SkillProgressTrendThresholds.improvingMinDelta
          ? kGreen
          : kAccent;
    } else {
      deltaLabel = '${delta.round()} pts';
      deltaColor = delta <= SkillProgressTrendThresholds.decliningMaxDelta
          ? kOrange
          : kAccent;
    }

    return Row(
      children: [
        Expanded(
          child: _OverviewMetricBlock(
            label: 'Latest Quality',
            value: latest == null ? 'N/A' : '${latest.displayPercent}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OverviewMetricBlock(
            label: 'Previous',
            value: previous == null ? 'N/A' : '${previous.displayPercent}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OverviewMetricBlock(
            label: 'Change',
            value: deltaLabel,
            valueColor: deltaColor,
          ),
        ),
      ],
    );
  }
}

class _OverviewMetricBlock extends StatelessWidget {
  const _OverviewMetricBlock({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAFD),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kOverviewBorder.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(const TextStyle(
              color: _kOverviewMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.1,
            )),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: dashText(TextStyle(
                color: valueColor ?? _kOverviewNavy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.2,
              )),
            ),
          ),
        ],
      ),
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
    final iconSize = compact ? 34.0 : 64.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: compact ? 10 : 24,
      ),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        boxShadow: compact ? null : memberDashboardCardShadows(),
      ),
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
          SizedBox(height: compact ? 6 : 14),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: memberDashboardCardTitleStyle.copyWith(fontSize: compact ? 12.5 : 14),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: memberDashboardBodyStyle.copyWith(
              fontSize: compact ? 11 : 13,
              color: kDashTextSecondary,
              height: 1.35,
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
      color: selected ? kCyanDim : kSurface,
      elevation: selected ? 0 : 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: dashText(TextStyle(
              fontSize: 12,
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
  const _TrendBadge({
    required this.trend,
    this.homeCopy = false,
  });

  final SkillProgressTrend trend;
  final bool homeCopy;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (trend) {
      SkillProgressTrend.improving => (
          kGreen.withValues(alpha: 0.12),
          kGreen,
          Icons.trending_up_rounded
        ),
      SkillProgressTrend.declining => (
          kOrange.withValues(alpha: 0.12),
          kOrange,
          Icons.trending_down_rounded
        ),
      SkillProgressTrend.stable => (
          kAccent.withValues(alpha: 0.1),
          kAccent,
          Icons.trending_flat_rounded
        ),
      SkillProgressTrend.insufficientData => (
          kBorder.withValues(alpha: 0.5),
          kTextSecondary,
          Icons.help_outline_rounded
        ),
    };
    final hint = homeCopy
        ? switch (trend) {
            SkillProgressTrend.improving =>
              'Your recent quality scores are moving up.',
            SkillProgressTrend.declining =>
              'Your recent quality scores are moving down.',
            SkillProgressTrend.stable =>
              'Your recent quality scores are relatively consistent.',
            SkillProgressTrend.insufficientData =>
              'More eligible evaluations are needed to show a trend.',
          }
        : switch (trend) {
            SkillProgressTrend.improving => 'Your recent scores are moving up',
            SkillProgressTrend.declining => 'Recent scores dipped a little',
            SkillProgressTrend.stable => 'Scores are holding steady',
            SkillProgressTrend.insufficientData =>
              'Add more eligible practice to see a trend',
          };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: homeCopy ? 10 : 14,
        vertical: homeCopy ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(homeCopy ? 11 : 14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: homeCopy ? 16 : 20, color: fg),
          SizedBox(width: homeCopy ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.label,
                  style: dashText(TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: homeCopy ? 12 : 13,
                    color: fg,
                  )),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: dashText(TextStyle(
                    fontSize: homeCopy ? 11 : 11,
                    color: fg.withValues(alpha: 0.88),
                    height: 1.28,
                  )),
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCyanDim.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Most recent', style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
                Text(
                  '${latest.displayPercent}%',
                  style: dashText(const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          if (prev != null && delta != null) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Before that', style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
                  Text(
                    '${prev.displayPercent}%',
                    style: dashText(const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                delta >= 0 ? '+${delta.round()} pts' : '${delta.round()} pts',
                style: dashText(TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: delta >= SkillProgressTrendThresholds.improvingMinDelta
                      ? kGreen
                      : delta <= SkillProgressTrendThresholds.decliningMaxDelta
                          ? kOrange
                          : kAccent,
                )),
              ),
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
          getDrawingHorizontalLine: (_) => FlLine(
            color: kBorder.withValues(alpha: 0.7),
            strokeWidth: 1,
          ),
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
                // Avoid overcrowding on many points.
                if (points.length > 6 && i != 0 && i != points.length - 1 && i % 2 != 0) {
                  return const SizedBox.shrink();
                }
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
                radius: 3.5,
                color: kAccent,
                strokeWidth: 2,
                strokeColor: kSurface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: kAccent.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}
