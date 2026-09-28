import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Shown when integrity review makes quality scores provisional.
class IntegrityProvisionalBanner extends StatelessWidget {
  const IntegrityProvisionalBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kYellow.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_rounded, color: kYellow.withValues(alpha: 0.95), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Provisional scores',
                  style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of quality breakdown when AI-generated integrity tier blocks coaching.
class IntegrityOnlyMessageCard extends StatelessWidget {
  const IntegrityOnlyMessageCard({super.key, required this.result});

  final PhotoEvaluationResult result;

  @override
  Widget build(BuildContext context) {
    final held = result.scoresHeldForReview && !result.aiDetection.isAiGenerated;
    final message = held
        ? (result.reviewGateMessage ??
            'This submission requires administrative review before its evaluation score and feedback can be released.')
        : (result.memberIntegrityMessageEffective.isNotEmpty
            ? result.memberIntegrityMessageEffective
            : result.feedback);

    final title = held ? 'Media Under Review' : 'Integrity review required';
    final subtitle = held
        ? 'Quality scores and coaching are held until review completes.'
        : 'Quality coaching is paused until an officer reviews this upload.';
    final accent = held ? kYellow : kRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: evalCardDecoration(borderColor: accent.withValues(alpha: 0.22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shield_outlined, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: evalCardTitleStyle.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: evalBodyStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.55, fontWeight: FontWeight.w500),
          ),
          if (result.xpPendingEffective && result.xpPointsPreviewEffective > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAccent.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Up to ${result.xpPointsPreviewEffective} XP may be awarded if your media is verified as authentic.',
                style: const TextStyle(color: kTextSecondary, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
