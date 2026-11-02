import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter_test/flutter_test.dart';

PhotoEvaluationResult _result(AiDetectionResult ai, {bool showQuality = true}) {
  return PhotoEvaluationResult(
    criteria: const [],
    overallScore: 4.0,
    qualityLevel: 'Good',
    feedback: '',
    improvementSuggestions: '',
    recommendation: 'Good',
    aiDetection: ai,
    showQualityFeedback: showQuality,
    memberScoresReleased: showQuality,
    xpPending: !showQuality,
  );
}

void main() {
  group('memberEvaluationResultMediaCheck', () {
    test('reupload required', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        detail: '',
        isFinal: true,
      );
      final check = memberEvaluationResultMediaCheck(
        automated: ai,
        adminReviewStatus: 'reupload_requested',
      );
      expect(check.statusLabel, 'Reupload Required');
    });

    test('under review when requiresReviewFlag', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.02,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: 'review',
      );
      final check = memberEvaluationResultMediaCheck(
        automated: ai,
        evaluationResult: _result(ai, showQuality: false),
      );
      expect(check.statusLabel, 'Under Review');
    });

    test('no major concerns when auto-cleared', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.01,
        riskLevel: 'low',
        visualRiskLevel: 'low',
        requiresReviewFlag: false,
        isFinal: true,
        detail: '',
      );
      final check = memberEvaluationResultMediaCheck(
        automated: ai,
        adminReviewStatus: 'automated_low_ai_risk',
        evaluationResult: _result(ai),
      );
      expect(check.statusLabel, 'No Major Concerns');
    });

    test('needs attention when admin rejected', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        detail: '',
        isFinal: true,
      );
      final check = memberEvaluationResultMediaCheck(
        automated: ai,
        adminReviewStatus: 'rejected',
      );
      expect(check.statusLabel, 'Needs Attention');
    });

    test('needs attention when flagged as ai generated', () {
      const ai = AiDetectionResult(
        verdict: 'ai_generated',
        confidence: 0.95,
        detail: 'flagged',
        isFinal: true,
      );
      final check = memberEvaluationResultMediaCheck(
        automated: ai,
        evaluationResult: _result(ai, showQuality: false),
      );
      expect(check.statusLabel, 'Needs Attention');
    });
  });
}
