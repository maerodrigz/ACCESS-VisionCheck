import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/rule_based_quality_feedback.dart';

void main() {
  Map<String, dynamic> criterion(String name, int? score) => {
        'name': name,
        'score': score,
        'available': score != null,
        'explanation': '',
        'suggestion': '',
      };

  test('Flutter displays backend overall and keeps seven diagnostic cards', () {
    // Backend v2: Clarity=mean(2,2)=2, plus five 5s → (2+25)/6 = 4.5
    final result = PhotoEvaluationResult.fromJson({
      'criteria': [
        criterion('Sharpness', 2),
        criterion('Blur', 2),
        criterion('Brightness', 5),
        criterion('Contrast', 5),
        criterion('Blocking Artifacts', 5),
        criterion('Color Balance', 5),
        criterion('Color Saturation', 5),
      ],
      'overall_score': 4.5,
      'quality_level': 'Excellent',
      'recommendation': 'Accepted',
      'scoring_formula_version': 'v2',
      'analysis': {
        'scoring_formula_version': 'v2',
        'scoring_formula': 'clarity_unified_v2',
        'clarity_score': 2.0,
      },
      'legacy': {'overall_score': 0.9},
      'xp_points_preview': 90,
    });

    expect(result, isNotNull);
    expect(result!.criteria.length, 7);
    expect(result.criteria.map((c) => c.name).take(2).toList(), ['Sharpness', 'Blur']);
    // Must NOT recompute a seven-criterion mean (would be ~4.14).
    expect(result.overallScore, 4.5);
    expect(result.qualityLevel, 'Excellent');
    expect(result.scoringFormulaVersion, 'v2');
    expect(result.scoringFormulaVersionEffective, 'v2');
    expect(result.xpPointsPreviewEffective, 90);
    expect(result.overallPercent, 90);
  });

  test('historical payload without version defaults to v1 and keeps stored overall', () {
    final result = PhotoEvaluationResult.fromJson({
      'criteria': [
        criterion('Sharpness', 2),
        criterion('Blur', 2),
        criterion('Brightness', 5),
        criterion('Contrast', 5),
        criterion('Blocking Artifacts', 5),
        criterion('Color Balance', 5),
        criterion('Color Saturation', 5),
      ],
      'overall_score': 4.14,
      'quality_level': 'Good',
      'recommendation': 'Accepted',
    });
    expect(result, isNotNull);
    expect(result!.scoringFormulaVersion, isNull);
    expect(result.scoringFormulaVersionEffective, 'v1');
    expect(result.overallScore, 4.14);
  });

  test('rule-based feedback still combines Clarity without numeric measurements', () {
    final feedback = RuleBasedQualityFeedback.build(
      criteria: const [
        RuleBasedQualityInput(name: 'Sharpness', score: 1, available: true),
        RuleBasedQualityInput(name: 'Blur', score: 2, available: true),
        RuleBasedQualityInput(name: 'Brightness', score: 5, available: true),
        RuleBasedQualityInput(name: 'Contrast', score: 5, available: true),
        RuleBasedQualityInput(name: 'Blocking Artifacts', score: 5, available: true),
        RuleBasedQualityInput(name: 'Color Balance', score: 5, available: true),
        RuleBasedQualityInput(name: 'Color Saturation', score: 5, available: true),
      ],
      isVideo: false,
      overallScore: 4.5,
      qualityLevel: 'Excellent',
    );
    expect(feedback.improvements.any((i) => i.startsWith('Clarity:')), isTrue);
    final blob = [
      feedback.explanation,
      ...feedback.strengths,
      ...feedback.improvements,
      ...feedback.tips,
    ].join(' ');
    expect(RuleBasedQualityFeedback.narrativeContainsMeasurements(blob), isFalse);
  });
}
