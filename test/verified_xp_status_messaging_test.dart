import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter_test/flutter_test.dart';

PhotoEvaluationResult _result({
  bool? xpAwardedAtReview,
  int? xpAwardedPoints,
  double? xpMultiplier,
  bool? xpPending,
  bool? xpEligible,
  bool? memberScoresReleased,
  int? xpPointsPreview,
}) {
  return PhotoEvaluationResult(
    criteria: const [
      CriterionScore(name: 'Sharpness', score: 4, explanation: '', suggestion: ''),
    ],
    overallScore: 4.0,
    qualityLevel: 'Good',
    feedback: '',
    improvementSuggestions: '',
    recommendation: 'Good',
    aiDetection: const AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.9,
      detail: 'Verified',
    ),
    xpAwardedAtReview: xpAwardedAtReview,
    xpAwardedPoints: xpAwardedPoints,
    xpMultiplier: xpMultiplier,
    xpPending: xpPending,
    xpEligible: xpEligible,
    memberScoresReleased: memberScoresReleased,
    xpPointsPreview: xpPointsPreview,
  );
}

void main() {
  test('verified with award stamp but multiplier 0 shows already awarded', () {
    final result = _result(
      xpAwardedAtReview: true,
      xpMultiplier: 0.0,
      xpPending: false,
      xpEligible: false,
      memberScoresReleased: true,
      xpPointsPreview: 80,
    );
    expect(result.xpAlreadyAwardedEffective, isTrue);
    expect(result.memberXpAwardedPoints, 80);
    expect(
      memberReportReviewDecisionXpLine(result, adminReviewStatus: 'verified_human'),
      '80 XP already awarded for this submission.',
    );
  });

  test('explicit xp_awarded_points wins over preview', () {
    final result = _result(
      xpAwardedAtReview: true,
      xpAwardedPoints: 55,
      xpMultiplier: 0.0,
      xpPending: false,
      memberScoresReleased: true,
      xpPointsPreview: 80,
    );
    expect(result.memberXpAwardedPoints, 55);
    expect(
      memberReportReviewDecisionXpLine(result, adminReviewStatus: 'verified_human'),
      '55 XP already awarded for this submission.',
    );
  });

  test('pending review shows XP pending', () {
    final result = _result(
      xpPending: true,
      xpEligible: false,
      xpMultiplier: 0.0,
      memberScoresReleased: false,
      xpPointsPreview: 40,
    );
    expect(
      memberReportReviewDecisionXpLine(result, adminReviewStatus: 'needs_further_review'),
      contains('XP pending'),
    );
  });

  test('released ineligible without award stamp stays not awarded', () {
    final result = _result(
      xpAwardedAtReview: false,
      xpMultiplier: 0.0,
      xpPending: false,
      xpEligible: false,
      memberScoresReleased: true,
      xpPointsPreview: 80,
    );
    expect(result.memberXpAwardedPoints, 0);
    expect(
      memberReportReviewDecisionXpLine(result, adminReviewStatus: 'verified_human'),
      'XP not awarded for this submission.',
    );
  });

  test('PhotoEvaluationResult.fromJson reads award stamps', () {
    final result = PhotoEvaluationResult.fromJson({
      'criteria': [
        {'name': 'Sharpness', 'score': 4, 'explanation': '', 'suggestion': '', 'available': true},
      ],
      'overall_score': 4.0,
      'quality_level': 'Good',
      'ai_feedback': '',
      'improvement_suggestions': '',
      'recommendation': 'Good',
      'ai_detection': {
        'verdict': 'authentic',
        'confidence': 0.9,
        'detail': 'ok',
      },
      'xp_awarded_at_review': true,
      'xp_awarded_points': 72,
      'xp_multiplier': 0.0,
      'xp_pending': false,
      'xp_eligible': true,
      'member_scores_released': true,
      'xp_points_preview': 72,
    });
    expect(result, isNotNull);
    expect(result!.xpAwardedAtReview, isTrue);
    expect(result.xpAwardedPoints, 72);
    expect(result.memberXpAwardedPoints, 72);
  });
}
