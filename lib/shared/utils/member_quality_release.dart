import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Final overall quality (Fair, Good, score /100) is shown only after the
/// existing verification workflow marks the submission Verified.
///
/// Pending Verification, Under Review, and Rejected stay status-only.
/// Automated low-AI clearance that the workflow already calls Verified still
/// shows the rating. Scores stored on the server are not changed.
bool memberFinalQualityVisible({
  String? reviewStatus,
  AiDetectionResult? automated,
  bool analysisInProgress = false,
}) {
  if (analysisInProgress) return false;
  if (MemberReviewStatus.isAdminRejected(reviewStatus) ||
      MemberReviewStatus.isAdminConfirmedAi(reviewStatus) ||
      MemberReviewStatus.isReviewPending(reviewStatus) ||
      MemberReviewStatus.isReuploadRequested(reviewStatus)) {
    return false;
  }
  if (automated != null) {
    return memberSubmissionWorkflowStatusLabel(
          automated: automated,
          adminReviewStatus: reviewStatus,
        ) ==
        'Verified';
  }
  return MemberReviewStatus.isAdminVerified(reviewStatus) ||
      MemberReviewStatus.isAutomatedLowAiRisk(reviewStatus);
}
