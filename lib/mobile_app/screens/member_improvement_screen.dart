import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/utils/skill_progress_trend.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_improvement_sparkline.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Dedicated My Improvement details — Photo / Video tabs, criteria deltas, tips.
class MemberImprovementScreen extends StatefulWidget {
  const MemberImprovementScreen({
    super.key,
    this.initialVideoTab = false,
  });

  final bool initialVideoTab;

  @override
  State<MemberImprovementScreen> createState() => _MemberImprovementScreenState();
}

class _MemberImprovementScreenState extends State<MemberImprovementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialVideoTab ? 1 : 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!memberDataController.evaluationsTabSynced) {
        await memberDataController.refreshEvaluationsTab();
      }
      await memberDataController.refreshQualitySkillClassification();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Improvement',
          style: dashText(TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          )),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              child: TabBar(
                controller: _tabs,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark ? colors.border : kCyan.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: kAccent,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: dashText(const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
                unselectedLabelStyle: dashText(const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
                tabs: const [
                  Tab(text: 'Photo'),
                  Tab(text: 'Video'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          return TabBarView(
            controller: _tabs,
            children: const [
              _ImprovementTabBody(videoOnly: false),
              _ImprovementTabBody(videoOnly: true),
            ],
          );
        },
      ),
    );
  }
}

class _ImprovementTabBody extends StatelessWidget {
  const _ImprovementTabBody({required this.videoOnly});

  final bool videoOnly;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    final series = comparableImprovementSeries(
      appState.evaluations,
      videoOnly: videoOnly,
    );
    final trend = computeSkillProgressTrend(series);
    final compare = latestVersusPrevious(series);
    final loading = appState.evaluations.isEmpty &&
        !memberDataController.evaluationsTabSynced &&
        memberDataController.evaluationsTabError == null;
    final kind = videoOnly ? 'video' : 'photo';

