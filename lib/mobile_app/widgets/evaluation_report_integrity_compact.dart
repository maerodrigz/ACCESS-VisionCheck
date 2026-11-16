import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Member saved report: one compact review decision (status, reason, remarks, XP).
class EvaluationReportIntegrityCompact extends StatelessWidget {
  const EvaluationReportIntegrityCompact({
    super.key,
    required this.result,
    this.adminReviewStatus,
    this.adminRemarks,
    this.showXpOutcome = true,
  });

  final PhotoEvaluationResult result;
  final String? adminReviewStatus;
  final String? adminRemarks;

  /// When false, XP line is omitted (shown in a higher-level summary card).
  final bool showXpOutcome;

  @override
  Widget build(BuildContext context) {
    final decision = memberEvaluationReportReviewDecision(
      result: result,
      adminReviewStatus: adminReviewStatus,
      adminRemarks: adminRemarks,
    );
    final accent = memberIntegrityColorKindToColor(decision.colorKind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review decision',
          style: evalSectionTitleStyle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(decision.iconKind), size: 20, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decision.statusTitle,
                      style: evalCardTitleStyle.copyWith(fontSize: 15, color: accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                decision.reason,
                style: evalBodyStyle.copyWith(fontSize: 12, height: 1.45, color: kTextPrimary),
              ),
              if (decision.administratorRemarks != null &&
                  decision.administratorRemarks!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Administrator remarks',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  decision.administratorRemarks!.trim(),
                  style: evalBodyStyle.copyWith(fontSize: 12, height: 1.45),
                ),
              ],
              if (showXpOutcome) ...[
                const SizedBox(height: 10),
                Text(
                  decision.xpOutcomeLine,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(MemberIntegrityIconKind kind) => switch (kind) {
        MemberIntegrityIconKind.verified => Icons.verified_outlined,
        MemberIntegrityIconKind.warning => Icons.warning_amber_rounded,
        MemberIntegrityIconKind.ai => Icons.flag_outlined,
        MemberIntegrityIconKind.pending => Icons.hourglass_top_rounded,
        MemberIntegrityIconKind.neutral => Icons.upload_rounded,
      };
}
