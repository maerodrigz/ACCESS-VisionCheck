import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/member_supplementary_insights_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera movement display title differs from rubric name', () {
    expect(
      supplementaryInsightDisplayTitle(SupplementaryInsightKind.cameraMovement),
      'Camera Movement Insights',
    );
  });

  test('concise lines prefer status templates over long API feedback', () {
    const insight = SupplementaryQualityInsight(
      status: 'possible_shake',
      headline: 'Possible Camera Shake',
      feedback:
          'Irregular motion patterns appeared across consecutive-frame samples. '
          'Try a slower pan, brace your phone, or use a tripod. Moving subjects can look similar to shake.',
    );
    final line = supplementaryInsightConciseLine(
      insight,
      kind: SupplementaryInsightKind.cameraMovement,
    );
    expect(line, contains('handshake'));
    expect(line.length, lessThan(insight.feedback.length));
  });
}
