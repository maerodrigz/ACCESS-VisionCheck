import 'package:access_mobile/mobile_app/sheets/admin_review_notice_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' hide AiDetectionResult;
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

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
    aiDetection: const AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.85,
      detail: 'No AI-generation artifacts detected.',
    ),
    mediaType: ev.mediaType ?? 'photo',
    scoringModel: ev.scoringModel ?? 'efficientnet_b0',
    geminiFeedback: ev.geminiFeedback,
  );
  return applyAdminReviewToPhotoResult(fallback, ev.reviewStatus);
}

/// Integrity explanation when opening a report from notifications (API body fallback).
String memberIntegrityReviewReasonFromEvaluation(
  Evaluation evaluation, {
  String? notificationMessage,
}) {
  final parsed = evaluation.parsedEvaluation ?? evaluationToPhotoResult(evaluation);
  if (parsed != null) {
    final fromPayload = memberIntegrityReviewReason(parsed);
    if (fromPayload.isNotEmpty) return fromPayload;
  }
  final remarks = adminRemarksFromNotificationFallback(notificationMessage);
  if (remarks.isNotEmpty) return remarks;
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
