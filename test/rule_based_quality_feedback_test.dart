import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/rule_based_quality_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

List<RuleBasedQualityInput> seven({
  int sharpness = 4,
  int blur = 4,
  int brightness = 3,
  int contrast = 3,
  int blocking = 5,
  int colorBalance = 3,
  int colorSaturation = 3,
  bool blurAvailable = true,
}) {
  return [
    RuleBasedQualityInput(name: 'Sharpness', score: sharpness),
    RuleBasedQualityInput(name: 'Blur', score: blur, available: blurAvailable),
    RuleBasedQualityInput(name: 'Brightness', score: brightness),
    RuleBasedQualityInput(name: 'Contrast', score: contrast),
    RuleBasedQualityInput(name: 'Blocking Artifacts', score: blocking),
    RuleBasedQualityInput(name: 'Color Balance', score: colorBalance),
    RuleBasedQualityInput(name: 'Color Saturation', score: colorSaturation),
  ];
}

void main() {
  test('all-good evaluation is positive with maintenance tips', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: seven(
        sharpness: 5,
        blur: 5,
        brightness: 5,
        contrast: 5,
        blocking: 5,
        colorBalance: 5,
        colorSaturation: 5,
      ),
      isVideo: false,
      overallScore: 5,
      qualityLevel: 'Excellent',
    );
    expect(fb.improvements, isEmpty);
    expect(fb.strengths, isNotEmpty);
    expect(fb.tips, isNotEmpty);
    expect(fb.explanation.toLowerCase(), contains('great'));
  });

  test('sharpness and blur are combined into one clarity recommendation', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: seven(sharpness: 1, blur: 2, brightness: 5, contrast: 5, blocking: 5, colorBalance: 5, colorSaturation: 5),
      isVideo: false,
      overallScore: 3.7,
      qualityLevel: 'Good',
    );
    expect(fb.improvements.any((i) => i.contains('Clarity')), isTrue);
    expect(fb.tips.any((t) => t.contains('softness and blur in one step')), isTrue);
    expect(fb.strengths.any((s) => s.startsWith('Sharpness') || s.startsWith('Blur')), isFalse);
  });

  test('N/A blur is not treated as a weakness', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: [
        const RuleBasedQualityInput(name: 'Sharpness', score: 5),
        const RuleBasedQualityInput(name: 'Blur', score: 0, available: false),
        const RuleBasedQualityInput(name: 'Brightness', score: 1, explanation: 'Scene is quite dark.'),
        const RuleBasedQualityInput(name: 'Contrast', score: 5),
        const RuleBasedQualityInput(name: 'Blocking Artifacts', score: 5),
        const RuleBasedQualityInput(name: 'Color Balance', score: 0, available: false),
        const RuleBasedQualityInput(name: 'Color Saturation', score: 5),
      ],
      isVideo: false,
      overallScore: 4.0,
      qualityLevel: 'Good',
    );
    final joined = [...fb.improvements, ...fb.tips].join(' ').toLowerCase();
    expect(joined.contains('color balance'), isFalse);
    expect(fb.improvements.any((i) => i.contains('Brightness')), isTrue);
  });

  test('insufficient metrics explains limited feedback', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: const [RuleBasedQualityInput(name: 'Sharpness', score: 4)],
      isVideo: false,
      overallScore: 4,
      qualityLevel: 'Good',
    );
    expect(fb.insufficientMetrics, isTrue);
    expect(fb.explanation.toLowerCase(), contains('limited'));
  });

  test('fromLocal uses rule-based builder and keeps MediaEvaluationFeedback shape', () {
    final result = PhotoEvaluationResult(
      criteria: [
        const CriterionScore(name: 'Sharpness', score: 1, explanation: '', suggestion: ''),
        const CriterionScore(name: 'Blur', score: 1, explanation: '', suggestion: ''),
        const CriterionScore(name: 'Brightness', score: 5, explanation: '', suggestion: ''),
        const CriterionScore(name: 'Contrast', score: 5, explanation: '', suggestion: ''),
        const CriterionScore(name: 'Blocking Artifacts', score: 5, explanation: '', suggestion: ''),
        const CriterionScore(name: 'Color Balance', score: 5, explanation: '', suggestion: ''),
        const CriterionScore(name: 'Color Saturation', score: 5, explanation: '', suggestion: ''),
      ],
      overallScore: 3.86,
      qualityLevel: 'Good',
      feedback: '',
      improvementSuggestions: '',
      recommendation: 'Accepted',
      aiDetection: const AiDetectionResult(verdict: 'authentic', confidence: 0.9, detail: ''),
      mediaType: 'photo',
      scoringModel: 'musiq',
      strengths: const [],
      weaknesses: const [],
    );
    final local = MediaEvaluationFeedback.fromLocal(result);
    expect(local.explanation, isNotEmpty);
    expect(local.improvements.any((i) => i.contains('Clarity')), isTrue);
    expect(local.toJson().keys, containsAll(['explanation', 'strengths', 'improvements', 'tips', 'closing_message']));
  });

  test('backend/flutter consistency markers for clarity tip', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: seven(sharpness: 1, blur: 1, brightness: 5, contrast: 5, blocking: 5, colorBalance: 5, colorSaturation: 5),
      isVideo: false,
      overallScore: 3.3,
      qualityLevel: 'Fair',
    );
    expect(fb.improvements.any((i) => i.startsWith('Clarity:')), isTrue);
    expect(fb.tips.any((t) => t.contains('softness and blur in one step')), isTrue);
  });

  test('narratives contain no numerical measurements while metric scores remain', () {
    final criteria = seven(sharpness: 1, blur: 2, brightness: 5, contrast: 5, blocking: 5, colorBalance: 1, colorSaturation: 5);
    final fb = RuleBasedQualityFeedback.build(
      criteria: criteria,
      isVideo: false,
      overallScore: 3.4,
      qualityLevel: 'Fair',
    );
    final chunks = <String>[
      fb.explanation,
      fb.closingMessage,
      ...fb.strengths,
      ...fb.improvements,
      ...fb.tips,
    ];
    for (final chunk in chunks) {
      expect(RuleBasedQualityFeedback.narrativeContainsMeasurements(chunk), isFalse, reason: chunk);
      expect(chunk.contains('/5'), isFalse, reason: chunk);
      expect(chunk.contains('%'), isFalse, reason: chunk);
    }
    expect(criteria.any((c) => c.name == 'Sharpness' && c.score == 1), isTrue);
    expect(fb.improvements.any((i) => i.contains('Clarity') || i.contains('Color Balance')), isTrue);
  });

  test('withoutNarrativeMeasurements strips Gemini-style scores', () {
    const dirty = MediaEvaluationFeedback(
      explanation: 'Nice work at 4/5 (80%)!',
      strengths: ['Sharpness (5/5): crisp detail'],
      improvements: ['Blur scored 2'],
      tips: ['Raise exposure by 20%'],
      closingMessage: 'Keep going!',
    );
    final clean = dirty.withoutNarrativeMeasurements();
    for (final chunk in [clean.explanation, ...clean.strengths, ...clean.improvements, ...clean.tips, clean.closingMessage]) {
      expect(RuleBasedQualityFeedback.narrativeContainsMeasurements(chunk), isFalse, reason: chunk);
    }
  });

  test('warning-only underexposure yields add-light brightness tip', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: seven(sharpness: 5, blur: 5, brightness: 2, contrast: 5, blocking: 5, colorBalance: 5, colorSaturation: 5),
      isVideo: false,
      overallScore: 4.57,
      qualityLevel: 'Excellent',
      qualityWarnings: const ['Media is quite dark — more light would improve detail.'],
    );
    expect(fb.tips.any((t) => t.contains('Add light') || t.contains('raise exposure')), isTrue);
    expect(fb.tips.any((t) => RuleBasedQualityFeedback.narrativeContainsMeasurements(t)), isFalse);
  });

  test('missing warnings keep neutral brightness tip', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: seven(sharpness: 5, blur: 5, brightness: 2, contrast: 5, blocking: 5, colorBalance: 5, colorSaturation: 5),
      isVideo: false,
      overallScore: 4.57,
      qualityLevel: 'Excellent',
    );
    expect(fb.tips.any((t) => t.contains('even light') || t.contains('without guessing')), isTrue);
    expect(fb.tips.any((t) => t.startsWith('Add light')), isFalse);
  });

  test('conflicting directional evidence stays neutral', () {
    final fb = RuleBasedQualityFeedback.build(
      criteria: seven(sharpness: 5, blur: 5, brightness: 2, contrast: 5, blocking: 5, colorBalance: 5, colorSaturation: 5),
      isVideo: false,
      overallScore: 4.57,
      qualityLevel: 'Excellent',
      qualityWarnings: const [
        'Media is quite dark',
        'Media may be overexposed — highlights could be washed out.',
      ],
    );
    expect(fb.tips.any((t) => t.contains('even light') || t.contains('without guessing')), isTrue);
    expect(fb.tips.any((t) => t.startsWith('Add light')), isFalse);
    expect(fb.tips.any((t) => t.startsWith('Reduce intense light')), isFalse);
  });
}
