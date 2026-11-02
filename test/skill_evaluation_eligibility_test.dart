import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _practice({
  required String id,
  required DateTime at,
  double score = 0.75,
  String? reviewStatus,
  String mediaType = 'photo',
}) {
  return Evaluation(
    id: id,
    title: 'Practice',
    score: score,
    composition: '',
    lighting: '',
    feedback: 'Feedback',
    date: '2026-01-01',
    evaluatedAt: at,
    reviewStatus: reviewStatus,
    mediaType: mediaType,
  );
}

void main() {
  test('pending and rejected evaluations are excluded from skill progress', () {
    final pending = _practice(
      id: 'MED-1',
      at: DateTime(2026, 1, 1),
      reviewStatus: 'pending_review',
      score: 0.9,
    );
    final rejected = _practice(
      id: 'MED-2',
      at: DateTime(2026, 1, 2),
      reviewStatus: 'rejected',
      score: 0.8,
    );
    final released = _practice(
      id: 'MED-3',
      at: DateTime(2026, 1, 3),
      reviewStatus: 'verified_human',
      score: 0.7,
    );

    expect(evaluationEligibleForSkillProgress(pending), isFalse);
    expect(evaluationEligibleForSkillProgress(rejected), isFalse);
    expect(evaluationEligibleForSkillProgress(released), isTrue);

    final eligible = skillEligibleEvaluations([pending, rejected, released]);
    expect(eligible.length, 1);
    expect(eligible.first.id, 'MED-3');
  });

  test('photo and video filters partition eligible history', () {
    final photo = _practice(id: 'MED-10', at: DateTime(2026, 2, 1), mediaType: 'photo');
    final video = _practice(id: 'MED-11', at: DateTime(2026, 2, 2), mediaType: 'video');
    final all = skillEligibleEvaluations([photo, video]);
    expect(all.length, 2);
    expect(all.where(isVideoPracticeEvaluation).length, 1);
    expect(all.where((e) => !isVideoPracticeEvaluation(e)).length, 1);
  });
}
