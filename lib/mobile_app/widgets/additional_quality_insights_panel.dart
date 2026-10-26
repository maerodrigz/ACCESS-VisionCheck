import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:flutter/material.dart';

class AdditionalQualityInsightsPanel extends StatelessWidget {
  const AdditionalQualityInsightsPanel({
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
            'Supplementary coaching only. These insights do not change your official score.',
            style: evalSectionSubtitleStyle.copyWith(fontSize: 11, color: kTextSecondary),
          ),
          const SizedBox(height: 12),
          if (_showInsight(insights.colorBalance)) ...[
            _InsightRow(
              title: 'Color Balance',
              insight: insights.colorBalance!,
            ),
            if (_showInsight(insights.compositionFraming)) const SizedBox(height: 10),
          ],
          if (_showInsight(insights.compositionFraming)) ...[
            _InsightRow(
              title: 'Composition / Framing',
              insight: insights.compositionFraming!,
            ),
            if (_showInsight(insights.motionStability)) const SizedBox(height: 10),
          ],
          if (_showInsight(insights.motionStability))
            _InsightRow(
              title: 'Motion Stability',
              insight: insights.motionStability!,
            ),
        ],
      ),
    );
  }

  bool _showInsight(SupplementaryQualityInsight? insight) =>
      insight != null && !insight.isUnavailable && insight.feedback.trim().isNotEmpty;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.title,
    required this.insight,
  });

  final String title;
  final SupplementaryQualityInsight insight;

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          insight.feedback,
          style: const TextStyle(fontSize: 12, height: 1.35, color: kTextSecondary),
        ),
      ],
    );
  }
}
