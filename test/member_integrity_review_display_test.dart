import 'package:access_mobile/mobile_app/utils/evaluation_report_utils.dart';
import 'package:access_mobile/mobile_app/widgets/ai_detection_banner.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_integrity_panels.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' as app_state;
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/camera_provenance_member_evidence.dart';
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

  group('memberAutomatedAiRiskTierLabel', () {
    test('low AI risk with partial provenance stays Low AI Risk', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.0056,
        riskLevel: 'low',
        visualRiskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: 'partial provenance',
        detectorBackend: 'waverep_g4',
        waverepFramesAnalyzed: 20,
        waverepRequestedFrames: 20,
      );
      expect(memberAutomatedAiRiskTierLabel(ai), 'Low AI Risk');
      expect(memberAutomatedIntegrityTierLabel(ai), 'Low AI Risk');
      expect(formatMemberAiProbabilityPercent(ai), '0.6%');
      expect(memberFacingAiScoreLine(ai), 'AI Score: 0.6%');
      expect(memberFacingAiScoreLine(ai), isNot(contains('20/20')));
    });

    test('list label under review when low AI but admin review pending', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.0056,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: 'partial',
      );
      expect(
        memberEvaluationListIntegrityLabel(
          automated: ai,
          adminReviewStatus: 'needs_further_review',
        ),
        'Under review',
      );
      expect(memberAutomatedAiRiskTierLabel(ai), 'Low AI Risk');
    });

    test('strong provenance low risk no overall review banner', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        probability: 0.02,
        riskLevel: 'low',
        requiresReviewFlag: false,
        provenancePolicyOutcome: 'low_ai_risk',
        cameraProvenanceStrength: 'strong',
        isFinal: true,
        detail: 'ok',
      );
      expect(memberShowOverallMediaUnderReview(automated: ai), isFalse);
      expect(memberShowCameraProvenancePanel(automated: ai), isFalse);
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
      expect(model.secondaryAutomatedLine, contains('43.0%'));
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

  group('EvaluationIntegrityPanels widget', () {
    testWidgets('low AI + partial provenance splits panels', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.0056,
        riskLevel: 'low',
        visualRiskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: 'device metadata incomplete',
        detectorBackend: 'waverep_g4',
        waverepFramesAnalyzed: 20,
        waverepRequestedFrames: 20,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(
              aiDetection: ai,
              adminReviewStatus: 'needs_further_review',
            ),
          ),
        ),
      );
      expect(find.text('Media under review'), findsOneWidget);
      expect(find.text('Low AI Risk'), findsOneWidget);
      expect(find.text('Camera Verification Pending'), findsOneWidget);
      expect(find.text('AI Score: 0.6%'), findsOneWidget);
      expect(find.textContaining('20/20'), findsNothing);
      expect(find.textContaining('WaveRep'), findsNothing);
      expect(find.textContaining('camera information is incomplete'), findsOneWidget);
      expect(find.text('Consistent with Camera-Captured Media'), findsNothing);
    });

    testWidgets('video low AI + partial provenance uses pending provenance copy', (tester) async {
      final ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.0056,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: '',
        exifMetadata: {
          'is_video': true,
          'format': 'video_container',
          'fields': [
            {'key': 'creation_time', 'value': '2026-06-29T10:14:54.000000Z'},
            {'key': 'com.android.version', 'value': '11'},
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(
              aiDetection: ai,
              adminReviewStatus: 'needs_further_review',
            ),
          ),
        ),
      );
      expect(find.text('Low AI Risk'), findsOneWidget);
      expect(find.textContaining('camera information is incomplete'), findsOneWidget);
      expect(
        find.textContaining('recording device could not be fully identified'),
        findsOneWidget,
      );
      expect(find.textContaining('does not necessarily mean the video is AI-generated'), findsOneWidget);
      expect(find.text('Available evidence'), findsOneWidget);
      expect(find.textContaining('Recording timestamp:'), findsOneWidget);
      expect(find.textContaining('Android version: 11'), findsOneWidget);
      expect(find.text('Camera identity unavailable'), findsOneWidget);
      expect(find.text('Consistent with Camera-Captured Media'), findsNothing);
    });

    testWidgets('AI analysis unavailable shows dedicated tier', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'suspicious',
        confidence: 0,
        detail: 'WaveRep unavailable',
        waverepAnalysisUnavailable: true,
        requiresReviewFlag: true,
        isFinal: true,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(aiDetection: ai),
          ),
        ),
      );
      expect(find.text('Analysis Unavailable'), findsOneWidget);
      expect(find.textContaining('cannot be assessed using the available AI result'), findsOneWidget);
      expect(find.textContaining('AI Score:'), findsNothing);
    });

    testWidgets('photo and video low AI strong provenance show positive assessment', (tester) async {
      for (var i = 0; i < 2; i++) {
        final ai = AiDetectionResult(
          verdict: 'authentic',
          confidence: 0.94,
          probability: 0.056,
          riskLevel: 'low',
          requiresReviewFlag: false,
          provenancePolicyOutcome: 'low_ai_risk',
          cameraProvenanceStrength: 'strong',
          isFinal: true,
          detail: '',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EvaluationIntegrityPanels(aiDetection: ai),
            ),
          ),
        );
        expect(find.text('Consistent with Camera-Captured Media'), findsOneWidget);
        expect(find.text('AI Score: 5.6%'), findsOneWidget);
        expect(find.textContaining('supports its reported origin'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('high AI risk shows score line without backend detail noise', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'ai_generated',
        confidence: 0.72,
        probability: 0.72,
        riskLevel: 'high',
        requiresReviewFlag: true,
        isFinal: true,
        detail: 'High AI authenticity risk from WaveRep G4 (72% AI score).',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(aiDetection: ai),
          ),
        ),
      );
      expect(find.text('High AI Risk'), findsOneWidget);
      expect(find.textContaining('elevated AI-generation indicators'), findsOneWidget);
      expect(find.text('AI Score: 72.0%'), findsOneWidget);
      expect(find.textContaining('WaveRep'), findsNothing);
      expect(find.text('Consistent with Camera-Captured Media'), findsNothing);
    });

    testWidgets('suspicious AI risk shows needs review tier and score', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(aiDetection: suspiciousProbe()),
          ),
        ),
      );
      expect(find.text('Needs Review'), findsOneWidget);
      expect(find.textContaining('patterns that require further verification'), findsOneWidget);
      expect(find.text('AI Score: 43.0%'), findsOneWidget);
      expect(find.text('Consistent with Camera-Captured Media'), findsNothing);
    });

    test('memberAiAuthenticityPanelModel five scenario copy', () {
      const strongLow = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.94,
        probability: 0.056,
        riskLevel: 'low',
        requiresReviewFlag: false,
        provenancePolicyOutcome: 'low_ai_risk',
        cameraProvenanceStrength: 'strong',
        isFinal: true,
        detail: '',
      );
      final positive = memberAiAuthenticityPanelModel(automated: strongLow);
      expect(positive.tierLabel, 'Consistent with Camera-Captured Media');
      expect(positive.statsLine, 'AI Score: 5.6%');

      const pendingProv = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.006,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: '',
      );
      final pending = memberAiAuthenticityPanelModel(
        automated: pendingProv,
        adminReviewStatus: 'needs_further_review',
      );
      expect(pending.tierLabel, 'Low AI Risk');
      expect(pending.detail, contains('camera information is incomplete'));
      expect(pending.tierLabel, isNot('Consistent with Camera-Captured Media'));

      final suspicious = memberAiAuthenticityPanelModel(automated: suspiciousProbe());
      expect(suspicious.tierLabel, 'Needs Review');

      final high = memberAiAuthenticityPanelModel(automated: highProbe());
      expect(high.tierLabel, 'High AI Risk');

      const unavailable = AiDetectionResult(
        verdict: 'suspicious',
        confidence: 0,
        detail: 'x',
        waverepAnalysisUnavailable: true,
        isFinal: true,
      );
      final unavail = memberAiAuthenticityPanelModel(automated: unavailable);
      expect(unavail.tierLabel, 'Analysis Unavailable');
      expect(unavail.statsLine, isNull);
    });

    test('media 251 stored ai_detection shape parses frame counts', () {
      final ai = AiDetectionResult.fromJsonMap({
        'verdict': 'authentic',
        'probability': 0.006,
        'risk_level': 'low',
        'requires_review': true,
        'detector_backend': 'waverep_g4',
        'waverep_frames_analyzed': 20,
        'waverep_processing_status': 'complete',
        'camera_provenance_strength': 'partial',
        'provenance_policy_outcome': 'source_partially_verified',
        'detail': 'Low AI authenticity risk from WaveRep G4 (0% AI score, 20/20 frames).',
        'waverep_supplementary': {
          'waverep_requested_frames': 20,
          'waverep_processed_frames': 20,
        },
      });
      expect(ai, isNotNull);
      expect(ai!.waverepFramesAnalyzed, 20);
      expect(ai.waverepRequestedFrames, 20);
      expect(formatMemberAiProbabilityPercent(ai), '0.6%');
      expect(memberFacingAiScoreLine(ai), 'AI Score: 0.6%');
      expect(ai.waverepFramesAnalyzed, 20);
    });

    test('hide integrity-only card when overall panels cover review hold', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.006,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
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
      expect(
        memberShouldHideIntegrityOnlyReviewCard(
          result: result,
          adminReviewStatus: 'needs_further_review',
        ),
        isTrue,
      );
      final detail = memberOverallReviewPanelDetail(result: result);
      expect(detail, contains('42 XP'));
    });

    testWidgets('photo evaluation shows AI Score label format', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        probability: 0.08,
        riskLevel: 'low',
        isFinal: true,
        detail: 'photo probe low',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(aiDetection: ai),
          ),
        ),
      );
      expect(find.text('AI Score: 8.0%'), findsOneWidget);
    });

    testWidgets('photo low risk without waverep frames', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.9,
        probability: 0.08,
        riskLevel: 'low',
        isFinal: true,
        detail: 'photo probe low',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(aiDetection: ai),
          ),
        ),
      );
      expect(find.text('Low AI Risk'), findsOneWidget);
      expect(find.text('AI Score: 8.0%'), findsOneWidget);
      expect(find.textContaining('Frames analyzed'), findsNothing);
    });

    testWidgets('partial photo provenance keeps photo copy and optional EXIF evidence', (tester) async {
      final ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.006,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: '',
        exifMetadata: {
          'has_exif': true,
          'fields': [
            {'key': 'Make', 'value': 'INFINIX MOBILITY LIMITED'},
            {'key': 'Model', 'value': 'Infinix X695'},
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(
              aiDetection: ai,
              adminReviewStatus: 'needs_further_review',
            ),
          ),
        ),
      );
      expect(find.textContaining('Original camera device information in this file is incomplete'), findsOneWidget);
      expect(find.textContaining('recording device could not be fully identified'), findsNothing);
      expect(find.textContaining('Camera manufacturer: INFINIX MOBILITY LIMITED'), findsOneWidget);
      expect(find.textContaining('Camera model: Infinix X695'), findsOneWidget);
      expect(find.text('Camera identity unavailable'), findsNothing);
    });

    testWidgets('absent provenance uses no reliable tier label', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        probability: 0.04,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_unverified',
        cameraProvenanceStrength: 'absent',
        isFinal: true,
        detail: '',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(
              aiDetection: ai,
              adminReviewStatus: 'needs_further_review',
            ),
          ),
        ),
      );
      expect(find.text('No reliable camera provenance'), findsOneWidget);
      expect(find.text('Camera identity unavailable'), findsOneWidget);
    });

    testWidgets('verified human shows administrator provenance completion panel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(
              aiDetection: suspiciousProbe(),
              adminReviewStatus: 'verified_human',
            ),
          ),
        ),
      );
      expect(find.text('Administrator verification completed'), findsOneWidget);
      expect(find.text('Camera Verification Pending'), findsNothing);
    });

    test('fromJsonMap parses video exif metadata for evidence', () {
      final ai = AiDetectionResult.fromJsonMap({
        'verdict': 'authentic',
        'probability': 0.006,
        'risk_level': 'low',
        'requires_review': true,
        'camera_provenance_strength': 'partial',
        'provenance_policy_outcome': 'source_partially_verified',
        'exif_metadata': {
          'is_video': true,
          'fields': [
            {'key': 'creation_time', 'value': '2026-06-29T10:14:54.000000Z'},
            {'key': 'com.android.version', 'value': '11'},
          ],
        },
      });
      expect(ai, isNotNull);
      expect(memberAiDetectionIsVideoContainerProvenance(ai!), isTrue);
      final lines = memberCameraProvenanceEvidenceLines(ai);
      expect(lines.any((l) => l.startsWith('Recording timestamp:')), isTrue);
      expect(lines, contains('Android version: 11'));
      expect(lines, contains('Camera identity unavailable'));
    });

    testWidgets('pending review shows single overall media under review section', (tester) async {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.006,
        riskLevel: 'low',
        requiresReviewFlag: true,
        provenancePolicyOutcome: 'source_partially_verified',
        cameraProvenanceStrength: 'partial',
        isFinal: true,
        detail: 'x',
      );
      final result = PhotoEvaluationResult(
        criteria: const [],
        overallScore: 3.5,
        qualityLevel: 'Fair',
        feedback: '',
        improvementSuggestions: '',
        recommendation: 'Fair',
        aiDetection: ai,
        xpPending: true,
        showQualityFeedback: false,
        memberScoresReleased: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvaluationIntegrityPanels(
              aiDetection: ai,
              evaluationResult: result,
              adminReviewStatus: 'needs_further_review',
            ),
          ),
        ),
      );
      expect(find.text('Media under review'), findsOneWidget);
      expect(find.text('Integrity review required'), findsNothing);
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
      expect(find.textContaining('43.0%'), findsOneWidget);
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
