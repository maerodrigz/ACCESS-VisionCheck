import 'package:access_mobile/mobile_app/widgets/additional_quality_insights_panel.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/services/practice_evaluation_result_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdditionalQualityInsights', () {
    test('fromJson parses supplementary fields', () {
      final insights = AdditionalQualityInsights.fromJson({
        'color_balance': {
          'status': 'warm_cast',
          'headline': 'Warm cast',
          'feedback': 'Noticeable warm color cast detected.',
        },
        'composition_framing': {
          'status': 'acceptable',
          'headline': 'Acceptable',
          'feedback': 'No strong edge-clipping signal was detected.',
        },
        'media_type': 'photo',
        'frames_analyzed': 1,
      });
      expect(insights.hasDisplayableData, isTrue);
      expect(insights.colorBalance?.status, 'warm_cast');
    });

    test('PhotoEvaluationResult without field stays compatible', () {
      final result = PhotoEvaluationResult.fromJson({
        'criteria': [
          {'name': 'Sharpness', 'score': 4, 'explanation': '', 'suggestion': ''},
        ],
        'overall_score': 4.0,
        'quality_level': 'Good',
        'ai_feedback': '',
        'improvement_suggestions': '',
        'recommendation': 'Accepted',
        'ai_detection': {'verdict': 'authentic', 'confidence': 0.9, 'detail': ''},
      });
      expect(result, isNotNull);
      expect(result!.hasAdditionalQualityInsights, isFalse);
      expect(result.additionalQualityInsights, isNull);
    });

    test('practice parser preserves additional_quality_insights', () {
      final criteria = {
        'criteria': [
          {'name': 'Sharpness', 'score': 4, 'explanation': '', 'suggestion': ''},
        ],
        'overall_score': 4.0,
        'quality_level': 'Good',
        'ai_feedback': '',
        'improvement_suggestions': '',
        'recommendation': 'Accepted',
        'ai_detection': {'verdict': 'authentic', 'confidence': 0.9, 'detail': ''},
        'additional_quality_insights': {
          'color_balance': {
            'status': 'neutral',
            'headline': 'Balanced',
            'feedback': 'Color channels look reasonably balanced.',
          },
          'composition_framing': {
            'status': 'inconclusive',
            'headline': 'Inconclusive',
            'feedback': 'No clear salient region was detected.',
          },
        },
      };
      final parsed = photoEvaluationResultFromApiRow({'criteria_json': criteria});
      expect(parsed?.hasAdditionalQualityInsights, isTrue);
    });

    test('fromJson parses video motion stability insight', () {
      final insights = AdditionalQualityInsights.fromJson({
        'motion_stability': {
          'status': 'stable_smooth',
          'headline': 'Stable / Smooth Motion',
          'feedback': 'Camera motion looks relatively steady.',
        },
        'media_type': 'video',
      });
      expect(insights.motionStability?.headline, 'Stable / Smooth Motion');
      expect(insights.hasDisplayableData, isTrue);
    });

    testWidgets('panel collapsed by default uses camera movement insights label when expanded',
        (tester) async {
      final insights = AdditionalQualityInsights.fromJson({
        'motion_stability': {
          'status': 'possible_shake',
          'headline': 'Possible Camera Shake',
          'feedback': 'Try bracing your phone or using a tripod.',
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdditionalQualityInsightsPanel(insights: insights),
          ),
        ),
      );
      expect(find.text('Motion Stability'), findsNothing);
      expect(find.text('Camera Movement Insights'), findsNothing);
      expect(find.text('Possible Camera Shake'), findsNothing);
      expect(find.textContaining('1 coaching hint'), findsOneWidget);
      expect(find.textContaining('Coaching only'), findsOneWidget);

      await tester.tap(find.text('Additional Quality Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Camera Movement Insights'), findsOneWidget);
      expect(find.text('Possible Camera Shake'), findsOneWidget);
      expect(find.text('Motion Stability'), findsNothing);
    });

    test('older evaluations without motion_stability stay compatible', () {
      final insights = AdditionalQualityInsights.fromJson({
        'color_balance': {
          'status': 'neutral',
          'headline': 'Balanced',
          'feedback': 'ok',
        },
      });
      expect(insights.motionStability, isNull);
      expect(insights.hasDisplayableData, isTrue);
    });

    test('quality insights not shown when member scores held for review', () {
      const ai = AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.99,
        probability: 0.006,
        riskLevel: 'low',
        requiresReviewFlag: true,
        isFinal: true,
        detail: 'partial provenance',
      );
      final result = PhotoEvaluationResult(
        criteria: const [],
        overallScore: 3.5,
        qualityLevel: 'Fair',
        feedback: '',
        improvementSuggestions: '',
        recommendation: 'Fair',
        aiDetection: ai,
        memberScoresReleased: false,
        additionalQualityInsights: AdditionalQualityInsights.fromJson({
          'motion_stability': {
            'status': 'stable_smooth',
            'headline': 'Stable / Smooth Motion',
            'feedback': 'steady',
          },
        }),
      );
      expect(result.hasAdditionalQualityInsights, isTrue);
      expect(result.showQualityFeedbackEffective, isFalse);
    });

    testWidgets('panel renders labeled section without scores when expanded', (tester) async {
      final insights = AdditionalQualityInsights.fromJson({
        'color_balance': {
          'status': 'warm_cast',
          'headline': 'Warm cast',
          'feedback': 'Consider adjusting white balance if natural colors are intended.',
        },
        'composition_framing': {
          'status': 'edge_proximity',
          'headline': 'Check framing',
          'feedback': 'The main visual area appears close to the frame edge.',
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdditionalQualityInsightsPanel(insights: insights),
          ),
        ),
      );

      expect(find.text('Additional Quality Insights'), findsOneWidget);
      expect(find.text('Color Balance'), findsNothing);

      await tester.tap(find.text('Additional Quality Insights'));
      await tester.pumpAndSettle();

      expect(find.text('Color Balance'), findsOneWidget);
      expect(find.text('Composition / Framing'), findsOneWidget);
      expect(find.textContaining('Warm color tint'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('/5'), findsNothing);
    });

    testWidgets('detail panel shows full API feedback', (tester) async {
      const longFeedback =
          'Irregular motion patterns appeared across consecutive-frame samples. '
          'Try a slower pan, brace your phone, or use a tripod.';
      final insights = AdditionalQualityInsights.fromJson({
        'motion_stability': {
          'status': 'possible_shake',
          'headline': 'Possible Camera Shake',
          'feedback': longFeedback,
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdditionalQualityInsightsDetailPanel(insights: insights),
          ),
        ),
      );
      expect(find.text('Camera Movement Insights'), findsOneWidget);
      expect(find.text(longFeedback), findsOneWidget);
    });
  });
}
