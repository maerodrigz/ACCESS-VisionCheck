import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_supplementary_insights_display.dart';
import 'package:flutter/material.dart';

const _coachingDisclaimer =
    'Coaching only. These insights do not affect your official quality score.';

/// Collapsed-by-default coaching block on Evaluation Result / Report.
class AdditionalQualityInsightsPanel extends StatefulWidget {
  const AdditionalQualityInsightsPanel({
    super.key,
    required this.insights,
  });

  final AdditionalQualityInsights insights;

  @override
  State<AdditionalQualityInsightsPanel> createState() => _AdditionalQualityInsightsPanelState();
}

class _AdditionalQualityInsightsPanelState extends State<AdditionalQualityInsightsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.insights.hasDisplayableData) return const SizedBox.shrink();

    final count = supplementaryInsightVisibleCount(widget.insights);
    final collapsedHint = count == 1
        ? '1 coaching hint'
        : '$count coaching hints';

    return Container(
      width: double.infinity,
      decoration: evalCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 18, color: kAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Quality Insights',
                            style: evalSectionTitleStyle.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _expanded ? _coachingDisclaimer : '$collapsedHint · $_coachingDisclaimer',
                            style: evalSectionSubtitleStyle.copyWith(
                              fontSize: 11,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: kTextSecondary,
                      size: 22,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  if (_showInsight(widget.insights.colorBalance)) ...[
                    _InsightRow(
                      kind: SupplementaryInsightKind.colorBalance,
                      insight: widget.insights.colorBalance!,
                    ),
                    if (_showInsight(widget.insights.compositionFraming) ||
                        _showInsight(widget.insights.motionStability))
                      const SizedBox(height: 10),
                  ],
                  if (_showInsight(widget.insights.compositionFraming)) ...[
                    _InsightRow(
                      kind: SupplementaryInsightKind.compositionFraming,
                      insight: widget.insights.compositionFraming!,
                    ),
                    if (_showInsight(widget.insights.motionStability)) const SizedBox(height: 10),
                  ],
                  if (_showInsight(widget.insights.motionStability))
                    _InsightRow(
                      kind: SupplementaryInsightKind.cameraMovement,
                      insight: widget.insights.motionStability!,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _showInsight(SupplementaryQualityInsight? insight) =>
      insight != null && !insight.isUnavailable && insight.feedback.trim().isNotEmpty;
}

/// Full API feedback for Detailed Analysis (Summary tab).
class AdditionalQualityInsightsDetailPanel extends StatelessWidget {
  const AdditionalQualityInsightsDetailPanel({
    super.key,
    required this.insights,
  });

  final AdditionalQualityInsights insights;

  @override
  Widget build(BuildContext context) {
    if (!insights.hasDisplayableData) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: evalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Quality Insights',
            style: evalSectionTitleStyle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _coachingDisclaimer,
            style: evalSectionSubtitleStyle.copyWith(fontSize: 11, color: kTextSecondary),
          ),
          if (insights.framesAnalyzed != null && insights.framesAnalyzed! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Frames sampled for coaching: ${insights.framesAnalyzed}',
              style: evalSectionSubtitleStyle.copyWith(fontSize: 10, color: kTextSecondary),
            ),
          ],
          const SizedBox(height: 12),
          if (_show(insights.colorBalance)) ...[
            _DetailRow(
              kind: SupplementaryInsightKind.colorBalance,
              insight: insights.colorBalance!,
            ),
            if (_show(insights.compositionFraming) || _show(insights.motionStability))
              const SizedBox(height: 12),
          ],
          if (_show(insights.compositionFraming)) ...[
            _DetailRow(
              kind: SupplementaryInsightKind.compositionFraming,
              insight: insights.compositionFraming!,
            ),
            if (_show(insights.motionStability)) const SizedBox(height: 12),
          ],
          if (_show(insights.motionStability))
            _DetailRow(
              kind: SupplementaryInsightKind.cameraMovement,
              insight: insights.motionStability!,
            ),
        ],
      ),
    );
  }

  bool _show(SupplementaryQualityInsight? insight) =>
      insight != null && !insight.isUnavailable && insight.feedback.trim().isNotEmpty;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.kind,
    required this.insight,
  });

  final SupplementaryInsightKind kind;
  final SupplementaryQualityInsight insight;

  @override
  Widget build(BuildContext context) {
    final title = supplementaryInsightDisplayTitle(kind);
    final line = supplementaryInsightConciseLine(insight, kind: kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          insight.headline,
          style: const TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w600),
        ),
        if (line.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            line,
            style: const TextStyle(fontSize: 12, height: 1.35, color: kTextSecondary),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.kind,
    required this.insight,
  });

  final SupplementaryInsightKind kind;
  final SupplementaryQualityInsight insight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          supplementaryInsightDisplayTitle(kind),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          insight.headline,
          style: const TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          insight.feedback,
          style: const TextStyle(fontSize: 12, height: 1.45, color: kTextSecondary),
        ),
      ],
    );
  }
}
