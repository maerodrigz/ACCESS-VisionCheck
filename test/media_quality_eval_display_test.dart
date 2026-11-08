import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/services/practice_evaluation_result_parser.dart';

void main() {
  test('member Noise score is higher-is-better 1-5', () {
    final result = PhotoEvaluationResult.fromJson({
      'criteria': [
        {'name': 'Sharpness', 'score': 4, 'explanation': '', 'suggestion': ''},
        {'name': 'Blur', 'score': 4, 'explanation': '', 'suggestion': ''},
        {'name': 'Noise', 'score': 4, 'explanation': '', 'suggestion': ''},
      ],
      'overall_score': 4.0,
      'quality_level': 'Good',
      'legacy': {
        'sharpness_score': 0.8,
        'blur_score': 0.8,
        'noise_score': 0.2,
        'overall_score': 0.8,
      },
    });
    expect(result, isNotNull);
    final noise = result!.criteria.firstWhere((c) => c.name == 'Noise');
    expect(noise.score, 4);
    expect(noise.percentScore, 80);
    expect(result.overallPercent, 80);
  });

  test('failed evaluation is unavailable, not a 0.5 or Fair default', () {
    final result = photoEvaluationResultFromApiRow({
      'criteria_json': {
        'evaluation_status': 'failed',
        'evaluation_available': false,
        'criteria': [],
        'overall_score': null,
        'ai_feedback': 'Quality evaluation could not be completed.',
      },
    });
    expect(result, isNotNull);
    expect(result!.evaluationAvailable, isFalse);
    expect(result.criteria, isEmpty);
    expect(result.qualityLevel, 'Unavailable');
  });

  test('admin and member share the same criterion names and direction', () {
    const names = [
      'Sharpness',
      'Blur',
      'Noise',
      'Brightness',
      'Contrast',
      'Blocking Artifacts',
      'Ringing Artifacts',
    ];
    expect(PhotoEvaluationResult.photoCriteriaOrder, names);
  });
}
