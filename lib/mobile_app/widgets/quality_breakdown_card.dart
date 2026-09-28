import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/eval_trophy_illustration.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';

import 'criterion_score_bar.dart';

/// Mockup-style section: overall score header + quality breakdown rows + legend.
class QualityBreakdownCard extends StatelessWidget {
  const QualityBreakdownCard({
    super.key,
    required this.result,
    this.dense = false,
    this.showCardShell = false,
  });

  final PhotoEvaluationResult result;
  final bool dense;
  final bool showCardShell;

  @override
  Widget build(BuildContext context) {
    final percent = result.overallPercent;
    final levelColor = qualityLevelColor(result.qualityLevel);
    final showTrophy = percent >= 90;
    final qualityHeadline = _qualityHeadline(result.qualityLevel);
    final criteria = result.displayCriteria(isVideo: result.isVideo);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(18, dense ? 16 : 20, 18, dense ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kEvalPrimaryLight,
                kEvalSecondaryLight.withValues(alpha: 0.55),
                kDashCardBg,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Quality Score',
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: dense ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$percent',
                          style: dashText(TextStyle(
                            color: levelColor,
                            fontSize: dense ? 40 : 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            height: 1,
                          )),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            '/100',
                            style: TextStyle(
                              color: kTextSecondary,
                              fontSize: dense ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qualityHeadline,
                      style: dashText(TextStyle(
                        color: levelColor,
                        fontSize: dense ? 14 : 16,
                        fontWeight: FontWeight.w800,
                      )),
                    ),
                  ],
                ),
              ),
              if (showTrophy) ...[
                const SizedBox(width: 8),
                EvalTrophyIllustration(size: dense ? 64 : 72),
              ],
            ],
          ),
        ),
        SizedBox(height: dense ? 14 : 18),
        Text(
          'Quality Breakdown',
          style: dashText(TextStyle(
            color: kDashTextPrimary,
            fontSize: dense ? 14 : 15,
            fontWeight: FontWeight.w800,
          )),
        ),
        SizedBox(height: dense ? 10 : 14),
        CriterionScoresList(
          criteria: criteria,
          isVideo: result.isVideo,
          dense: dense,
          horizontal: false,
          staggerMs: dense ? 50 : 70,
        ),
        SizedBox(height: dense ? 12 : 16),
        const _ScoreRangeLegend(),
      ],
    );

    if (!showCardShell) return content;

    return Container(
      decoration: evalCardDecoration(),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(18, dense ? 14 : 18, 18, dense ? 14 : 18),
      child: content,
    );
  }

  String _qualityHeadline(String level) {
    final trimmed = level.trim();
    if (trimmed.isEmpty) return 'Quality Result';
    return trimmed.toLowerCase().contains('quality') ? trimmed : '$trimmed Quality';
  }
}

class _ScoreRangeLegend extends StatelessWidget {
  const _ScoreRangeLegend();

  static const _items = [
    (color: kRed, label: 'Poor', range: '0–59'),
    (color: kOrange, label: 'Fair', range: '60–74'),
    (color: kBlue, label: 'Good', range: '75–89'),
    (color: kGreen, label: 'Excellent', range: '90–100'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: _items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '${item.label} (${item.range})',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

Color qualityLevelColor(String? level) => switch (level) {
      'Excellent' => kGreen,
      'Good' => kAccent,
      'Fair' => kYellow,
      'Needs Improvement' || 'Poor' => kRed,
      _ => kTextSecondary,
    };
