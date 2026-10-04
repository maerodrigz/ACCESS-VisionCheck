import 'package:flutter/material.dart';

import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// Member-facing integrity banner copy (automated PROBE vs final admin decision).
class MemberIntegrityBannerModel {
  const MemberIntegrityBannerModel({
    required this.heading,
    required this.subtitle,
    required this.detail,
    required this.colorKind,
    required this.iconKind,
    this.secondaryAutomatedLine,
    this.showPendingReviewFooter = false,
    this.pendingReviewFooter,
  });

  final String heading;
  final String subtitle;
  final String detail;
  final MemberIntegrityColorKind colorKind;
  final MemberIntegrityIconKind iconKind;
  final String? secondaryAutomatedLine;
  final bool showPendingReviewFooter;
  final String? pendingReviewFooter;
}

enum MemberIntegrityColorKind { green, yellow, red, accent, neutral }

enum MemberIntegrityIconKind { verified, warning, ai, pending, neutral }

/// Member-facing automated integrity tier (copy only; thresholds unchanged).
String memberAutomatedIntegrityTierLabel(AiDetectionResult automated) {
  if (automated.isDeferredAuthenticity) return 'Needs Review';
  final risk = (automated.riskLevel ?? automated.visualRiskLevel ?? '').toLowerCase();
  if (automated.isAiGenerated || risk == 'high') return 'High AI Risk';
  if (automated.isSuspicious ||
      risk == 'suspicious' ||
      risk == 'medium' ||
      automated.isSourceUnverified) {
    return 'Needs Review';
  }
  if (automated.requiresReview && !automated.isLowProbeRisk) return 'Needs Review';
  return 'Low AI Risk';
}

/// Tier label for saved evaluations (admin review + automated PROBE).
String memberIntegrityTierLabel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) {
    if (MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)) {
      return 'Low AI Risk';
    }
    if (MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus) ||
        MemberReviewStatus.isAdminRejected(adminReviewStatus)) {
      return 'High AI Risk';
    }
    return 'Needs Review';
  }
  if (MemberReviewStatus.isReviewPending(adminReviewStatus)) return 'Needs Review';
  return memberAutomatedIntegrityTierLabel(automated);
}

Color memberIntegrityTierColor(String tierLabel) {
  switch (tierLabel) {
    case 'High AI Risk':
      return kRed;
    case 'Needs Review':
      return kYellow;
    case 'Low AI Risk':
    default:
      return kGreen;
  }
}

String automatedScreeningSecondaryLine(AiDetectionResult automated) {
  final pct = automated.probability != null ? (automated.probability! * 100).round() : null;
  final band = _automatedBandLabel(automated);
  if (pct != null) {
    return 'Automated screening initially reported $band AI authenticity risk ($pct%).';
  }
  return 'Automated screening initially reported $band AI authenticity risk.';
}

String _automatedBandLabel(AiDetectionResult ai) {
  final r = (ai.riskLevel ?? '').toLowerCase();
  if (r == 'high' || ai.isAiGenerated) return 'high';
  if (r == 'suspicious' || ai.isSuspicious) return 'elevated';
  if (r == 'low') return 'low';
  if (ai.isAiGenerated) return 'high';
  if (ai.isSuspicious) return 'elevated';
  return 'elevated';
}

