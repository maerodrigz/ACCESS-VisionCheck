import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' show Evaluation;
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _evaluationWithResult(
  PhotoEvaluationResult parsed, {
  String? reviewStatus,
  String title = 'Practice upload',
  String date = 'Jun 1, 2026',
  String? imageUrl,
}) {
  return Evaluation(
    id: 'local-test-1',
    title: title,
    score: parsed.overallScore / 5,
    composition: '',
    lighting: '',
    feedback: parsed.feedback,
    date: date,
    qualityLevel: parsed.qualityLevel,
    mediaType: parsed.mediaType,
    recommendation: parsed.recommendation,
    parsedEvaluation: parsed,
    reviewStatus: reviewStatus,
    imageUrl: imageUrl,
  );
}

PhotoEvaluationResult _sampleParsed({String mediaType = 'photo'}) {
  return PhotoEvaluationResult(
    criteria: const [],
    overallScore: 3.5,
    qualityLevel: 'Fair',
    feedback: '',
    improvementSuggestions: '',
    recommendation: 'Fair',
    aiDetection: const AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.99,
      probability: 0.006,
      riskLevel: 'low',
      requiresReviewFlag: true,
      provenancePolicyOutcome: 'source_partially_verified',
      cameraProvenanceStrength: 'partial',
      isFinal: true,
      detail: 'review',
    ),
    mediaType: mediaType,
    showQualityFeedback: false,
    memberScoresReleased: false,
    xpPending: true,
  );
}

