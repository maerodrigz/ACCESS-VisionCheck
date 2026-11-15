import 'package:access_mobile/shared/models/quality_skill_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses backend quality skill classification without inventing scores', () {
    final snap = QualitySkillClassificationSnapshot.fromJson({
      'photo': {
        'media_kind': 'photo',
        'title': 'Proficient',
        'average_score': 3.4567,
        'average_score_display': 3.46,
        'qualifying_evaluations': 5,
        'window_size': 10,
        'formula_version': 'v2',
        'next_title': 'Advanced',
        'score_gap': 0.54,
        'evaluations_gap': 3,
        'progress_summary': 'Toward Advanced: need 3 more qualifying evaluations and raise average by 0.54.',
        'classified': true,
      },
      'video': {
        'media_kind': 'video',
        'title': 'Not Yet Classified',
        'average_score': null,
        'average_score_display': null,
        'qualifying_evaluations': 1,
        'classified': false,
        'progress_summary': 'Complete 2 more qualifying evaluations to earn Beginner.',
      },
      'disclaimer': 'Not a certification.',
      'photo_title': 'Proficient',
      'video_title': 'Not Yet Classified',
      'guide': [
        {
          'title': 'Beginner',
          'meaning': 'Learning basic media quality skills.',
          'score_range': '0.00–1.99 / 5',
          'minimum_evaluations': 3,
          'focus': 'Focus',
          'next': {
            'title': 'Developing',
            'minimum_average_score': 2.0,
            'minimum_evaluations': 3,
          },
        },
      ],
    });

    expect(snap.photo.title, 'Proficient');
    expect(snap.photo.averageLabel, '3.46/5');
    expect(snap.video.title, 'Not Yet Classified');
    expect(snap.video.averageLabel, 'N/A');
    expect(snap.forMedia(isVideo: false).nextTitle, 'Advanced');
    expect(snap.guide.single.nextTitle, 'Developing');
    expect(snap.disclaimer, 'Not a certification.');
  });
}