    if (loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    return ListView(
      padding: mobileScrollPadding(context, top: 12),
      children: [
        MemberDashboardCard(
          showAccentStrip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                videoOnly ? 'Video quality trend' : 'Photo quality trend',
                style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'Comparable released practice scores (Clarity Option C). AI authenticity risk is not included.',
                style: memberDashboardMetaStyle.copyWith(fontSize: 11.5, height: 1.35),
              ),
              Builder(
                builder: (context) {
                  final cls = memberDataController.qualitySkillClassification
                      ?.forMedia(isVideo: videoOnly);
                  if (cls == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Current level: ${cls.title}',
                            style: dashText(const TextStyle(
                              color: kAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            )),
                          ),
                        ),
                        if (cls.progressSummary.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            cls.progressSummary,
                            style: memberDashboardMetaStyle.copyWith(
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (series.length < 2)
                MemberDashboardEmptyState(
                  icon: Icons.show_chart_rounded,
                  iconColor: kCyan,
                  message:
                      'Not enough comparable $kind scores yet. Complete at least 2 eligible $kind evaluations under the current scoring formula. Legacy scores stay separate and are not mixed in.',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        label: 'Latest',
                        value: formatQualityOutOfFive(
                          qualityScoreOutOfFive(compare.latest!),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _DetailMetric(
                        label: 'Previous',
                        value: compare.previous == null
                            ? 'N/A'
                            : formatQualityOutOfFive(
                                qualityScoreOutOfFive(compare.previous!),
                              ),
                      ),
                    ),
                    Expanded(
                      child: _DetailMetric(
                        label: 'Change',
                        value: formatQualityDeltaOutOfFive(compare.deltaPoints),
                        tone: _deltaColor(compare.deltaPoints),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TrendBanner(trend: trend),
                const SizedBox(height: 12),
                MemberImprovementSparkline(
                  valuesOutOfFive: series.map(qualityScoreOutOfFive).toList(),
                  height: 86,
                  lineColor: switch (trend) {
                    SkillProgressTrend.improving => kGreen,
                    SkillProgressTrend.declining => kOrange,
                    _ => kCyan,
                  },
                ),
              ],
            ],
          ),
        ),
        if (series.length >= 2) ...[
          const SizedBox(height: 14),
          Text(
            'Criterion changes',
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Latest vs previous comparable evaluation. N/A metrics are omitted.',
            style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          _CriterionChangesCard(
            changes: criterionLevelChanges(compare.previous, compare.latest),
          ),
          const SizedBox(height: 14),
          Text(
            'Suggestions',
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          _SuggestionsCard(
            latest: compare.latest,
            changes: criterionLevelChanges(compare.previous, compare.latest),
          ),
          const SizedBox(height: 14),
          Text(
            'History',
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...series.reversed.take(12).map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MemberDashboardCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.date,
                            style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatQualityOutOfFive(qualityScoreOutOfFive(e)),
                      style: dashText(TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Color? _deltaColor(double? deltaPoints) {
    if (deltaPoints == null) return null;
    if (deltaPoints >= SkillProgressTrendThresholds.improvingMinDelta) return kGreen;
    if (deltaPoints <= SkillProgressTrendThresholds.decliningMaxDelta) return kOrange;
    return null;
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: memberDashboardMetaStyle.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: dashText(TextStyle(
            color: tone ?? colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          )),
        ),
      ],
    );
  }
}

class _TrendBanner extends StatelessWidget {
  const _TrendBanner({required this.trend});

  final SkillProgressTrend trend;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (trend) {
      SkillProgressTrend.improving => (kGreenDim, kGreen, Icons.trending_up_rounded),
      SkillProgressTrend.declining => (kYellowDim, kOrange, Icons.trending_down_rounded),
      SkillProgressTrend.stable => (kCyanDim, kAccent, Icons.trending_flat_rounded),
      SkillProgressTrend.insufficientData => (
          kSurfaceAlt,
          kTextSecondary,
          Icons.more_horiz_rounded
        ),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? fg.withValues(alpha: 0.14) : bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(
            trend.label,
            style: dashText(TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            )),
          ),
        ],
      ),
    );
  }
}

class _CriterionChangesCard extends StatelessWidget {
  const _CriterionChangesCard({required this.changes});

  final List<({String name, int? previous, int? latest, int? delta, String? suggestion})>
      changes;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    if (changes.isEmpty) {
      return MemberDashboardCard(
        child: Text(
          'Criterion detail is not available for these evaluations yet.',
          style: memberDashboardMetaStyle.copyWith(fontSize: 12),
        ),
      );
    }
    return MemberDashboardCard(
      child: Column(
        children: [
          for (var i = 0; i < changes.length; i++) ...[
            if (i > 0) Divider(height: 14, color: colors.border),
            Row(
              children: [
                Expanded(
                  child: Text(
                    changes[i].name,
                    style: memberDashboardCardTitleStyle.copyWith(fontSize: 12.5),
                  ),
                ),
                Text(
                  changes[i].previous == null ? 'N/A' : '${changes[i].previous}/5',
                  style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  changes[i].latest == null ? 'N/A' : '${changes[i].latest}/5',
                  style: dashText(TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  )),
                ),
                const SizedBox(width: 8),
                _DeltaPill(delta: changes[i].delta),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final int? delta;

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Text(
        '-',
        style: memberDashboardMetaStyle.copyWith(fontSize: 11),
      );
    }
    final positive = delta! > 0;
    final negative = delta! < 0;
    final color = positive ? kGreen : (negative ? kOrange : kTextSecondary);
    final label = positive ? '+$delta' : '$delta';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: dashText(TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        )),
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({
    required this.latest,
    required this.changes,
  });

  final Evaluation? latest;
  final List<({String name, int? previous, int? latest, int? delta, String? suggestion})>
      changes;

  @override
  Widget build(BuildContext context) {
    final tips = <String>[];
    final fromPayload = latest?.parsedEvaluation?.improvementSuggestions.trim();
    if (fromPayload != null && fromPayload.isNotEmpty) {
      tips.add(fromPayload);
    }
    for (final c in changes) {
      if (c.delta != null && c.delta! < 0 && (c.suggestion?.isNotEmpty ?? false)) {
        tips.add('${c.name}: ${c.suggestion}');
      }
    }
    if (tips.isEmpty) {
      for (final c in changes) {
        if (c.suggestion != null && c.suggestion!.isNotEmpty) {
          tips.add('${c.name}: ${c.suggestion}');
        }
        if (tips.length >= 4) break;
      }
    }
    if (tips.isEmpty) {
      return MemberDashboardCard(
        child: Text(
          'Keep practicing with steady framing, even lighting, and sharp focus. Fresh tips appear after comparable evaluations.',
          style: memberDashboardBodyStyle.copyWith(fontSize: 12.5, height: 1.35),
        ),
      );
    }
    final shown = tips.take(5).toList();
    return MemberDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.lightbulb_outline_rounded, size: 15, color: kCyan),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shown[i],
                    style: memberDashboardBodyStyle.copyWith(fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