void main() {
  testWidgets('saved report uses Review decision and hides legacy integrity panels', (tester) async {
    final parsed = _sampleParsed();

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: _evaluationWithResult(parsed, reviewStatus: 'needs_further_review'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Evaluation Report'), findsOneWidget);
    expect(find.text('Pending Verification'), findsWidgets);
    expect(find.text('Admin Review'), findsOneWidget);
    expect(find.text('Integrity status'), findsOneWidget);
    expect(find.text('AI Risk'), findsOneWidget);
    expect(find.text('Source Provenance'), findsOneWidget);
    expect(find.text('Partially Verified'), findsOneWidget);
    expect(find.text('Review decision'), findsNothing);
    expect(find.text('Media Check'), findsNothing);
    expect(find.text('Media under review'), findsNothing);
    expect(find.text('AI Authenticity Assessment'), findsNothing);
    expect(find.text('Camera Metadata / Provenance'), findsNothing);
    expect(find.text('Additional Quality Insights'), findsNothing);
    expect(find.textContaining('AI Score'), findsNothing);
  });

  testWidgets('Phase 1 header shows photo title, date, and Verified status', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: _evaluationWithResult(
            _sampleParsed(mediaType: 'photo'),
            reviewStatus: 'verified_human',
            title: 'Sunset plaza shot',
            date: 'Nov 9, 13:57',
            imageUrl: 'http://127.0.0.1:3001/api/media/55/stream',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Evaluation Report'), findsOneWidget);
    expect(find.text('Sunset plaza shot'), findsOneWidget);
    expect(find.text('Nov 9, 13:57'), findsOneWidget);
    expect(find.text('Photo'), findsWidgets);
    expect(find.text('Verified'), findsWidgets);
    expect(find.text('View Original'), findsOneWidget);
    // Glass header: media fills the card; no separate solid "Media quality" info block.
    expect(find.text('Media quality'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 1 header shows video play affordance', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: _evaluationWithResult(
            _sampleParsed(mediaType: 'video'),
            reviewStatus: 'pending_review',
            title: 'Practice walkthrough',
            date: 'Nov 8, 10:12',
            imageUrl: 'http://127.0.0.1:3001/api/media/56/stream.mp4',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Practice walkthrough'), findsOneWidget);
    expect(find.text('Video'), findsWidgets);
    expect(find.text('Pending Verification'), findsWidgets);
    expect(find.text('Play Video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 2 shows score and admin review summary with XP once',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final parsed = PhotoEvaluationResult(
      criteria: const [],
      overallScore: 4.2,
      qualityLevel: 'Good',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Good',
      aiDetection: const AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        probability: 0.04,
        riskLevel: 'low',
        isFinal: true,
        detail: 'ok',
      ),
      mediaType: 'photo',
      showQualityFeedback: true,
      memberScoresReleased: true,
      xpPending: false,
      xpEligible: true,
      xpMultiplier: 1.0,
      xpPointsPreview: 80,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: Evaluation(
            id: 'MED-200',
            title: 'Plaza still',
            score: 0.84,
            composition: '',
            lighting: '',
            feedback: '',
            date: 'Nov 9, 13:57',
            qualityLevel: 'Good',
            mediaType: 'photo',
            parsedEvaluation: parsed,
            reviewStatus: 'verified_human',
            imageUrl: 'http://127.0.0.1:3001/api/media/200/stream',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Overall Quality Score'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
    expect(find.text('Good'), findsWidgets);
    expect(find.text('Admin Review'), findsOneWidget);
    expect(find.text('Verified'), findsWidgets);
    expect(find.textContaining('80 XP awarded'), findsOneWidget);
    expect(find.text('Review decision'), findsNothing);
    expect(find.text('Approved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 2 pending shows N/A score and Pending Verification',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: _evaluationWithResult(
            _sampleParsed(),
            reviewStatus: 'needs_further_review',
            title: 'Held upload',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Overall Quality Score'), findsOneWidget);
    expect(find.text('Score pending review'), findsOneWidget);
    expect(find.text('Admin Review'), findsOneWidget);
    expect(find.text('Pending Verification'), findsWidgets);
    expect(find.textContaining('XP pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 2 rejected shows Rejected and XP not awarded', (tester) async {
    final parsed = PhotoEvaluationResult(
      criteria: const [],
      overallScore: 2.0,
      qualityLevel: 'Poor',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Poor',
      aiDetection: const AiDetectionResult(
        verdict: 'ai_generated',
        confidence: 0.99,
        isFinal: true,
        detail: '',
      ),
      mediaType: 'photo',
      showQualityFeedback: true,
      memberScoresReleased: true,
      xpPending: false,
      xpEligible: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvaluationReportScreen(
          evaluation: Evaluation(
            id: 'MED-201',
            title: 'Rejected shot',
            score: 0.4,
            composition: '',
            lighting: '',
            feedback: '',
            date: 'Nov 1, 09:00',
            qualityLevel: 'Poor',
            mediaType: 'photo',
            parsedEvaluation: parsed,
            reviewStatus: 'confirmed_ai_generated',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Rejected'), findsWidgets);
    expect(find.text('XP not awarded for this submission.'), findsOneWidget);
    expect(find.text('Review decision'), findsNothing);
    expect(find.text('Admin Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report shows one score summary, one admin review, and quality breakdown',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final criteria = [
      const CriterionScore(
        name: 'Sharpness',
        score: 4,
        explanation: 'ok',
        suggestion: '',
      ),
      const CriterionScore(
        name: 'Brightness',
        score: 5,
        explanation: 'ok',
        suggestion: '',
      ),
    ];
    final photoParsed = PhotoEvaluationResult(
      criteria: criteria,
      overallScore: 4.2,
      qualityLevel: 'Good',
      feedback: 'Solid capture',
      improvementSuggestions: 'Hold steadier',
      recommendation: 'Good',
      aiDetection: const AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        probability: 0.04,
        riskLevel: 'low',
        isFinal: true,
        detail: 'ok',
      ),
      mediaType: 'photo',
      showQualityFeedback: true,
      memberScoresReleased: true,
      xpPending: false,
      xpEligible: true,
      xpMultiplier: 1.0,
      xpPointsPreview: 80,
    );
    final videoParsed = PhotoEvaluationResult(
      criteria: [
        ...criteria,
        const CriterionScore(
          name: 'Motion Stability',
          score: 5,
          explanation: 'ok',
          suggestion: '',
        ),
      ],
      overallScore: 4.2,
      qualityLevel: 'Good',
      feedback: 'Solid capture',
      improvementSuggestions: 'Hold steadier',
      recommendation: 'Good',
      aiDetection: const AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        probability: 0.04,
        riskLevel: 'low',
        isFinal: true,
        detail: 'ok',
      ),
      mediaType: 'video',
      showQualityFeedback: true,
      memberScoresReleased: true,
      xpPending: false,
      xpEligible: true,
      xpMultiplier: 1.0,
      xpPointsPreview: 80,
    );

    Future<void> pumpReport(PhotoEvaluationResult parsed) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EvaluationReportScreen(
            evaluation: Evaluation(
              id: 'MED-dup-${parsed.mediaType}',
              title: 'Dedup check',
              score: 0.84,
              composition: '',
              lighting: '',
              feedback: '',
              date: 'Nov 9, 13:57',
              qualityLevel: 'Good',
              mediaType: parsed.mediaType,
              parsedEvaluation: parsed,
              reviewStatus: 'verified_human',
              adminRemarks: 'Looks genuine. Keep lighting consistent.',
              imageUrl: parsed.isVideo
                  ? 'http://127.0.0.1:3001/api/media/56/stream.mp4'
                  : 'http://127.0.0.1:3001/api/media/55/stream',
            ),
          ),
        ),
      );
      await tester.pump();
      // Criterion bar intro timers (stagger) must finish before the next pumpWidget.
      await tester.pump(const Duration(milliseconds: 400));
    }

    await pumpReport(photoParsed);
    expect(find.text('Overall Quality Score'), findsOneWidget);
    expect(find.text('Admin Review'), findsOneWidget);
    expect(find.text('Review decision'), findsNothing);
    expect(find.text('Media quality'), findsNothing);
    expect(find.text('Quality Breakdown'), findsOneWidget);
    expect(find.text('Sharpness'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
    expect(find.text('Administrator remarks'), findsOneWidget);
    expect(find.textContaining('80 XP awarded'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsOneWidget);

    await pumpReport(videoParsed);
    expect(find.text('Overall Quality Score'), findsOneWidget);
    expect(find.text('Admin Review'), findsOneWidget);
    expect(find.text('Review decision'), findsNothing);
    expect(find.text('Quality Breakdown'), findsOneWidget);
    expect(find.text('Motion Stability'), findsOneWidget);
    expect(find.text('Administrator remarks'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
