import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Authenticity scan banner for evaluation result + report screens.
class AiDetectionBanner extends StatelessWidget {
  const AiDetectionBanner({
    super.key,
    required this.aiDetection,
    this.compact = false,
    this.minimal = false,
    this.practiceFinalCopy = false,
    this.adminReviewStatus,
  });

  final AiDetectionResult aiDetection;
  final bool compact;
  /// Result screen: tier label + disclaimer only (no long duplicate copy).
  final bool minimal;
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
    final tierLabel = memberIntegrityTierLabel(
      automated: aiDetection,
      adminReviewStatus: adminReviewStatus,
    );
    final color = memberIntegrityTierColor(tierLabel);
    final disclaimer = _disclaimerLine(model, aiDetection);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(minimal ? 8 : (compact ? 10 : 12)),
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
                      'AI INTEGRITY RISK',
                      style: TextStyle(
                        color: kDashTextSecondary,
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tierLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: minimal ? 14 : (compact ? 15 : 17),
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!minimal) ...[
            const SizedBox(height: 8),
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
          ] else if (disclaimer != null) ...[
            const SizedBox(height: 6),
            Text(
              disclaimer,
              style: TextStyle(
                color: kDashTextSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _disclaimerLine(MemberIntegrityBannerModel model, AiDetectionResult ai) {
    if (model.pendingReviewFooter != null && model.pendingReviewFooter!.trim().isNotEmpty) {
      return model.pendingReviewFooter;
    }
    if (model.showPendingReviewFooter || ai.isSuspicious || ai.isSourceUnverified) {
      return 'This is not a claim that the media is AI-generated.';
    }
    if (tierNeedsReviewDisclaimer(model)) {
      return 'This is a risk assessment, not proof of origin.';
    }
    return null;
  }

  static bool tierNeedsReviewDisclaimer(MemberIntegrityBannerModel model) {
    final h = model.heading.toLowerCase();
    return h.contains('risk') || h.contains('review');
  }

  IconData _iconFor(MemberIntegrityIconKind kind) => switch (kind) {
        MemberIntegrityIconKind.verified => Icons.verified_outlined,
        MemberIntegrityIconKind.warning => Icons.warning_amber_rounded,
        MemberIntegrityIconKind.ai => Icons.smart_toy_outlined,
        MemberIntegrityIconKind.pending => Icons.hourglass_top_rounded,
        MemberIntegrityIconKind.neutral => Icons.info_outline_rounded,
      };
}
