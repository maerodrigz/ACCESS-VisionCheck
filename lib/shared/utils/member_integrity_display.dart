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
    sectionTitle: 'Camera Metadata / Provenance',
    tierLabel: 'Administrator verification completed',
    detail:
        'An administrator completed review using the available evidence. '
        'This reflects an administrative decision, not new automated metadata extraction.',
    colorKind: MemberIntegrityColorKind.green,
    iconKind: MemberIntegrityIconKind.verified,
  );
}

/// Admin queue / outcome only (independent of AI risk and camera metadata tiers).
MemberIntegrityPanelModel? memberAdminVerificationPanelModel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
  PhotoEvaluationResult? evaluationResult,
}) {
  if (MemberReviewStatus.isAutomatedLowAiRisk(adminReviewStatus)) {
    return null;
  }

  const sectionTitle = 'Admin Verification Status';

  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) {
    if (MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)) {
      return const MemberIntegrityPanelModel(
        sectionTitle: sectionTitle,
        tierLabel: 'Verified as human',
        detail:
            'An administrator verified this submission as human-captured. '
            'This is separate from the automated AI risk and camera metadata results below.',
        colorKind: MemberIntegrityColorKind.green,
        iconKind: MemberIntegrityIconKind.verified,
      );
    }
    if (MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus) ||
        MemberReviewStatus.isAdminRejected(adminReviewStatus)) {
      return const MemberIntegrityPanelModel(
        sectionTitle: sectionTitle,
        tierLabel: 'Admin review complete',
        detail:
            'An administrator completed review and recorded the outcome below. '
            'This reflects an administrative decision, not a new automated scan.',
        colorKind: MemberIntegrityColorKind.red,
        iconKind: MemberIntegrityIconKind.ai,
      );
    }
    if (MemberReviewStatus.isAcceptedWithWarning(adminReviewStatus)) {
      return const MemberIntegrityPanelModel(
        sectionTitle: sectionTitle,
        tierLabel: 'Accepted with warning',
        detail: 'Your submission was reviewed and accepted with an admin warning on record.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.warning,
      );
    }
    if (MemberReviewStatus.isReuploadRequested(adminReviewStatus)) {
      return const MemberIntegrityPanelModel(
        sectionTitle: sectionTitle,
        tierLabel: 'Reupload requested',
        detail: 'An administrator requested a new upload. See admin remarks if provided.',
        colorKind: MemberIntegrityColorKind.accent,
        iconKind: MemberIntegrityIconKind.neutral,
      );
    }
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Admin review complete',
      detail: memberIntegrityBannerModel(
        automated: automated,
        adminReviewStatus: adminReviewStatus,
      ).detail,
      colorKind: MemberIntegrityColorKind.neutral,
      iconKind: MemberIntegrityIconKind.verified,
    );
  }

  if (!memberShowOverallMediaUnderReview(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    return null;
  }

  return MemberIntegrityPanelModel(
    sectionTitle: sectionTitle,
    tierLabel: 'Pending Verification',
    detail:
        'This submission is waiting for an administrator to complete verification. '
        '${memberOverallReviewPanelDetail(result: evaluationResult)}',
    colorKind: MemberIntegrityColorKind.yellow,
    iconKind: MemberIntegrityIconKind.pending,
  );
}

/// Overall submission workflow label (evaluations list and summary chips).
String memberSubmissionWorkflowStatusLabel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (automated.isDeferredAuthenticity) return 'Processing';
  if (MemberReviewStatus.isReuploadRequested(adminReviewStatus)) {
    return 'Re-upload Required';
  }
  if (MemberReviewStatus.isAdminRejected(adminReviewStatus)) return 'Rejected';
  if (MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)) return 'Verified';
  if (MemberReviewStatus.isAcceptedWithWarning(adminReviewStatus)) return 'Verified';
  if (MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus)) return 'Rejected';
  if (MemberReviewStatus.isAutomatedLowAiRisk(adminReviewStatus) &&
      !memberShowOverallMediaUnderReview(
        automated: automated,
        adminReviewStatus: adminReviewStatus,
      )) {
    return 'Verified';
  }
  if (memberShowOverallMediaUnderReview(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    return 'Pending Verification';
  }
  if (automated.isAiAnalysisUnavailable) return 'Pending Verification';
  return 'Verified';
}

