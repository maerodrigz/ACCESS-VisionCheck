import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';

/// Mirrors backend `practice_evaluation_eligible_for_skill`.
bool evaluationEligibleForSkillProgress(Evaluation ev) {
  if (ev.isAnalysisInProgress || ev.storageRemoved) return false;
  if (MemberReviewStatus.isReviewPending(ev.reviewStatus)) return false;
  if (MemberReviewStatus.isAdminConfirmedAi(ev.reviewStatus)) return false;
  if (MemberReviewStatus.isAdminRejected(ev.reviewStatus)) return false;
  if (MemberReviewStatus.isReuploadRequested(ev.reviewStatus)) return false;
  if (ev.isPending || ev.displayScore <= 0) return false;
  final verdict = ev.parsedEvaluation?.aiDetection.verdict.toLowerCase() ?? '';
  if (verdict == 'ai_generated' || verdict == 'ai') return false;
  return true;
}

List<Evaluation> skillEligibleEvaluations(Iterable<Evaluation> source) =>
    source.where(evaluationEligibleForSkillProgress).toList();

bool isVideoPracticeEvaluation(Evaluation ev) {
  final mt = (ev.mediaType ?? ev.parsedEvaluation?.mediaType ?? 'photo').toLowerCase();
  return mt == 'video';
}
