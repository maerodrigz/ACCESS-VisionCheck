import 'package:access_mobile/mobile_app/utils/evaluation_report_utils.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' show Evaluation;
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

CriterionScore _c(String name, int? score, {bool available = true}) => CriterionScore(
      name: name,
      score: score ?? 0,
      explanation: '',
      suggestion: '',
      available: available && score != null,
    );

List<CriterionScore> _nineVideoCriteria() => [
      _c('Sharpness', 4),
      _c('Blur', 3),
      _c('Brightness', 5),
      _c('Contrast', 3),
      _c('Blocking Artifacts', 3),
      _c('Color Balance', 5),
      _c('Color Saturation', 5),
      _c('Motion Stability', 4),
      _c('Flickering', 5),
    ];

PhotoEvaluationResult _videoResult({
  required List<CriterionScore> criteria,
  String mediaType = 'photo', // simulate missing/defaulted media_type
  double overall = 4.0,
}) {
  return PhotoEvaluationResult(
    criteria: criteria,
    overallScore: overall,
    qualityLevel: 'Good',
    feedback: 'ok',
    improvementSuggestions: '',
    recommendation: 'Accepted',
    aiDetection: const AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.9,
      detail: '',
    ),
    mediaType: mediaType,
    scoringModel: 'efficientnet-b0',
  );
}

Evaluation _evaluation({
  required PhotoEvaluationResult parsed,
  String? mediaType,
  String? imageUrl,
  String title = 'clip.mp4',
}) {
  return Evaluation(
    id: 'MED-42',
    title: title,
    score: parsed.overallScore / 5,
    composition: '',
    lighting: '',
    feedback: parsed.feedback,
    date: 'Nov 9, 2026',
    mediaType: mediaType ?? parsed.mediaType,
    imageUrl: imageUrl,
    criteria: parsed.criteria,
    parsedEvaluation: parsed,
    recommendation: parsed.recommendation,
    qualityLevel: parsed.qualityLevel,
    scoringModel: parsed.scoringModel,
  );
}

void main() {
  test('notification and history paths show identical video criteria and overall', () {
    final parsed = _videoResult(criteria: _nineVideoCriteria(), mediaType: 'photo');
    // Notification-like: mediaType may be wrong on parsed, but file/url says video.
    final fromNotification = _evaluation(
      parsed: parsed,
      mediaType: 'photo',
      imageUrl: 'http://127.0.0.1:3001/api/media/42/stream?name=clip.mp4',
      title: 'clip.mp4',
    );
    // History-like after refresh: same saved row.
    final fromHistory = _evaluation(
      parsed: parsed,
      mediaType: 'photo',
      imageUrl: 'http://127.0.0.1:3001/api/media/42/stream?name=clip.mp4',
      title: 'clip.mp4',
    );

    final a = evaluationToPhotoResult(fromNotification)!;
    final b = evaluationToPhotoResult(fromHistory)!;

    expect(a.mediaType, 'video');
    expect(b.mediaType, 'video');
    expect(a.overallScore, b.overallScore);
    expect(a.displayCriteria().map((c) => c.name).toList(), b.displayCriteria().map((c) => c.name).toList());
    expect(a.displayCriteria().map((c) => c.name), containsAll(['Motion Stability', 'Flickering', 'Blocking Artifacts']));
    expect(a.displayCriteria().length, 9);
  });

  test('new video evaluation keeps all nine criteria including Motion and Flickering', () {
    final parsed = _videoResult(criteria: _nineVideoCriteria(), mediaType: 'video');
    final names = parsed.displayCriteria(isVideo: true).map((c) => c.name).toList();
    expect(names, [
      'Sharpness',
      'Blur',
      'Brightness',
      'Contrast',
      'Blocking Artifacts',
      'Color Balance',
      'Color Saturation',
      'Motion Stability',
      'Flickering',
    ]);
  });

  test('N/A Motion Stability and Flickering are preserved, not dropped', () {
    final raw = {
      'media_type': 'video',
      'overall_score': 4.0,
      'quality_level': 'Good',
      'criteria': [
        {'name': 'Sharpness', 'score': 4, 'explanation': '', 'suggestion': '', 'available': true},
        {
          'name': 'Motion Stability',
          'score': null,
          'label': 'N/A',
          'explanation': 'Not enough tracks',
          'suggestion': '',
          'available': false,
        },
        {
          'name': 'Flickering',
          'score': null,
          'label': 'N/A',
          'explanation': 'Insufficient frames',
          'suggestion': '',
          'available': false,
        },
      ],
      'ai_detection': {'verdict': 'authentic', 'confidence': 0.9, 'detail': ''},
    };
    final parsed = PhotoEvaluationResult.fromJson(raw)!;
    final motion = parsed.criteria.firstWhere((c) => c.name == 'Motion Stability');
    final flicker = parsed.criteria.firstWhere((c) => c.name == 'Flickering');
    expect(motion.available, isFalse);
    expect(flicker.available, isFalse);
    expect(motion.displayScoreText, 'N/A');
    expect(parsed.displayCriteria(isVideo: true).map((c) => c.name), containsAll(['Motion Stability', 'Flickering']));
  });

  test('historical video without Motion/Flickering does not fabricate them', () {
    final parsed = _videoResult(
      mediaType: 'video',
      criteria: [
        _c('Sharpness', 4),
        _c('Blur', 3),
        _c('Brightness', 5),
        _c('Contrast', 3),
        _c('Blocking Artifacts', 3),
        _c('Color Balance', 5),
        _c('Color Saturation', 5),
      ],
    );
    final names = parsed.displayCriteria(isVideo: true).map((c) => c.name).toList();
    expect(names, isNot(contains('Motion Stability')));
    expect(names, isNot(contains('Flickering')));
    expect(names, contains('Blocking Artifacts'));
    expect(names.length, 7);
  });

  test('photo evaluation stays at seven criteria', () {
    final parsed = _videoResult(
      mediaType: 'photo',
      criteria: [
        _c('Sharpness', 4),
        _c('Blur', 3),
        _c('Brightness', 5),
        _c('Contrast', 3),
        _c('Blocking Artifacts', 3),
        _c('Color Balance', 5),
        _c('Color Saturation', 5),
      ],
    );
    final ev = _evaluation(parsed: parsed, mediaType: 'photo', title: 'shot.jpg', imageUrl: 'http://x/shot.jpg');
    final result = evaluationToPhotoResult(ev)!;
    expect(result.mediaType, 'photo');
    expect(result.displayCriteria().length, 7);
    expect(result.displayCriteria().map((c) => c.name), isNot(contains('Motion Stability')));
  });

  test('defaulted photo media_type still shows saved video-only criteria', () {
    final parsed = _videoResult(criteria: _nineVideoCriteria(), mediaType: 'photo');
    final names = orderCriteriaForDisplay(parsed.criteria, isVideo: false).map((c) => c.name).toList();
    expect(names, containsAll(['Motion Stability', 'Flickering']));
    expect(isVideoPracticeEvaluation(_evaluation(parsed: parsed, mediaType: 'photo', title: 'a.mp4')), isTrue);
  });
}
