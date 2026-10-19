import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' hide AiDetectionResult;
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';

AiDetectionResult _fallbackAiDetection(String? reviewStatus) {
  final status = reviewStatus?.trim().toLowerCase();
  if (status == 'pending_review' || status == 'needs_further_review') {
    return const AiDetectionResult(
      verdict: 'suspicious',
      confidence: 0.5,
      detail: 'Awaiting administrative review before scores are released.',
      requiresReviewFlag: true,
    );
  }
  if (MemberReviewStatus.isAdminConfirmedAi(status)) {
    return const AiDetectionResult(
      verdict: 'ai_generated',
      confidence: 0.9,
      detail: 'Confirmed by an administrator.',
    );
  }
  return const AiDetectionResult(
    verdict: 'authentic',
    confidence: 0.85,
    detail: 'No AI-generation artifacts detected.',
  );
}

/// Builds a [PhotoEvaluationResult] from a saved [Evaluation] row.
PhotoEvaluationResult? evaluationToPhotoResult(Evaluation ev) {
  if (ev.parsedEvaluation != null) {
    return applyAdminReviewToPhotoResult(ev.parsedEvaluation!, ev.reviewStatus);
  }
  if (!ev.hasAiCriteria && ev.score <= 0) return null;
  final fallback = PhotoEvaluationResult(
    criteria: ev.criteria,
    overallScore: ev.score <= 1.0 ? ev.score * 5 : ev.score,
    qualityLevel: ev.qualityLevel ?? 'Fair',
    feedback: ev.feedback,
    improvementSuggestions: '',
    recommendation: ev.recommendation ?? 'Needs Improvement',
    aiDetection: _fallbackAiDetection(ev.reviewStatus),
    mediaType: ev.mediaType ?? 'photo',
    scoringModel: ev.scoringModel ?? 'efficientnet_b0',
    geminiFeedback: ev.geminiFeedback,
  );
  return applyAdminReviewToPhotoResult(fallback, ev.reviewStatus);
}

/// Integrity explanation for a saved evaluation row (PROBE / review status only).
String memberIntegrityReviewReasonFromEvaluation(Evaluation evaluation) {
  final parsed = evaluation.parsedEvaluation ?? evaluationToPhotoResult(evaluation);
  if (parsed != null) {
    final fromPayload = memberIntegrityReviewReason(parsed);
    if (fromPayload.isNotEmpty) return fromPayload;
  }
  final feedback = evaluation.feedback.trim();
  if (feedback.isNotEmpty) return feedback;
  return '';
}

List<PhotoEvaluationResult> comparisonResultsFromHistory(
  List<Evaluation> all, {
  String? excludeId,
  int limit = 8,
}) {
  final out = <PhotoEvaluationResult>[];
  for (final ev in all) {
    if (excludeId != null && ev.id == excludeId) continue;
    final parsed = evaluationToPhotoResult(ev);
    if (parsed != null) out.add(parsed);
    if (out.length >= limit) break;
  }
  return out;
}
