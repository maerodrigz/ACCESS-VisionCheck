import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Compact media integrity status for the member Evaluation Result screen.
class EvaluationResultMediaCheckCard extends StatelessWidget {
  const EvaluationResultMediaCheckCard({
    super.key,
    required this.result,
    this.adminReviewStatus,
  });

  final PhotoEvaluationResult result;
  final String? adminReviewStatus;

  static const _disclaimer =
      'Automated screening looks for common signs of edited or AI-generated media. '
      'It cannot prove a photo or video is authentic.';

  @override
  Widget build(BuildContext context) {
    final model = memberEvaluationResultMediaCheck(
      automated: result.aiDetection,
      adminReviewStatus: adminReviewStatus,
      evaluationResult: result,
    );
    final accent = memberIntegrityColorKindToColor(model.colorKind);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(model.iconKind), size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media Check',
                      style: evalSectionTitleStyle.copyWith(fontSize: 13, color: kTextSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.statusLabel,
                      style: evalCardTitleStyle.copyWith(fontSize: 15, color: accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            model.summary,
            style: evalBodyStyle.copyWith(fontSize: 12, height: 1.45, color: kTextPrimary),
          ),
          if (model.detail != null && model.detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              model.detail!.trim(),
              style: memberDashboardMetaStyle.copyWith(
                fontSize: 11,
                height: 1.4,
                color: kTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _disclaimer,
            style: memberDashboardMetaStyle.copyWith(fontSize: 10, height: 1.35, color: kTextSecondary),
          ),
        ],
      ),
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
