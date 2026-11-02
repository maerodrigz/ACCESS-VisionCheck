import 'package:access_mobile/mobile_app/widgets/evaluation_report_integrity_compact.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PhotoEvaluationResult _base({
  AiDetectionResult? ai,
  bool xpPending = false,
  int xpPreview = 0,
  bool scoresHeld = false,
  bool showQuality = true,
}) {
  return PhotoEvaluationResult(
    criteria: const [],
    overallScore: 3.5,
    qualityLevel: 'Fair',
    feedback: '',
    improvementSuggestions: '',
    recommendation: 'Fair',
    aiDetection: ai ??
        const AiDetectionResult(
          verdict: 'authentic',
          confidence: 0.9,
          detail: '',
          isFinal: true,
        ),
    xpPending: xpPending,
    xpPointsPreview: xpPreview,
    showQualityFeedback: showQuality,
    memberScoresReleased: !scoresHeld,
  );
}

void main() {
  group('memberEvaluationReportReviewDecision', () {
    test('confirmed AI uses admin decision copy only', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(
          ai: const AiDetectionResult(
            verdict: 'ai_generated',
            confidence: 0.99,
            probability: 0.95,
            isFinal: true,
            detail: 'high probe',
          ),
          xpPending: true,
        ),
        adminReviewStatus: 'confirmed_ai_generated',
        adminRemarks: 'Please use an original recording.',
      );
      expect(decision.statusTitle, 'Submission Rejected');
      expect(decision.reason, contains('administrator confirmed'));
      expect(decision.reason, isNot(contains('95')));
      expect(decision.xpOutcomeLine, 'XP not awarded for this submission.');
      expect(decision.administratorRemarks, 'Please use an original recording.');
    });

    test('generic rejected without remarks uses neutral reason', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(xpPending: true, showQuality: false),
        adminReviewStatus: 'rejected',
      );
      expect(decision.statusTitle, 'Submission Rejected');
      expect(decision.reason, contains('did not approve'));
      expect(decision.xpOutcomeLine, 'XP not awarded for this submission.');
    });

    test('rejected with admin remarks uses remarks as reason once', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(),
        adminReviewStatus: 'rejected',
        adminRemarks: 'Video does not show the required skill.',
      );
      expect(decision.reason, 'Video does not show the required skill.');
      expect(decision.administratorRemarks, isNull);
    });

    test('pending review never shows submission rejected', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(
          ai: const AiDetectionResult(
            verdict: 'authentic',
            confidence: 0.99,
            probability: 0.006,
            requiresReviewFlag: true,
            provenancePolicyOutcome: 'source_partially_verified',
            isFinal: true,
            detail: 'review',
          ),
          xpPending: true,
          xpPreview: 42,
          scoresHeld: true,
          showQuality: false,
        ),
        adminReviewStatus: 'needs_further_review',
      );
      expect(decision.statusTitle, 'Pending Administrator Review');
      expect(decision.reason, isNot(contains('Rejected')));
      expect(decision.xpOutcomeLine, contains('pending'));
      expect(decision.xpOutcomeLine, contains('42'));
    });

    test('high AI risk while pending is not treated as confirmed AI', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(
          ai: const AiDetectionResult(
            verdict: 'ai_generated',
            confidence: 0.8,
            probability: 0.88,
            isFinal: true,
            requiresReviewFlag: true,
            detail: 'flagged',
          ),
          xpPending: true,
          scoresHeld: true,
          showQuality: false,
        ),
        adminReviewStatus: 'needs_further_review',
      );
      expect(decision.statusTitle, 'Pending Administrator Review');
      expect(decision.reason, isNot(contains('confirmed this submission as AI-generated')));
      expect(decision.xpOutcomeLine, isNot(contains('not awarded for this submission')));
    });

    test('verified human approved with XP awarded line', () {
      final result = _base(
        ai: const AiDetectionResult(verdict: 'authentic', confidence: 0.9, isFinal: true, detail: ''),
        xpPending: false,
      ).copyWithIntegrity(
        xpEligible: true,
        memberScoresReleased: true,
        xpPointsPreview: 80,
      );
      final decision = memberEvaluationReportReviewDecision(
        result: result,
        adminReviewStatus: 'verified_human',
      );
      expect(decision.statusTitle, 'Approved');
      expect(decision.xpOutcomeLine, contains('80 XP awarded'));
    });

    test('reupload requested', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(xpPending: true, showQuality: false),
        adminReviewStatus: 'reupload_requested',
        adminRemarks: 'Upload a clearer clip.',
      );
      expect(decision.statusTitle, 'Re-upload Required');
      expect(decision.reason, 'Upload a clearer clip.');
      expect(decision.xpOutcomeLine, contains('not awarded until'));
    });

    test('automated low ai risk cleared', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(),
        adminReviewStatus: 'automated_low_ai_risk',
      );
      expect(decision.statusTitle, 'Approved');
      expect(decision.reason, contains('Automated screening cleared'));
    });

    test('accepted with warning', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(),
        adminReviewStatus: 'accepted_with_warning',
      );
      expect(decision.statusTitle, 'Approved with Warning');
    });

    test('deferred processing', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(
          ai: const AiDetectionResult(
            verdict: 'deferred',
            confidence: 0,
            analysisStatus: 'deferred',
            isFinal: false,
            detail: '',
          ),
        ),
        adminReviewStatus: 'pending_review',
      );
      expect(decision.statusTitle, 'Processing');
    });

    test('conflicting final reject with pending xp flags still shows not awarded', () {
      final decision = memberEvaluationReportReviewDecision(
        result: _base(xpPending: true, xpPreview: 100, showQuality: false),
        adminReviewStatus: 'confirmed_ai_generated',
      );
      expect(decision.statusTitle, 'Submission Rejected');
      expect(decision.xpOutcomeLine, 'XP not awarded for this submission.');
      expect(decision.xpOutcomeLine, isNot(contains('100')));
    });
  });

  group('EvaluationReportIntegrityCompact widget', () {
    testWidgets('shows single review decision card without Media Check', (tester) async {
      final result = _base(
        ai: const AiDetectionResult(
          verdict: 'authentic',
          confidence: 0.99,
          requiresReviewFlag: true,
          isFinal: true,
          detail: '',
        ),
        xpPending: true,
        xpPreview: 30,
        scoresHeld: true,
        showQuality: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationReportIntegrityCompact(
              result: result,
              adminReviewStatus: 'needs_further_review',
              adminRemarks: 'Officer note',
            ),
          ),
        ),
      );

      expect(find.text('Review decision'), findsOneWidget);
      expect(find.text('Pending Administrator Review'), findsOneWidget);
      expect(find.text('Media Check'), findsNothing);
      expect(find.text('Media under review'), findsNothing);
      expect(find.text('Skill progress (XP)'), findsNothing);
      expect(find.text('Officer note'), findsOneWidget);
      expect(find.textContaining('XP pending'), findsOneWidget);
    });

    testWidgets('confirmed AI shows fixed rejection copy once', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationReportIntegrityCompact(
              result: _base(
                ai: const AiDetectionResult(
                  verdict: 'ai_generated',
                  confidence: 0.99,
                  isFinal: true,
                  detail: '',
                ),
                xpPending: true,
                showQuality: false,
              ),
              adminReviewStatus: 'confirmed_ai_generated',
            ),
          ),
        ),
      );

      expect(find.text('Submission Rejected'), findsOneWidget);
      expect(
        find.text('The administrator confirmed this submission as AI-generated.'),
        findsOneWidget,
      );
      expect(find.text('Needs Attention'), findsNothing);
    });
  });
}