bool memberProvenancePartialAndroidPendingReview({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isFinalAdminDecision(adminReviewStatus)) return false;
  if (memberAutomatedAiRiskTierLabel(automated) != 'Low AI Risk') return false;
  if (!automated.isProvenancePartialAndroidHold) return false;
  return memberShowOverallMediaUnderReview(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  );
}

/// Camera metadata classification on the result screen (including after admin verification).
bool memberShowCameraMetadataPanel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  if (automated.isCameraProvenancePartial ||
      automated.isSourceUnverified ||
      automated.isCameraProvenanceAbsent) {
    return true;
  }
  if (automated.isCameraProvenanceStrong &&
      !memberShowOverallMediaUnderReview(
        automated: automated,
        adminReviewStatus: adminReviewStatus,
      )) {
    return true;
  }
  return false;
}

MemberIntegrityPanelModel memberCameraProvenancePanelModel({
  required AiDetectionResult automated,
  String? adminReviewStatus,
}) {
  const sectionTitle = 'Camera Metadata / Provenance';
  final evidenceLines = memberCameraProvenanceEvidenceLines(automated);
  final isVideo = memberAiDetectionIsVideoContainerProvenance(automated);
  final adminComplete = MemberReviewStatus.isFinalAdminDecision(adminReviewStatus);
  final reviewPending = memberShowOverallMediaUnderReview(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  );

  if (automated.isCameraProvenancePartial) {
    final detail = isVideo
        ? 'Recording metadata was detected (such as timestamp or Android version), but camera manufacturer and model are not available in this file. '
            'Incomplete metadata does not mean the video is AI-generated.'
        : 'Some camera metadata is present, but manufacturer and model information is incomplete or missing in this file. '
            'Incomplete metadata does not mean the photo is AI-generated.';
    if (reviewPending && !adminComplete) {
      return MemberIntegrityPanelModel(
        sectionTitle: sectionTitle,
        tierLabel: 'Partial metadata · verification pending',
        detail: '$detail Administrator verification is still required.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.warning,
        evidenceLines: evidenceLines,
      );
    }
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Partial camera metadata',
      detail: detail,
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
      evidenceLines: evidenceLines,
    );
  }

  if (automated.isCameraProvenanceStrong) {
    return MemberIntegrityPanelModel(
      sectionTitle: sectionTitle,
      tierLabel: 'Strong camera metadata',
      detail:
          'Original capture metadata met automated provenance checks. '
          'This supports authenticity screening but is not a substitute for officer review when required.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
      evidenceLines: evidenceLines,
    );
  }

  final absentDetail =
      'No reliable original camera provenance was found in this file. '
      'This is not a claim that the media is AI-generated.';
  return MemberIntegrityPanelModel(
    sectionTitle: sectionTitle,
    tierLabel: 'No reliable camera provenance',
    detail: reviewPending && !adminComplete
        ? '$absentDetail Administrator verification is still required.'
        : absentDetail,
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
          'AI analysis indicates low AI-generation risk. '
          'Camera metadata is assessed separately below and does not change this AI screening result.',
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
  return memberSubmissionWorkflowStatusLabel(
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
    case 'Pending Verification':
    case 'Processing':
    case 'Re-upload Required':
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

  if (memberProvenancePartialAndroidPendingReview(
    automated: automated,
    adminReviewStatus: admin,
  )) {
    return MemberIntegrityBannerModel(
      heading: 'Pending Verification',
      subtitle: 'Low AI authenticity risk',
      detail:
          'Automated screening shows low AI-generation risk. Some Android recording metadata '
          'is present, but camera make and model are not in this file. This is not treated as '
          'AI-generated content. An officer must still confirm the file before scores and XP are released.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.pending,
      showPendingReviewFooter: true,
      pendingReviewFooter:
          'Scores and XP stay pending until verification completes.',
      secondaryAutomatedLine: automatedScreeningSecondaryLine(automated),
    );
  }

  if (automated.isSourceUnverified && !MemberReviewStatus.isFinalAdminDecision(admin)) {
    return MemberIntegrityBannerModel(
      heading: 'Pending Verification',
      subtitle: 'Source metadata incomplete',
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

/// Compact evaluation report: verification title + one-line explanation.
class MemberReportVerificationStatus {
  const MemberReportVerificationStatus({
    required this.title,
    required this.explanation,
    required this.colorKind,
    required this.iconKind,
  });

  final String title;
  final String explanation;
  final MemberIntegrityColorKind colorKind;
  final MemberIntegrityIconKind iconKind;
}

MemberReportVerificationStatus memberReportVerificationStatus({
  required AiDetectionResult automated,
  String? adminReviewStatus,
  PhotoEvaluationResult? evaluationResult,
}) {
  if (automated.isDeferredAuthenticity) {
    return const MemberReportVerificationStatus(
      title: 'Processing',
      explanation: 'Authenticity screening is still running for this submission.',
      colorKind: MemberIntegrityColorKind.accent,
      iconKind: MemberIntegrityIconKind.pending,
    );
  }
  if (MemberReviewStatus.isReuploadRequested(adminReviewStatus)) {
    return const MemberReportVerificationStatus(
      title: 'Re-upload Required',
      explanation: 'An administrator needs a new file before this evaluation can continue.',
      colorKind: MemberIntegrityColorKind.accent,
      iconKind: MemberIntegrityIconKind.neutral,
    );
  }
  if (MemberReviewStatus.isAdminRejected(adminReviewStatus) ||
      MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus)) {
    return const MemberReportVerificationStatus(
      title: 'Rejected',
      explanation: 'An administrator completed review and did not approve this submission for scoring or XP.',
      colorKind: MemberIntegrityColorKind.red,
      iconKind: MemberIntegrityIconKind.ai,
    );
  }
  if (MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)) {
    return const MemberReportVerificationStatus(
      title: 'Verified as Human',
      explanation: 'An administrator verified this upload as human-captured.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
    );
  }
  if (MemberReviewStatus.isAcceptedWithWarning(adminReviewStatus)) {
    return const MemberReportVerificationStatus(
      title: 'Verified as Human',
      explanation: 'Review completed and accepted with an admin warning on record.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
    );
  }
  if (MemberReviewStatus.isAutomatedLowAiRisk(adminReviewStatus)) {
    return const MemberReportVerificationStatus(
      title: 'Verified',
      explanation: 'Auto-cleared under integrity policy. No administrator review was required.',
      colorKind: MemberIntegrityColorKind.green,
      iconKind: MemberIntegrityIconKind.verified,
    );
  }
  if (memberShowOverallMediaUnderReview(
    automated: automated,
    adminReviewStatus: adminReviewStatus,
  )) {
    if (memberProvenancePartialAndroidPendingReview(
      automated: automated,
      adminReviewStatus: adminReviewStatus,
    )) {
      return const MemberReportVerificationStatus(
        title: 'Pending Verification',
        explanation:
            'Low AI risk, but camera metadata is incomplete. This is not treated as AI-generated; an officer must still confirm the file.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.pending,
      );
    }
    final aiTier = memberAutomatedAiRiskTierLabel(automated);
    if (aiTier == 'High AI Risk' || aiTier == 'Needs Review') {
      return MemberReportVerificationStatus(
        title: 'Pending Verification',
        explanation: aiTier == 'High AI Risk'
            ? 'Elevated AI-generation risk requires an administrator decision before scores and XP are final.'
            : 'Elevated screening signals require administrator review before scores and XP are final.',
        colorKind: MemberIntegrityColorKind.yellow,
        iconKind: MemberIntegrityIconKind.pending,
      );
    }
    return MemberReportVerificationStatus(
      title: 'Pending Verification',
      explanation: evaluationResult != null
          ? 'Scores and XP stay pending until an administrator completes verification.'
          : 'Administrative verification is required before this submission is finalized.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.pending,
    );
  }
  if (automated.isAiAnalysisUnavailable) {
    return const MemberReportVerificationStatus(
      title: 'Pending Verification',
      explanation: 'AI authenticity screening did not complete; administrator review is required.',
      colorKind: MemberIntegrityColorKind.yellow,
      iconKind: MemberIntegrityIconKind.warning,
    );
  }
  return const MemberReportVerificationStatus(
    title: 'Verified',
    explanation: 'No administrator review is required for this submission.',
    colorKind: MemberIntegrityColorKind.green,
    iconKind: MemberIntegrityIconKind.verified,
  );
}

String memberCompactProvenanceStatusLabel(AiDetectionResult automated) {
  if (automated.isCameraProvenanceStrong) return 'Strong';
  if (automated.isCameraProvenancePartial) return 'Partial';
  return 'Unavailable';
}

String memberCompactProvenanceBrief(
  AiDetectionResult automated, {
  String? adminReviewStatus,
}) {
  if (automated.isCameraProvenanceStrong) {
    return 'Camera or container metadata supports the reported capture source.';
  }
  if (automated.isCameraProvenancePartial) {
    return memberAiDetectionIsVideoContainerProvenance(automated)
        ? 'Some recording metadata is present; missing make/model is not proof of AI generation.'
        : 'Some camera metadata is present; incomplete tags are not proof of AI generation.';
  }
  return 'Reliable in-camera provenance was not found. This alone is not proof of AI generation.';
}

/// Compact XP line for evaluation report (never treats preview as awarded XP).
class MemberReportXpStatus {
  const MemberReportXpStatus({
    required this.headline,
    required this.detail,
    required this.colorKind,
  });

  final String headline;
  final String detail;
  final MemberIntegrityColorKind colorKind;
}

MemberReportXpStatus memberReportXpStatus(
  PhotoEvaluationResult result, {
  String? adminReviewStatus,
}) {
  if (MemberReviewStatus.isAdminRejected(adminReviewStatus) ||
      MemberReviewStatus.isAdminConfirmedAi(adminReviewStatus)) {
    return const MemberReportXpStatus(
      headline: 'Not awarded',
      detail: 'XP was not granted for this submission after administrator review.',
      colorKind: MemberIntegrityColorKind.red,
    );
  }
  if (MemberReviewStatus.isReuploadRequested(adminReviewStatus)) {
    return const MemberReportXpStatus(
      headline: 'Not awarded',
      detail: 'Upload a replacement file to continue. XP is not applied until review succeeds.',
      colorKind: MemberIntegrityColorKind.accent,
    );
  }
  final awarded = result.memberXpAwardedPoints;
  if (awarded != null && awarded > 0) {
    return MemberReportXpStatus(
      headline: '$awarded XP awarded',
      detail: 'Rewards were released after verification and scoring.',
      colorKind: MemberIntegrityColorKind.green,
    );
  }
  if (awarded == 0 && result.memberScoresReleasedEffective && !result.xpPendingEffective) {
    return const MemberReportXpStatus(
      headline: 'Not awarded',
      detail: 'Scores may be visible, but XP was not granted for this submission.',
      colorKind: MemberIntegrityColorKind.neutral,
    );
  }
  if (result.xpPendingEffective || result.scoresHeldForReview) {
    return const MemberReportXpStatus(
      headline: 'Pending',
      detail: 'XP is not released until verification and scoring rules are satisfied.',
      colorKind: MemberIntegrityColorKind.yellow,
    );
  }
  if (result.xpEligibleEffective == false) {
    return const MemberReportXpStatus(
      headline: 'Not awarded',
      detail: 'This submission is not eligible for XP under the current integrity outcome.',
      colorKind: MemberIntegrityColorKind.neutral,
    );
  }
  return const MemberReportXpStatus(
    headline: 'Pending',
    detail: 'XP status will update when scoring and verification complete.',
    colorKind: MemberIntegrityColorKind.yellow,
  );
}

Color memberIntegrityColorKindToColor(MemberIntegrityColorKind kind) => switch (kind) {
      MemberIntegrityColorKind.green => kGreen,
      MemberIntegrityColorKind.yellow => kYellow,
      MemberIntegrityColorKind.red => kRed,
      MemberIntegrityColorKind.accent => kAccent,
      MemberIntegrityColorKind.neutral => kTextSecondary,
    };

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
