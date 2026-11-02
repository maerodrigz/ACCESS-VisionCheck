import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' show Evaluation;
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _evaluationWithResult(PhotoEvaluationResult parsed, {String? reviewStatus}) {
  return Evaluation(
    id: 'local-test-1',
    title: 'Practice upload',
    score: parsed.overallScore / 5,
    composition: '',
    lighting: '',
    feedback: parsed.feedback,
    date: 'Jun 1, 2026',
    qualityLevel: parsed.qualityLevel,
    mediaType: parsed.mediaType,
    recommendation: parsed.recommendation,
    parsedEvaluation: parsed,
    reviewStatus: reviewStatus,
  );
}

void main() {
  testWidgets('saved report uses Review decision and hides legacy integrity panels', (tester) async {
    const ai = AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.99,
      probability: 0.006,
      riskLevel: 'low',
      requiresReviewFlag: true,
      provenancePolicyOutcome: 'source_partially_verified',
      cameraProvenanceStrength: 'partial',
      isFinal: true,
      detail: 'review',
    );
    final parsed = PhotoEvaluationResult(
      criteria: const [],
      overallScore: 3.5,
      qualityLevel: 'Fair',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Fair',
      aiDetection: ai,
      showQualityFeedback: false,
      memberScoresReleased: false,
      xpPending: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: _evaluationWithResult(parsed, reviewStatus: 'needs_further_review'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Evaluation Report'), findsOneWidget);
    expect(find.text('Review decision'), findsOneWidget);
    expect(find.text('Pending Administrator Review'), findsOneWidget);
    expect(find.text('Media Check'), findsNothing);
    expect(find.text('Media under review'), findsNothing);
    expect(find.text('AI Authenticity Assessment'), findsNothing);
    expect(find.text('Camera Metadata / Provenance'), findsNothing);
    expect(find.text('Additional Quality Insights'), findsNothing);
    expect(find.textContaining('AI Score'), findsNothing);
  });

  test('report review decision pending label differs from live result Media Check', () {
    const ai = AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.99,
      probability: 0.02,
      riskLevel: 'low',
      requiresReviewFlag: true,
      isFinal: true,
      detail: '',
    );
    final parsed = PhotoEvaluationResult(
      criteria: const [],
      overallScore: 4.0,
      qualityLevel: 'Good',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Good',
      aiDetection: ai,
      showQualityFeedback: false,
      memberScoresReleased: false,
    );
    const reviewStatus = 'needs_further_review';
    final reportDecision = memberEvaluationReportReviewDecision(
      result: parsed,
      adminReviewStatus: reviewStatus,
    );
    final check = memberEvaluationResultMediaCheck(
      automated: ai,
      adminReviewStatus: reviewStatus,
      evaluationResult: parsed,
    );
    expect(reportDecision.statusTitle, 'Pending Administrator Review');
    expect(check.statusLabel, 'Under Review');
  });
}
