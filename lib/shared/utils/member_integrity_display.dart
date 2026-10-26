import 'package:flutter/material.dart';

import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/camera_provenance_member_evidence.dart';

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

/// AI authenticity tier only (excludes camera provenance / admin review gates).
String memberAutomatedAiRiskTierLabel(AiDetectionResult automated) {
  if (automated.isDeferredAuthenticity) return 'Analysis pending';
  if (automated.isAiAnalysisUnavailable) return 'Analysis unavailable';
  final risk = (automated.visualRiskLevel ?? automated.riskLevel ?? '').toLowerCase();
  if (automated.isAiGenerated || risk == 'high') return 'High AI Risk';
  if (automated.isSuspicious || risk == 'suspicious' || risk == 'medium') {
    return 'Needs Review';
  }
  if (risk == 'low' || automated.isLowProbeRisk) return 'Low AI Risk';
  if (automated.requiresReview && !automated.isLowProbeRisk) return 'Needs Review';
  return 'Low AI Risk';
}

/// Member-facing automated integrity tier (copy only; thresholds unchanged).
String memberAutomatedIntegrityTierLabel(AiDetectionResult automated) {
  return memberAutomatedAiRiskTierLabel(automated);
}

String formatMemberAiProbabilityPercent(AiDetectionResult automated) {
  final p = automated.probability;
  if (p == null) return 'N/A';
  final pct = p * 100;
  return '${pct.toStringAsFixed(1)}%';
}

/// Member-facing AI card: score only (no frames, detector names, or admin metadata).
String? memberFacingAiScoreLine(AiDetectionResult automated) {
  if (automated.isAiAnalysisUnavailable || automated.isDeferredAuthenticity) {
    return null;
  }
  if (automated.probability == null) return null;
  return 'AI Score: ${formatMemberAiProbabilityPercent(automated)}';
}

bool memberShouldHideIntegrityOnlyReviewCard({
  required PhotoEvaluationResult result,
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isReuploadRequested(adminReviewStatus)) return false;
  if (result.aiDetection.isAiGenerated) return false;
  if (!result.scoresHeldForReview) return false;
  return memberShowOverallMediaUnderReview(
    automated: result.aiDetection,
    adminReviewStatus: adminReviewStatus,
  );
}

String memberOverallReviewPanelDetail({PhotoEvaluationResult? result}) {
  var detail =
      'Administrative review is required before this submission is finalized. '
      'Scores, feedback, and XP remain pending until an officer completes review.';
  if (result != null &&
      result.xpPendingEffective &&
      result.xpPointsPreviewEffective > 0) {
    detail +=
        ' Up to ${result.xpPointsPreviewEffective} XP may be awarded after review if approved.';
  }
  return detail;
}

bool memberShowOverallMediaUnderReview({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) return false;
  if (MemberReviewStatus.isAutomatedLowAiRisk(adminReviewStatus)) return false;
  return automated.requiresReview ||
      MemberReviewStatus.isReviewPending(adminReviewStatus);
}

bool memberShowCameraProvenancePanel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) return false;
  if (!automated.requiresReview && !MemberReviewStatus.isReviewPending(adminReviewStatus)) {
    return false;
  }
  return automated.isSourceUnverified || automated.isCameraProvenancePartial;
}

