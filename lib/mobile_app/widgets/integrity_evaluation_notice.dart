import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: kYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kYellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_rounded, color: kYellow, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Provisional scores',
                  style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: kTextSecondary, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum IntegrityOnlyCardLayout { standard, resultCompact }

/// Member-visible explanation for why admin / integrity review is required.
String memberIntegrityReviewReason(PhotoEvaluationResult result) {
  final stored = result.memberIntegrityMessage?.trim() ?? '';
  if (stored.isNotEmpty) return stored;

  final effective = result.memberIntegrityMessageEffective.trim();
  if (effective.isNotEmpty) return effective;

  final detail = result.aiDetection.detail.trim();
  if (detail.isNotEmpty) return detail;

  final gate = result.reviewGateMessage?.trim() ?? '';
  if (gate.isNotEmpty) return gate;

  if (result.aiDetection.requiresReview) {
    return 'Administrative review is required before scores and coaching are released.';
  }
  return '';
}

/// Shown instead of quality breakdown when AI-generated integrity tier blocks coaching.
class IntegrityOnlyMessageCard extends StatelessWidget {
  const IntegrityOnlyMessageCard({
    super.key,
    required this.result,
    this.layout = IntegrityOnlyCardLayout.standard,
    this.reviewStatus,
    this.adminRemarks,
  });

  final PhotoEvaluationResult result;
  final IntegrityOnlyCardLayout layout;
  final String? reviewStatus;
  final String? adminRemarks;

  @override
  Widget build(BuildContext context) {
    final held = result.scoresHeldForReview && !result.aiDetection.isAiGenerated;
    final compact = layout == IntegrityOnlyCardLayout.resultCompact;
    final reupload = MemberReviewStatus.isReuploadRequested(reviewStatus);
    final remarks = adminRemarks?.trim() ?? '';
    final integrityReason = memberIntegrityReviewReason(result);

    final message = reupload
        ? (remarks.isNotEmpty
            ? remarks
            : 'An administrator reviewed this upload and needs a new file. Upload again from Evaluations.')
        : held
            ? (integrityReason.isNotEmpty
                ? integrityReason
                : (result.reviewGateMessage ??
                    'Scores and coaching stay hidden until an administrator completes review.'))
            : (integrityReason.isNotEmpty ? integrityReason : result.feedback);

    final title = reupload
        ? 'Re-upload requested'
        : held
            ? 'Media under review'
            : 'Integrity review required';
    final subtitle = reupload
        ? 'Replace this file to continue skill progress.'
        : held
            ? 'Quality scores and coaching are held until review completes.'
            : 'Quality coaching is paused until an officer reviews this upload.';
    final accent = reupload ? kAccent : (held ? kYellow : kRed);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 12 : 18,
      ),
      decoration: evalCardDecoration(borderColor: accent.withValues(alpha: compact ? 0.28 : 0.22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 30 : 34,
                height: compact ? 30 : 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shield_outlined, color: accent, size: compact ? 16 : 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: evalCardTitleStyle.copyWith(fontSize: compact ? 14 : 15)),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: evalBodyStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 14),
          Text(
            message,
            style: TextStyle(
              color: kTextPrimary,
              fontSize: compact ? 12 : 13,
              height: compact ? 1.4 : 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!reupload && remarks.isNotEmpty) ...[
            SizedBox(height: compact ? 10 : 12),
            Text(
              'Administrator notes',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: compact ? 10 : 11,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              remarks,
              style: TextStyle(
                color: kTextPrimary,
                fontSize: compact ? 12 : 13,
                height: 1.45,
              ),
            ),
          ],
          if (result.xpPendingEffective && result.xpPointsPreviewEffective > 0) ...[
            SizedBox(height: compact ? 8 : 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAccent.withValues(alpha: 0.22)),
              ),
              child: Text(
                'Up to ${result.xpPointsPreviewEffective} XP may be awarded after review if approved.',
                style: TextStyle(
                  color: kAccent,
                  fontSize: compact ? 11 : 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
