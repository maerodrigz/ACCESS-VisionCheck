import 'dart:convert';
import 'dart:typed_data';

import 'package:access_mobile/mobile_app/screens/evaluation_result_screen.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_report_integrity_compact.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PhotoEvaluationResult _baseResult(AiDetectionResult ai) {
  return PhotoEvaluationResult(
    criteria: const [],
    overallScore: 3.5,
    qualityLevel: 'Fair',
    feedback: '',
    improvementSuggestions: '',
    recommendation: 'Fair',
    aiDetection: ai,
    showQualityFeedback: false,
    xpPending: true,
    memberScoresReleased: false,
  );
}

void main() {
  group('memberReportVerificationStatus', () {
    test('processing deferred', () {
      const ai = AiDetectionResult(
        verdict: 'deferred',
        confidence: 0,
        detail: 'Pending',
        analysisStatus: 'deferred',
        isFinal: false,
      );
      final status = memberReportVerificationStatus(automated: ai);
      expect(status.title, 'Processing');
    });

    test('verified as human', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        detail: '',
        isFinal: true,
      );
      final status = memberReportVerificationStatus(
        automated: ai,
        adminReviewStatus: 'verified_human',
      );
      expect(status.title, 'Verified as Human');
    });

    test('rejected admin', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        detail: '',
        isFinal: true,
      );
      final status = memberReportVerificationStatus(
        automated: ai,
        adminReviewStatus: 'rejected',
      );
      expect(status.title, 'Rejected');
    });

    test('re-upload required', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        detail: '',
        isFinal: true,
      );
      final status = memberReportVerificationStatus(
        automated: ai,
        adminReviewStatus: 'reupload_requested',
      );
      expect(status.title, 'Re-upload Required');
    });
  });

  testWidgets('compact report shows unified review decision with XP pending', (tester) async {
    const ai = AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.99,
      probability: 0.006,
      riskLevel: 'low',
      visualRiskLevel: 'low',
      requiresReviewFlag: true,
      provenancePolicyOutcome: 'source_partially_verified',
      primaryReviewDriver: 'provenance_partial_android',
      cameraProvenanceStrength: 'partial',
      isFinal: true,
      detail: 'review',
    );
    final result = PhotoEvaluationResult(
      criteria: const [],
      overallScore: 3.5,
      qualityLevel: 'Fair',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Fair',
      aiDetection: ai,
      qualityProvisional: true,
      xpPending: true,
      xpPointsPreview: 42,
      showQualityFeedback: false,
      memberScoresReleased: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvaluationReportIntegrityCompact(
            result: result,
            adminReviewStatus: 'needs_further_review',
          ),
        ),
      ),
    );

    expect(find.text('Review decision'), findsOneWidget);
    expect(find.text('Pending Administrator Review'), findsOneWidget);
    expect(find.text('Media Check'), findsNothing);
    expect(find.textContaining('42 XP'), findsOneWidget);
    expect(find.text('Integrity Assessment'), findsNothing);
    expect(find.text('Verification Status'), findsNothing);
  });

  testWidgets('compact report shows awarded XP when released', (tester) async {
    const ai = AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.9,
      probability: 0.05,
      riskLevel: 'low',
      isFinal: true,
      detail: 'ok',
    );
    final result = PhotoEvaluationResult(
      criteria: const [],
      overallScore: 4.0,
      qualityLevel: 'Good',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Good',
      aiDetection: ai,
      xpPending: false,
      xpEligible: true,
      xpMultiplier: 1.0,
      xpPointsPreview: 80,
      memberScoresReleased: true,
      showQualityFeedback: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvaluationReportIntegrityCompact(
            result: result,
            adminReviewStatus: 'verified_human',
          ),
        ),
      ),
    );

    expect(find.text('Approved'), findsOneWidget);
    expect(find.textContaining('80 XP awarded'), findsOneWidget);
    expect(find.text('Media Check'), findsNothing);
  });

  testWidgets('evaluation result screen uses compact integrity (no legacy panels)', (tester) async {
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
    final result = _baseResult(ai);

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationResultScreen(
          media: EvaluationResultMedia(
            name: 'practice.jpg',
            bytes: Uint8List.fromList(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
              ),
            ),
            isVideo: false,
          ),
          result: result,
          evaluatedAt: DateTime(2026, 6, 1),
          onEvaluateAgain: () {},
        ),
      ),
    );

    expect(find.text('Media Check'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    expect(find.text('AI Authenticity Assessment'), findsNothing);
    expect(find.text('Camera Metadata / Provenance'), findsNothing);
    expect(find.text('Additional Quality Insights'), findsNothing);
    expect(find.text('AI Score: 2.0%'), findsOneWidget);
  });
}
