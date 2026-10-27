import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Compact integrity block for the saved Evaluation Report (details live in Detailed Analysis).
class EvaluationReportIntegrityCompact extends StatelessWidget {
  const EvaluationReportIntegrityCompact({
    super.key,
    required this.result,
    this.adminReviewStatus,
  });

  final PhotoEvaluationResult result;
  final String? adminReviewStatus;

  @override
  Widget build(BuildContext context) {
    final ai = result.aiDetection;
    final verification = memberReportVerificationStatus(
      automated: ai,
      adminReviewStatus: adminReviewStatus,
      evaluationResult: result,
    );
    final aiTier = memberAutomatedAiRiskTierLabel(ai);
    final aiColor = memberIntegrityTierColor(aiTier);
    final provLabel = memberCompactProvenanceStatusLabel(ai);
    final provBrief = memberCompactProvenanceBrief(ai, adminReviewStatus: adminReviewStatus);
    final provColor = provLabel == 'Strong' ? kGreen : kYellow;
    final xp = memberReportXpStatus(result, adminReviewStatus: adminReviewStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactReportCard(
          sectionLabel: 'Verification Status',
          title: verification.title,
          detail: verification.explanation,
          accentColor: memberIntegrityColorKindToColor(verification.colorKind),
          icon: _iconFor(verification.iconKind),
        ),
        const SizedBox(height: 8),
        _CompactReportCard(
          sectionLabel: 'Integrity Assessment',
          title: aiTier,
          detail: provBrief,
          accentColor: aiColor,
          icon: Icons.shield_outlined,
          statsLine: memberFacingAiScoreLine(ai),
          subRows: [
            _SubRow(label: 'Camera provenance', value: provLabel, valueColor: provColor),
          ],
        ),
        const SizedBox(height: 8),
        _CompactReportCard(
          sectionLabel: 'XP Status',
          title: xp.headline,
          detail: xp.detail,
          accentColor: memberIntegrityColorKindToColor(xp.colorKind),
          icon: Icons.military_tech_outlined,
        ),
      ],
    );
  }

  IconData _iconFor(MemberIntegrityIconKind kind) => switch (kind) {
        MemberIntegrityIconKind.verified => Icons.verified_outlined,
        MemberIntegrityIconKind.warning => Icons.warning_amber_rounded,
        MemberIntegrityIconKind.ai => Icons.smart_toy_outlined,
        MemberIntegrityIconKind.pending => Icons.hourglass_top_rounded,
        MemberIntegrityIconKind.neutral => Icons.info_outline_rounded,
      };
}

class _SubRow {
  const _SubRow({required this.label, required this.value, required this.valueColor});

  final String label;
  final String value;
  final Color valueColor;
}

class _CompactReportCard extends StatelessWidget {
  const _CompactReportCard({
    required this.sectionLabel,
    required this.title,
    required this.detail,
    required this.accentColor,
    required this.icon,
    this.statsLine,
    this.subRows = const [],
  });

  final String sectionLabel;
  final String title;
  final String detail;
  final Color accentColor;
  final IconData icon;
  final String? statsLine;
  final List<_SubRow> subRows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionLabel,
                      style: const TextStyle(
                        color: kDashTextSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (statsLine != null) ...[
            const SizedBox(height: 6),
            Text(
              statsLine!,
              style: const TextStyle(
                color: kDashTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          for (final row in subRows) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  row.label,
                  style: const TextStyle(color: kDashTextSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  row.value,
                  style: TextStyle(color: row.valueColor, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(color: kDashTextSecondary, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }
}
