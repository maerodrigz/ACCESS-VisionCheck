import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Authenticity scan banner for evaluation result + report screens.
class AiDetectionBanner extends StatelessWidget {
  const AiDetectionBanner({
    super.key,
    required this.aiDetection,
    this.compact = false,
    this.practiceFinalCopy = false,
    this.adminReviewStatus,
  });

  final AiDetectionResult aiDetection;
  final bool compact;
  /// Member practice flow immediately after background eval (no admin review yet).
  final bool practiceFinalCopy;
  /// Authoritative admin review from GET /evaluations (`review_status`).
  final String? adminReviewStatus;

  @override
  Widget build(BuildContext context) {
    final model = memberIntegrityBannerModel(
      automated: aiDetection,
      adminReviewStatus: adminReviewStatus,
      practiceFinalAutomatedCopy: practiceFinalCopy,
    );
    final color = _colorFor(model.colorKind);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(model.iconKind), size: compact ? 16 : 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.heading,
                      style: TextStyle(
                        color: color,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (model.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        model.subtitle,
                        style: TextStyle(
                          color: color,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            model.detail,
            style: TextStyle(
              color: kDashTextSecondary,
              fontSize: compact ? 11 : 12,
              height: 1.35,
            ),
          ),
          if (model.secondaryAutomatedLine != null) ...[
            const SizedBox(height: 8),
            Text(
              model.secondaryAutomatedLine!,
              style: TextStyle(
                color: kDashTextSecondary.withValues(alpha: 0.85),
                fontSize: compact ? 10 : 11,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (model.showPendingReviewFooter && model.pendingReviewFooter != null) ...[
            const SizedBox(height: 6),
            Text(
              model.pendingReviewFooter!,
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorFor(MemberIntegrityColorKind kind) => switch (kind) {
        MemberIntegrityColorKind.green => kGreen,
        MemberIntegrityColorKind.yellow => kYellow,
        MemberIntegrityColorKind.red => kRed,
        MemberIntegrityColorKind.accent => kAccent,
        MemberIntegrityColorKind.neutral => kDashTextSecondary,
      };

  IconData _iconFor(MemberIntegrityIconKind kind) => switch (kind) {
        MemberIntegrityIconKind.verified => Icons.verified_outlined,
        MemberIntegrityIconKind.warning => Icons.warning_amber_rounded,
        MemberIntegrityIconKind.ai => Icons.smart_toy_outlined,
        MemberIntegrityIconKind.pending => Icons.hourglass_top_rounded,
        MemberIntegrityIconKind.neutral => Icons.info_outline_rounded,
      };
}