/// Positive AI + provenance wording only when automated results already justify both.
bool memberQualifiesForCameraCapturedPositiveMessage({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) return false;
  if (memberAutomatedAiRiskTierLabel(automated) != 'Low AI Risk') return false;
  if (memberShowCameraProvenancePanel(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    return false;
  }
  if (!automated.isCameraProvenanceStrong) return false;
  if (automated.isCameraProvenancePartial || automated.isSourceUnverified) return false;
  return true;
}

bool memberLowAiWithCameraVerificationPending({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (memberAutomatedAiRiskTierLabel(automated) != 'Low AI Risk') return false;
  return memberShowCameraProvenancePanel(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  );
}

MemberIntegrityPanelModel memberCameraProvenanceAdminCompletedPanelModel() {
  return const MemberIntegrityPanelModel(
    sectionTitle: 'Camera Provenance Verification',
    tierLabel: 'Administrator verification completed',
    detail:
        'An administrator completed review using the available evidence. '
        'This reflects an administrative decision, not new automated metadata extraction.',
    colorKind: MemberIntegrityColorKind.green,
    iconKind: MemberIntegrityIconKind.verified,
  );
}

MemberIntegrityPanelModel memberCameraProvenancePanelModel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  const sectionTitle = 'Camera Provenance Verification';
  final evidenceLines = memberCameraProvenanceEvidenceLines(automated);
  final isVideo = memberAiDetectionIsVideoContainerProvenance(automated);

  if (automated.isCameraProvenancePartial) {
    final detail = isVideo
        ? 'Recording-related metadata was detected, but the recording device could not be fully identified. '
            'This does not necessarily mean the video is AI-generated. Administrator verification is required.'
        : 'Original camera device information in this file is incomplete. '
            'Capture source is verified separately from AI risk screening.';
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Camera Verification Pending',
      detail: detail,
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
      evidenceLines: evidenceLines,
    );
  }

  return MemberIntegrityPanelModel(
    sectionTitle: sectionTitle,
    tierLabel: 'No reliable camera provenance',
    detail:
        'No reliable original camera provenance was found in this file. '
        'This is not a claim that the media is AI-generated. Administrator verification is required when review is pending.',
    colorKind: MemberIntegrityColorKind.yellow,
    iconKind: MemberIntegrityIconKind.warning,
    evidenceLines: evidenceLines,
  );
}

MemberIntegrityPanelModel memberAiAuthenticityPanelModel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  const sectionTitle = 'AI Authenticity Assessment';

  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) {
    final tier = memberIntegrityTierLabel(
      automated: automated,
      adminReviewStatus: adminReviewStatus,
    );
    final detail = MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)
        ? 'An administrator completed review using the available evidence. '
            'This reflects an administrative decision, not a new automated scan.'
        : MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus) ||
                MemberReviewStatus.isAdminRejected(adminReviewStatus)
            ? 'An administrator completed review and recorded the outcome below. '
                'This reflects an administrative decision, not a new automated scan.'
            : memberIntegrityBannerModel(
                automated: automated,
                adminReviewStatus: adminReviewStatus,
              ).detail;
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: tier == 'Low AI Risk' && automated.isCameraProvenanceStrong
          ? 'Consistent with Camera-Captured Media'
          : tier,
      detail: detail,
      colorKind: tier == 'High AI Risk'
          ? MemberIntegrityColorKind.red
          : tier == 'Needs Review'
              ? MemberIntegrityColorKind.yellow
              : MemberIntegrityColorKind.green,
      iconKind: tier == 'High AI Risk'
          ? MemberIntegrityIconKind.ai
          : tier == 'Needs Review'
              ? MemberIntegrityIconKind.warning
              : MemberIntegrityIconKind.verified,
      statsLine: memberFacingAiScoreLine(automated),
    );
  }

  if (automated.isAiAnalysisUnavailable) {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Analysis Unavailable',
      detail:
          'AI authenticity analysis could not be completed. '
          "The media's origin cannot be assessed using the available AI result.",
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
    );
  }

  if (automated.isDeferredAuthenticity) {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Analysis pending',
      detail: automated.detail,
      colorKind: MemberIntegrityColorKind.accent,
      iconKind: MemberIntegrityIconKind.pending,
    );
  }

  final aiTier = memberAutomatedAiRiskTierLabel(automated);

  if (memberQualifiesForCameraCapturedPositiveMessage(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Consistent with Camera-Captured Media',
      detail:
          'The media shows characteristics consistent with camera-captured content. '
          'AI analysis indicates low AI-generation risk, and the available camera metadata '
          'supports its reported origin.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
      statsLine: memberFacingAiScoreLine(automated),
    );
  }

  if (memberLowAiWithCameraVerificationPending(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Low AI Risk',
      detail:
          'AI analysis indicates low AI-generation risk. However, camera information is incomplete, '
          "so the media's origin requires further verification.",
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
      statsLine: memberFacingAiScoreLine(automated),
    );
  }

  if (aiTier == 'High AI Risk') {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'High AI Risk',
      detail:
          'The analysis identified elevated AI-generation indicators. '
          'Administrative review is required.',
      colorKind: MemberIntegrityColorKind.red,
      iconKind: MemberIntegrityIconKind.ai,
      statsLine: memberFacingAiScoreLine(automated),
    );
  }

  if (aiTier == 'Needs Review') {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Needs Review',
      detail:
          'The analysis detected patterns that require further verification. '
          'Administrative review is recommended.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
      statsLine: memberFacingAiScoreLine(automated),
    );
  }

  if (aiTier == 'Low AI Risk') {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Low AI Risk',
      detail:
          'AI analysis indicates low AI-generation risk. '
          'This is a screening result only and does not verify capture source by itself.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
      statsLine: memberFacingAiScoreLine(automated),
    );
  }

  return MemberIntegrityPanelModel(
    sectionTitle: sectionTitle,
    tierLabel: aiTier,
    detail: automated.detail.isNotEmpty ? automated.detail : 'Automated authenticity screening is in progress.',
    colorKind: MemberIntegrityColorKind.accent,
    iconKind: MemberIntegrityIconKind.pending,
    statsLine: memberFacingAiScoreLine(automated),
  );
}

