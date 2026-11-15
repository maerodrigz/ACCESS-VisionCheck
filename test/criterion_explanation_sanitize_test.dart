import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/criterion_explanation_sanitize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips experimental and heuristic disclaimers', () {
    const raw =
        'Significant camera movement was detected. Experimental heuristic; '
        'sparse sampling limits certainty.';
    final cleaned = sanitizeCriterionExplanation(raw);
    expect(cleaned.toLowerCase(), isNot(contains('experimental heuristic')));
    expect(cleaned.toLowerCase(), isNot(contains('sparse sampling limits certainty')));
    expect(cleaned, contains('Significant camera movement'));
  });

  test('CriterionScore.fromJson sanitizes stored explanations', () {
    final c = CriterionScore.fromJson({
      'name': 'Color Balance',
      'score': 3,
      'explanation':
          'Some noticeable color shifts were detected. (Heuristic estimate; not a validated aesthetic score.)',
      'suggestion': 'Correct white balance.',
      'available': true,
    });
    expect(c.explanation.toLowerCase(), isNot(contains('heuristic estimate')));
    expect(c.explanation.toLowerCase(), isNot(contains('validated aesthetic')));
    expect(c.explanation, contains('color shifts'));
  });
}
