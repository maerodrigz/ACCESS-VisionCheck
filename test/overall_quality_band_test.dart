import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/rule_based_quality_feedback.dart';
import 'package:access_mobile/shared/utils/overall_quality_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overall quality labels match the 0-100 legend', () {
    const expected = {
      59: 'Poor',
      60: 'Fair',
      74: 'Fair',
      75: 'Good',
      80: 'Good',
      89: 'Good',
      90: 'Excellent',
      100: 'Excellent',
    };
    for (final entry in expected.entries) {
      expect(overallQualityLabelFromPercent(entry.key), entry.value);
    }
  });

  test('a stored Fair label still displays Good Quality at 80/100', () {
    const result = PhotoEvaluationResult(
      criteria: [
        CriterionScore(name: 'Sharpness', score: 4, explanation: 'Crisp.', suggestion: ''),
        CriterionScore(name: 'Blur', score: 4, explanation: 'Steady.', suggestion: ''),
        CriterionScore(name: 'Brightness', score: 4, explanation: 'Even.', suggestion: ''),
        CriterionScore(name: 'Contrast', score: 4, explanation: 'Clear.', suggestion: ''),
      ],
      overallScore: 4,
      qualityLevel: 'Fair',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Accepted',
      aiDetection: AiDetectionResult(verdict: 'authentic', confidence: 0.9, detail: ''),
      mediaType: 'photo',
      scoringModel: 'musiq',
      strengths: [],
      weaknesses: [],
    );
    expect(result.overallPercent, 80);
    expect(result.displayQualityLabel, 'Good');
    expect(overallQualityHeadline(result.displayQualityLabel), 'Good Quality');

    final feedback = MediaEvaluationFeedback.fromLocal(result);
    expect(feedback.explanation.toLowerCase(), contains('good'));
    expect(feedback.explanation.toLowerCase(), isNot(contains('fair')));
  });

  test('stored overall sentence is corrected without changing criterion wording', () {
    const feedback = MediaEvaluationFeedback(
      explanation: 'Overall quality looks fair. Brightness is fair in the highlights.',
      strengths: ['Sharpness is good.'],
      improvements: ['Contrast is fair and can be stronger.'],
      tips: ['Keep the subject steady.'],
      closingMessage: 'Your measured quality looks strong overall (Fair).',
    );
    final aligned = feedback.withAlignedOverallLabel('Good');
    expect(aligned.explanation, 'Overall quality looks good. Brightness is fair in the highlights.');
    expect(aligned.improvements.single, 'Contrast is fair and can be stronger.');
    expect(aligned.closingMessage, 'Your measured quality looks strong overall (Good).');
  });

  test('video feedback uses the same overall label as the score', () {
    final feedback = RuleBasedQualityFeedback.build(
      criteria: const [
        RuleBasedQualityInput(name: 'Sharpness', score: 4),
        RuleBasedQualityInput(name: 'Blur', score: 4),
        RuleBasedQualityInput(name: 'Brightness', score: 4),
        RuleBasedQualityInput(name: 'Motion Stability', score: 4),
      ],
      isVideo: true,
      overallScore: 4,
      qualityLevel: 'Fair',
    );
    expect(feedback.explanation.toLowerCase(), contains('good'));
    expect(feedback.explanation.toLowerCase(), isNot(contains('fair')));
  });
}
