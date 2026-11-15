import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/member_improvement_screen.dart';
import 'package:access_mobile/mobile_app/utils/skill_progress_trend.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_improvement_sparkline.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Compact Profile "My Improvement" card — quality trend only (not XP / AI risk).
class MemberImprovementCard extends StatefulWidget {
  const MemberImprovementCard({super.key});

  @override
  State<MemberImprovementCard> createState() => _MemberImprovementCardState();
}

class _MemberImprovementCardState extends State<MemberImprovementCard> {
  /// false = photo, true = video
  bool _videoTab = false;
  bool _prefResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureHistory();
    });
  }

  Future<void> _ensureHistory() async {
    if (!memberDataController.evaluationsTabSynced &&
        memberDataController.evaluationsTabError == null) {
      await memberDataController.refreshEvaluationsTab();
    }
    unawaited(memberDataController.refreshQualitySkillClassification());
    if (!mounted) return;
    _resolveDefaultTab();
  }

  void _resolveDefaultTab() {
    if (_prefResolved) return;
    final photo = comparableImprovementSeries(appState.evaluations, videoOnly: false);
    final video = comparableImprovementSeries(appState.evaluations, videoOnly: true);
    setState(() {
      if (photo.length >= 2) {
        _videoTab = false;
      } else if (video.length >= 2) {
        _videoTab = true;
      } else {
        _videoTab = video.length > photo.length;
      }
      _prefResolved = true;
    });
  }

  Future<void> _openDetails() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => MemberImprovementScreen(
          initialVideoTab: _videoTab,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        if (!_prefResolved && appState.evaluations.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDefaultTab());
        }
        final colors = AccessColors.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final series = comparableImprovementSeries(
          appState.evaluations,
          videoOnly: _videoTab,
        );
        final trend = computeSkillProgressTrend(series);
        final compare = latestVersusPrevious(series);
        final loading = appState.evaluations.isEmpty &&
            !memberDataController.evaluationsTabSynced &&
            memberDataController.evaluationsTabError == null;
        final sparkValues = series.map(qualityScoreOutOfFive).toList();
        final latestFive =
            compare.latest == null ? null : qualityScoreOutOfFive(compare.latest!);
        final previousFive =
            compare.previous == null ? null : qualityScoreOutOfFive(compare.previous!);

        return Semantics(
          label: 'My Improvement',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openDetails,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            colors.surface,
                            Color.lerp(colors.surface, kCyan, 0.08)!,
                          ]
                        : [
                            colors.surface,
                            kCyan.withValues(alpha: 0.07),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? colors.border
                        : kCyan.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kCyan.withValues(alpha: isDark ? 0.08 : 0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: kCyan.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.trending_up_rounded,
                              size: 15,
                              color: kCyan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'My Improvement',
                              style: dashText(TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              )),
                            ),
                          ),
                          Text(
                            'View Details',
                            style: dashText(const TextStyle(
                              color: kAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: kAccent.withValues(alpha: 0.9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MediaToggle(
                        videoSelected: _videoTab,
                        onChanged: (v) => setState(() => _videoTab = v),
                      ),
                      const SizedBox(height: 10),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                          ),
                        )
                      else if (series.length < 2)
                        _CompactEmpty(
                          isVideo: _videoTab,
                          colors: colors,
                        )
                      else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ScoreCell(
                                label: 'Latest',
                                value: latestFive == null
                                    ? 'N/A'
                                    : formatQualityOutOfFive(latestFive),
                                colors: colors,
                              ),
                            ),
                            Expanded(
                              child: _ScoreCell(
                                label: 'Previous',
                                value: previousFive == null
                                    ? 'N/A'
                                    : formatQualityOutOfFive(previousFive),
                                colors: colors,
                              ),
                            ),
                            Expanded(
                              child: _ScoreCell(
                                label: 'Change',
                                value: formatQualityDeltaOutOfFive(compare.deltaPoints),
                                colors: colors,
                                emphasize: true,
                                tone: _deltaTone(compare.deltaPoints),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MemberImprovementSparkline(
                          valuesOutOfFive: sparkValues,
                          height: 78,
                          lineColor: _trendLineColor(trend),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _TrendChip(trend: trend),
                        ),
                        Builder(
                          builder: (context) {
                            final cls = memberDataController
                                .qualitySkillClassification
                                ?.forMedia(isVideo: _videoTab);
                            if (cls == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
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
                                      'Level: ${cls.title}',
                                      style: dashText(const TextStyle(
                                        color: kAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      )),
                                    ),
                                  ),
                                  if (cls.progressSummary.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      cls.progressSummary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: dashText(TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 11,
                                        height: 1.3,
                                        fontWeight: FontWeight.w500,
                                      )),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _trendLineColor(SkillProgressTrend trend) {
    return switch (trend) {
      SkillProgressTrend.improving => kGreen,
      SkillProgressTrend.declining => kOrange,
      SkillProgressTrend.stable => kCyan,
      SkillProgressTrend.insufficientData => kIconInactive,
    };
  }

  Color? _deltaTone(double? deltaPoints) {
    if (deltaPoints == null) return null;
    if (deltaPoints >= SkillProgressTrendThresholds.improvingMinDelta) return kGreen;
    if (deltaPoints <= SkillProgressTrendThresholds.decliningMaxDelta) return kOrange;
    return null;
  }
}

class _MediaToggle extends StatelessWidget {
  const _MediaToggle({
    required this.videoSelected,
    required this.onChanged,
  });

  final bool videoSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSeg(
              label: 'Photo',
              selected: !videoSelected,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleSeg(
              label: 'Video',
              selected: videoSelected,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSeg extends StatelessWidget {
  const _ToggleSeg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: selected ? 0.5 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: dashText(TextStyle(
              color: selected ? kAccent : colors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            )),
          ),
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.label,
    required this.value,
    required this.colors,
    this.emphasize = false,
    this.tone,
  });

  final String label;
  final String value;
  final AccessColors colors;
  final bool emphasize;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: dashText(TextStyle(
            color: colors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          )),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: dashText(TextStyle(
            color: tone ?? colors.textPrimary,
            fontSize: emphasize ? 15 : 14,
            fontWeight: FontWeight.w800,
            height: 1.15,
          )),
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});

  final SkillProgressTrend trend;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (trend) {
      SkillProgressTrend.improving => (
          kGreenDim,
          kGreen,
          Icons.arrow_upward_rounded,
        ),
      SkillProgressTrend.declining => (
          kYellowDim,
          kOrange,
          Icons.arrow_downward_rounded,
        ),
      SkillProgressTrend.stable => (
          kCyanDim,
          kAccent,
          Icons.horizontal_rule_rounded,
        ),
      SkillProgressTrend.insufficientData => (
          kSurfaceAlt,
          kTextSecondary,
          Icons.more_horiz_rounded,
        ),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? fg.withValues(alpha: 0.16) : bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            trend.label,
            style: dashText(TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            )),
          ),
        ],
      ),
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({
    required this.isVideo,
    required this.colors,
  });

  final bool isVideo;
  final AccessColors colors;

  @override
  Widget build(BuildContext context) {
    final kind = isVideo ? 'video' : 'photo';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.show_chart_rounded, size: 18, color: kCyan.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not enough comparable $kind scores yet',
                  style: dashText(TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  )),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete at least 2 eligible $kind evaluations under the current scoring formula to see your trend.',
                  style: dashText(TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
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
