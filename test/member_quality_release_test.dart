import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_quality_release.dart';
import 'package:flutter_test/flutter_test.dart';

AiDetectionResult _ai({bool requiresReview = false}) {
  return AiDetectionResult(
    verdict: 'authentic',
    confidence: 0.9,
    detail: 'test',
    probability: 0.05,
    riskLevel: 'low',
    requiresReviewFlag: requiresReview,
    isFinal: true,
  );
}

void main() {
  test('Pending Verification hides the final quality rating', () {
    expect(
      memberFinalQualityVisible(
        reviewStatus: 'pending_review',
        automated: _ai(requiresReview: true),
      ),
      isFalse,
    );
  });

  test('Under Review hides the final quality rating', () {
    expect(
      memberFinalQualityVisible(
        reviewStatus: 'needs_further_review',
        automated: _ai(requiresReview: true),
      ),
      isFalse,
    );
  });

  test('Approved media keeps the final quality rating', () {
    expect(
      memberFinalQualityVisible(
        reviewStatus: 'verified_human',
        automated: _ai(),
      ),
      isTrue,
    );
    expect(
      memberFinalQualityVisible(reviewStatus: 'accepted_with_warning'),
      isTrue,
    );
  });

  test('Rejected media hides the final quality rating', () {
    expect(
      memberFinalQualityVisible(
        reviewStatus: 'rejected',
        automated: _ai(),
      ),
      isFalse,
    );
    expect(
      memberFinalQualityVisible(reviewStatus: 'confirmed_ai_generated'),
      isFalse,
    );
  });
}