MemberIntegrityBannerModel memberIntegrityBannerModel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
  bool practiceFinalAutomatedCopy = false,
}) {
  final admin = adminReviewStatus;

  if (MemberReviewStatus.isFinalAdminDecision(admin)) {
    if (MemberReviewStatus.isAdminConfirmedHuman(admin)) {
      return MemberIntegrityBannerModel(
        heading: 'Human-Captured',
        subtitle: 'Confirmed by Admin',
        detail: 'This submission was reviewed and confirmed as human-captured.',
        colorKind: MemberIntegrityColorKind.green,
        iconKind: MemberIntegrityIconKind.verified,
        secondaryAutomatedLine: automatedScreeningSecondaryLine(automated),
      );
    }
    if (MemberReviewStatus.isAdminConfirmedAi(admin) || MemberReviewStatus.isAdminRejected(admin)) {
      return MemberIntegrityBannerModel(
        heading: 'AI-Generated / Manipulated',
        subtitle: 'Confirmed by Admin Review',
        detail:
            'An administrator completed review and confirmed this outcome. '
            'This is an administrative decision, not a new automated scan.',
        colorKind: MemberIntegrityColorKind.red,
        iconKind: MemberIntegrityIconKind.ai,
        secondaryAutomatedLine: automatedScreeningSecondaryLine(automated),
      );
    }
    if (MemberReviewStatus.isAcceptedWithWarning(admin)) {
      return MemberIntegrityBannerModel(
        heading: 'Accepted with Warning',
        subtitle: 'Admin Review Complete',
        detail: 'Your submission was reviewed and accepted with an admin warning on record.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.warning,
        secondaryAutomatedLine: automatedScreeningSecondaryLine(automated),
      );
    }
    if (MemberReviewStatus.isReuploadRequested(admin)) {
      return MemberIntegrityBannerModel(
        heading: 'Reupload Requested',
        subtitle: 'Admin Review Complete',
        detail: 'An administrator requested a new upload. See admin remarks if provided.',
        colorKind: MemberIntegrityColorKind.accent,
        iconKind: MemberIntegrityIconKind.neutral,
        secondaryAutomatedLine: automatedScreeningSecondaryLine(automated),
      );
    }
  }

  if (automated.isDeferredAuthenticity && !practiceFinalAutomatedCopy) {
    return MemberIntegrityBannerModel(
      heading: 'AI Authenticity Risk',
      subtitle: 'Pending save',
      detail: automated.detail,
      colorKind: MemberIntegrityColorKind.accent,
      iconKind: MemberIntegrityIconKind.pending,
    );
  }

  if (practiceFinalAutomatedCopy) {
    if (automated.isAiGenerated || (automated.riskLevel ?? '').toLowerCase() == 'high') {
      return MemberIntegrityBannerModel(
        heading: 'AI Authenticity Risk',
        subtitle: 'High Risk — Review Required',
        detail:
            'The automated analysis found elevated AI-generation risk. '
            'Administrative review is required.',
        colorKind: MemberIntegrityColorKind.red,
        iconKind: MemberIntegrityIconKind.ai,
        showPendingReviewFooter: automated.requiresReview,
        pendingReviewFooter:
            'This submission may be flagged for officer review before it counts toward rankings.',
      );
    }
    if (automated.isSourceUnverified) {
      return MemberIntegrityBannerModel(
        heading: 'Source unverified',
        subtitle: 'Review required',
        detail: automated.detail.isNotEmpty
            ? automated.detail
            : 'No reliable original camera provenance was found. Administrative review is required.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.warning,
        showPendingReviewFooter: true,
        pendingReviewFooter: 'This is not a claim that the media is AI-generated.',
      );
    }
    if (automated.isSuspicious || (automated.riskLevel ?? '').toLowerCase() == 'suspicious') {
      return MemberIntegrityBannerModel(
        heading: 'AI Authenticity Risk',
        subtitle: 'Elevated Risk',
        detail:
            'The automated analysis found signals that require review. '
            'This result is not definitive proof of AI generation.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.warning,
        showPendingReviewFooter: automated.requiresReview,
        pendingReviewFooter: 'Officers may review this submission for authenticity.',
      );
    }
    return MemberIntegrityBannerModel(
      heading: 'AI Authenticity Risk',
      subtitle: 'Low Risk',
      detail:
          'No elevated AI-generation risk was detected by the automated analysis. '
          'This is a risk assessment, not proof of origin.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
    );
  }

  if (automated.isSourceUnverified && !MemberReviewStatus.isFinalAdminDecision(admin)) {
    return MemberIntegrityBannerModel(
      heading: 'Source unverified',
      subtitle: 'Review required',
      detail: automated.detail.isNotEmpty
          ? automated.detail
          : 'No reliable original camera provenance was found. Administrative review is required.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
      showPendingReviewFooter: true,
      pendingReviewFooter: 'This is not a claim that the media is AI-generated.',
    );
  }

  if (automated.isAiGenerated || (automated.riskLevel ?? '').toLowerCase() == 'high') {
    return MemberIntegrityBannerModel(
      heading: 'High AI authenticity risk',
      subtitle: 'Review required',
      detail: automated.detail.isNotEmpty ? automated.detail : 'Administrative review is required.',
      colorKind: MemberIntegrityColorKind.red,
      iconKind: MemberIntegrityIconKind.ai,
      showPendingReviewFooter: true,
      pendingReviewFooter:
          'This submission may be flagged for officer review before it counts toward rankings.',
    );
  }

  if (automated.isSuspicious ||
      (automated.riskLevel ?? '').toLowerCase() == 'suspicious' ||
      MemberReviewStatus.isReviewPending(admin)) {
    return MemberIntegrityBannerModel(
      heading: 'Elevated AI authenticity risk',
      subtitle: 'Review recommended',
      detail: automated.detail.isNotEmpty
          ? automated.detail
          : 'The automated analysis found signals that require review.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
      showPendingReviewFooter: true,
      pendingReviewFooter: 'Officers may review this submission for authenticity.',
    );
  }

  final lowSubtitle = automated.isCameraProvenanceStrong ? 'Camera provenance verified' : '';
  return MemberIntegrityBannerModel(
    heading: 'Low AI authenticity risk',
    subtitle: lowSubtitle,
    detail: automated.detail.isNotEmpty
        ? automated.detail
        : 'No elevated AI-generation risk was detected by the automated analysis.',
    colorKind: MemberIntegrityColorKind.green,
    iconKind: MemberIntegrityIconKind.verified,
  );
}

/// Adjust frozen criteria_json flags when admin review has completed.
PhotoEvaluationResult applyAdminReviewToPhotoResult(
  PhotoEvaluationResult result,
  String? adminReviewStatus,
) {
  if (!MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) return result;
  if (MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)) {
    return result.copyWithIntegrity(
      qualityProvisional: false,
      xpPending: false,
      xpEligible: true,
      showQualityFeedback: true,
      memberScoresReleased: true,
      reviewGateMessage: null,
    );
  }
  if (MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus) ||
      MemberReviewStatus.isAdminRejected(adminReviewStatus)) {
    return result.copyWithIntegrity(
      qualityProvisional: false,
      xpPending: true,
      xpEligible: false,
      showQualityFeedback: false,
      memberScoresReleased: false,
    );
  }
  if (MemberReviewStatus.isReuploadRequested(adminReviewStatus)) {
    return result.copyWithIntegrity(
      showQualityFeedback: false,
      memberScoresReleased: false,
      xpPending: true,
      xpEligible: false,
    );
  }
  if (MemberReviewStatus.isAcceptedWithWarning(adminReviewStatus)) {
    return result.copyWithIntegrity(
      qualityProvisional: false,
      xpPending: false,
      xpEligible: true,
      showQualityFeedback: true,
    );
  }
  return result;
}
