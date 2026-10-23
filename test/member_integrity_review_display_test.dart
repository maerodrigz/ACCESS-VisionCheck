import 'package:access_mobile/mobile_app/utils/evaluation_report_utils.dart';
import 'package:access_mobile/mobile_app/widgets/ai_detection_banner.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' as app_state;
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AiDetectionResult suspiciousProbe({double probability = 0.43}) {
  return AiDetectionResult(
    verdict: 'suspicious',
    confidence: probability,
    probability: probability,
    riskLevel: 'suspicious',
    requiresReviewFlag: true,
    isFinal: true,
    detail: 'Elevated AI authenticity risk. Review recommended',
  );
}

AiDetectionResult highProbe({double probability = 0.72}) {
  return AiDetectionResult(
    verdict: 'ai_generated',
    confidence: probability,
    probability: probability,
    riskLevel: 'high',
    requiresReviewFlag: true,
    isFinal: true,
    detail: 'High AI authenticity risk.',
  );
}

PhotoEvaluationResult baseResult(AiDetectionResult ai) {
  return PhotoEvaluationResult(
    criteria: const [
      CriterionScore(name: 'Sharpness', score: 3, explanation: '', suggestion: ''),
    ],
    overallScore: 3.5,
    qualityLevel: 'Fair',
    feedback: '',
    improvementSuggestions: '',
    recommendation: 'Needs Improvement',
    aiDetection: ai,
    qualityProvisional: true,
    xpPending: true,
  );
}

void main() {
  group('MemberReviewStatus', () {
    test('automated_low_ai_risk is not a final admin decision', () {
      expect(MemberReviewStatus.isFinalAdminDecision('automated_low_ai_risk'), isFalse);
    });

    test('verified_human is final admin human', () {
      expect(MemberReviewStatus.isFinalAdminDecision('verified_human'), isTrue);
      expect(MemberReviewStatus.isAdminConfirmedHuman('verified_human'), isTrue);
    });
  });

  group('memberIntegrityBannerModel', () {
    test('suspicious 0.43 pending review shows elevated / review recommended', () {
      final model = memberIntegrityBannerModel(
        automated: suspiciousProbe(),
        adminReviewStatus: 'needs_further_review',
      );
      expect(model.heading, 'Elevated AI authenticity risk');
      expect(model.subtitle, 'Review recommended');
      expect(model.showPendingReviewFooter, isTrue);
      expect(model.secondaryAutomatedLine, isNull);
    });

    test('suspicious 0.43 admin human: primary admin copy, secondary PROBE preserved', () {
      final ai = suspiciousProbe(probability: 0.43);
      final model = memberIntegrityBannerModel(
        automated: ai,
        adminReviewStatus: 'verified_human',
      );
      expect(model.heading, 'Human-Captured');
      expect(model.subtitle, 'Confirmed by Admin');
      expect(model.showPendingReviewFooter, isFalse);
      expect(model.secondaryAutomatedLine, contains('43%'));
      expect(model.secondaryAutomatedLine, contains('elevated'));
      expect(ai.probability, 0.43);
    });

    test('high risk admin human takes precedence over automated high', () {
      final model = memberIntegrityBannerModel(
        automated: highProbe(),
        adminReviewStatus: 'verified_human',
      );
      expect(model.heading, 'Human-Captured');
      expect(model.subtitle, 'Confirmed by Admin');
      expect(model.showPendingReviewFooter, isFalse);
    });

    test('admin confirmed AI shows completed review, not pending wording', () {
      final model = memberIntegrityBannerModel(
        automated: suspiciousProbe(),
        adminReviewStatus: 'confirmed_ai_generated',
      );
      expect(model.heading, 'AI-Generated / Manipulated');
      expect(model.subtitle, 'Confirmed by Admin Review');
      expect(model.showPendingReviewFooter, isFalse);
    });

    test('low automated without admin review unchanged', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        probability: 0.04,
        riskLevel: 'low',
        isFinal: true,
        detail: 'Low risk.',
      );
      final model = memberIntegrityBannerModel(automated: ai);
      expect(model.heading, 'Low AI authenticity risk');
      expect(model.showPendingReviewFooter, isFalse);
    });
  });

  group('applyAdminReviewToPhotoResult', () {
    test('verified human clears provisional and xp pending without changing PROBE', () {
      final ai = suspiciousProbe();
      final before = baseResult(ai);
      final after = applyAdminReviewToPhotoResult(before, 'verified_human');
      expect(after.aiDetection.probability, 0.43);
      expect(after.qualityProvisionalEffective, isFalse);
      expect(after.xpPendingEffective, isFalse);
      expect(after.xpEligibleEffective, isTrue);
    });
  });

  group('evaluationToPhotoResult refresh', () {
    test('reopen after admin decision uses review_status for integrity flags', () {
      final ai = suspiciousProbe();
      final ev = app_state.Evaluation(
        id: '1',
        title: 'Practice',
        score: 0.7,
        composition: '',
        lighting: '',
        feedback: '',
        date: '2026-01-01',
        criteria: ai.verdict.isEmpty ? const [] : const [],
        parsedEvaluation: baseResult(ai),
        reviewStatus: 'verified_human',
      );
      final parsed = evaluationToPhotoResult(ev);
      expect(parsed, isNotNull);
      expect(parsed!.aiDetection.probability, 0.43);
      expect(parsed.qualityProvisionalEffective, isFalse);
      expect(ev.hasAdminReviewDecision, isTrue);
    });
  });

  group('AiDetectionBanner widget', () {
    testWidgets('admin human shows low tier and detail, not pending review copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiDetectionBanner(
              aiDetection: suspiciousProbe(),
              adminReviewStatus: 'verified_human',
            ),
          ),
        ),
      );
      expect(find.text('AI Authenticity Assessment'), findsOneWidget);
      expect(find.text('Low AI Risk'), findsOneWidget);
      expect(find.textContaining('human-captured'), findsOneWidget);
      expect(find.text('Review recommended'), findsNothing);
      expect(find.textContaining('Officers may review'), findsNothing);
      expect(find.textContaining('43%'), findsOneWidget);
    });

    testWidgets('pending suspicious shows needs review tier and elevated detail', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiDetectionBanner(
              aiDetection: suspiciousProbe(),
              adminReviewStatus: 'needs_further_review',
            ),
          ),
        ),
      );
      expect(find.text('AI Authenticity Assessment'), findsOneWidget);
      expect(find.text('Needs Review'), findsOneWidget);
      expect(find.textContaining('Elevated AI authenticity risk'), findsOneWidget);
      expect(find.textContaining('Officers may review'), findsOneWidget);
    });
  });
}