class MemberIntegrityPanelModel {
  const MemberIntegrityPanelModel({
    required this.sectionTitle,
    required this.tierLabel,
    required this.detail,
    required this.colorKind,
    required this.iconKind,
    this.statsLine,
    this.evidenceLines = const [],
  });

  final String sectionTitle;
  final String tierLabel;
  final String detail;
  final MemberIntegrityColorKind colorKind;
  final MemberIntegrityIconKind iconKind;
  final String? statsLine;
  final List<String> evidenceLines;
}

/// Tier label for saved evaluations (admin review + automated PROBE).
/// Compact list-row label (Evaluations tab): overall review gate vs AI-only tier.
String memberEvaluationListIntegrityLabel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (memberShowOverallMediaUnderReview(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    return 'Under review';
  }
  return memberIntegrityTierLabel(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  );
}

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
  if (MemberReviewStatus.isReviewPending(adminReviewStatus)) {
    return memberAutomatedAiRiskTierLabel(automated);
  }
  return memberAutomatedAiRiskTierLabel(automated);
}

Color memberIntegrityTierColor(String tierLabel) {
  switch (tierLabel) {
    case 'High AI Risk':
      return kRed;
    case 'Needs Review':
    case 'Analysis unavailable':
    case 'Analysis Unavailable':
      return kYellow;
    case 'Analysis pending':
      return kAccent;
    case 'Under review':
      return kYellow;
    case 'Low AI Risk':
    case 'Consistent with Camera-Captured Media':
    default:
      return kGreen;
  }
}

String automatedScreeningSecondaryLine(AiDetectionResult automated) {
  final pct = automated.probability != null ? formatMemberAiProbabilityPercent(automated) : null;
  final band = _automatedBandLabel(automated);
  if (pct != null) {
    return 'Automated screening initially reported $band AI authenticity risk ($pct).';
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

  if (MemberReviewStatus.isAutomatedLowAiRisk(admin)) {
    return MemberIntegrityBannerModel(
      heading: 'Low AI authenticity risk',
      subtitle: 'Auto-cleared',
      detail:
          'Automated screening found low AI-generation risk with acceptable provenance. '
          'No administrator review is required for this submission.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
      secondaryAutomatedLine: automatedScreeningSecondaryLine(automated),
    );
  }

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
          'Automated screening only. This is not confirmation that media is AI-generated. '
          'Officers may review before it counts toward rankings.',
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
  if (MemberReviewStatus.isAutomatedLowAiRisk(adminReviewStatus)) {
    return result.copyWithIntegrity(
      qualityProvisional: false,
      xpPending: false,
      xpEligible: true,
      showQualityFeedback: true,
      memberScoresReleased: true,
      reviewGateMessage: '',
      memberIntegrityMessage: '',
    );
  }
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
