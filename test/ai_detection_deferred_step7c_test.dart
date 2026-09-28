import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deferred ai_detection parses without fake authentic verdict', () {
    final ai = AiDetectionResult.fromJsonMap({
      'analysis_status': 'deferred',
      'is_final': false,
      'requires_review': false,
      'detail': 'AI authenticity risk will be assessed when you save this submission.',
    });
    expect(ai, isNotNull);
    expect(ai!.isDeferredAuthenticity, isTrue);
    expect(ai.isAuthentic, isFalse);
    expect(ai.isAiGenerated, isFalse);
    expect(ai.isSuspicious, isFalse);
    expect(ai.requiresReview, isFalse);
  });

  test('legacy authentic payload unchanged', () {
    final ai = AiDetectionResult.fromJsonMap({
      'verdict': 'authentic',
      'confidence': 0.82,
      'probability': 0.12,
      'detail': 'ok',
    });
    expect(ai!.isAuthentic, isTrue);
    expect(ai.isDeferredAuthenticity, isFalse);
  });

  test('PhotoEvaluationResult fromJson with deferred ai_detection', () {
    final parsed = PhotoEvaluationResult.fromJson({
      'criteria': [
        {'name': 'Sharpness', 'score': 4, 'explanation': 'e', 'suggestion': 's'},
      ],
      'overall_score': 4.0,
      'ai_detection': {
        'analysis_status': 'deferred',
        'is_final': false,
        'detail': 'pending',
      },
      'xp_pending': true,
      'xp_eligible': false,
    });
    expect(parsed, isNotNull);
    expect(parsed!.aiDetection.isDeferredAuthenticity, isTrue);
    expect(parsed.xpEligibleEffective, isFalse);
  });
}
