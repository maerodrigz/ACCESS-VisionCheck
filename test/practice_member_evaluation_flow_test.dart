import 'package:access_mobile/mobile_app/widgets/ai_detection_banner.dart';
import 'package:access_mobile/mobile_app/widgets/eval_result_action_bar.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/practice_evaluation_save_outcome.dart';
import 'package:access_mobile/shared/services/deferred_media_evaluation_poll.dart';
import 'package:access_mobile/shared/services/practice_evaluation_result_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('practice evaluation result parser', () {
    test('parses final criteria_json without deferred authenticity', () {
      const criteria = '''
      {
        "criteria": [{"name": "Sharpness", "score": 4, "explanation": "ok", "suggestion": ""}],
        "overall_score": 4.2,
        "quality_level": "Good",
        "ai_detection": {
          "verdict": "authentic",
          "confidence": 0.92,
          "probability": 0.04,
          "risk_level": "low",
          "requires_review": false,
          "is_final": true,
          "detail": "Low AI authenticity risk from PROBE."
        },
        "quality_provisional": false,
        "xp_eligible": true
      }
      ''';
      final row = {'criteria_json': criteria};
      final result = photoEvaluationResultFromApiRow(row);
      expect(result, isNotNull);
      expect(result!.aiDetection.isDeferredAuthenticity, isFalse);
      expect(result.aiDetection.isLowProbeRisk, isTrue);
      expect(result.qualityProvisionalEffective, isFalse);
    });

    test('rejects deferred preview payload', () {
      const criteria = '''
      {
        "criteria": [],
        "overall_score": 4,
        "ai_detection": {"analysis_status": "deferred", "is_final": false, "detail": "pending"}
      }
      ''';
      expect(photoEvaluationResultFromApiRow({'criteria_json': criteria}), isNull);
    });

    test('final suspicious copy inputs', () {
      const criteria = '''
      {
        "criteria": [{"name": "Sharpness", "score": 3, "explanation": "", "suggestion": ""}],
        "overall_score": 3.5,
        "ai_detection": {
          "verdict": "suspicious",
          "confidence": 0.4,
          "probability": 0.38,
          "risk_level": "suspicious",
          "requires_review": true,
          "is_final": true,
          "detail": "Elevated risk."
        },
        "quality_provisional": true,
        "xp_pending": true
      }
      ''';
      final result = photoEvaluationResultFromApiRow({'criteria_json': criteria});
      expect(result!.aiDetection.isSuspicious, isTrue);
      expect(result.qualityProvisionalEffective, isTrue);
    });
  });

  group('practice flow widgets', () {
    testWidgets('EvalResultActionBar shows Done for practice result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvalResultActionBar(
              onDone: () {},
              onEvaluateAgain: () {},
            ),
          ),
        ),
      );
      expect(find.text('Back to Practice'), findsOneWidget);
    });

    testWidgets('practice final banner avoids pending-save copy', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        detail: 'server detail',
        probability: 0.02,
        riskLevel: 'low',
        isFinal: true,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiDetectionBanner(aiDetection: ai, practiceFinalCopy: true),
          ),
        ),
      );
      expect(find.textContaining('pending save', findRichText: true), findsNothing);
      expect(find.text('Low AI Risk'), findsOneWidget);
      expect(find.textContaining('Authenticity check pending save'), findsNothing);
    });
  });

  group('single upload poll contract', () {
    test('poll completes without second upload call', () async {
      var fetches = 0;
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: const Duration(seconds: 2),
        fetchMediaById: (_) async {
          fetches += 1;
          if (fetches < 2) {
            return {'id': 99, 'processing_status': 'processing'};
          }
          return {'id': 99, 'processing_status': 'completed', 'overall_score': 0.8};
        },
      );
      final outcome = await poll.waitForCompletion(mediaId: 99, isVideo: false);
      expect(outcome, DeferredPollOutcome.completed);
      expect(fetches, 2);
    });

    test('timeout does not imply re-upload', () async {
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: Duration.zero,
        fetchMediaById: (_) async => {'id': 1, 'processing_status': 'processing'},
      );
      final outcome = await poll.waitForCompletion(mediaId: 1, isVideo: false);
      expect(outcome, DeferredPollOutcome.stillProcessing);
      expect(
        const PracticeEvaluationSaveOutcome(phase: PracticeEvaluationSavePhase.stillProcessingOnServer).uploadSucceeded,
        isTrue,
      );
    });
  });
}
