import 'package:access_mobile/mobile_app/utils/skill_progress_trend.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' hide AiDetectionResult;
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _ev({
  required double score,
  required DateTime at,
  String mediaType = 'photo',
  String? formulaVersion,
  List<CriterionScore> criteria = const [],
}) {
  return Evaluation(
    id: 'MED-${at.millisecondsSinceEpoch}',
    title: 'Test',
    score: score,
    composition: '',
    lighting: '',
    feedback: '',
    date: at.toIso8601String(),
    evaluatedAt: at,
    reviewStatus: 'verified',
    mediaType: mediaType,
    criteria: criteria,
    parsedEvaluation: formulaVersion == null
        ? null
        : PhotoEvaluationResult(
            overallScore: (score * 5).clamp(1, 5).toDouble(),
            qualityLevel: 'Good',
            recommendation: 'Accepted',
            feedback: '',
            improvementSuggestions: '',
            criteria: criteria,
            scoringFormulaVersion: formulaVersion,
            mediaType: mediaType,
            aiDetection: const AiDetectionResult(
              verdict: 'authentic',
              confidence: 0.9,
              detail: '',
            ),
          ),
  );
}

void main() {
  test('computeSkillProgressTrend uses ±3 pt thresholds', () {
    final base = DateTime(2026, 1, 1);
    expect(
      computeSkillProgressTrend([
        _ev(score: 0.70, at: base),
        _ev(score: 0.72, at: base.add(const Duration(days: 1))),
      ]),
      SkillProgressTrend.stable,
    );
    expect(
      computeSkillProgressTrend([
        _ev(score: 0.60, at: base),
        _ev(score: 0.64, at: base.add(const Duration(days: 1))),
      ]),
      SkillProgressTrend.improving,
    );
    expect(
      computeSkillProgressTrend([
        _ev(score: 0.80, at: base),
        _ev(score: 0.75, at: base.add(const Duration(days: 1))),
      ]),
      SkillProgressTrend.declining,
    );
    expect(computeSkillProgressTrend([_ev(score: 0.7, at: base)]), SkillProgressTrend.insufficientData);
  });

  test('latestVersusPrevious returns delta in percentage points', () {
    final t0 = DateTime(2026, 2, 1);
    final t1 = DateTime(2026, 2, 2);
    final pair = latestVersusPrevious([
      _ev(score: 0.65, at: t0),
      _ev(score: 0.72, at: t1),
    ]);
    expect(pair.deltaPoints, 7);
    expect(formatQualityDeltaOutOfFive(pair.deltaPoints), '+0.4');
  });

  test('comparableImprovementSeries never mixes v1 with v2', () {
    final base = DateTime(2026, 3, 1);
    final mixed = [
      _ev(score: 0.60, at: base, formulaVersion: 'v1'),
      _ev(score: 0.70, at: base.add(const Duration(days: 1)), formulaVersion: 'v1'),
      _ev(score: 0.75, at: base.add(const Duration(days: 2)), formulaVersion: 'v2'),
    ];
    final series = comparableImprovementSeries(mixed, videoOnly: false);
    expect(series.length, 1);
    expect(evaluationFormulaVersion(series.single), 'v2');
    expect(computeSkillProgressTrend(series), SkillProgressTrend.insufficientData);
  });

  test('photo and video series stay separate', () {
    final base = DateTime(2026, 4, 1);
    final rows = [
      _ev(score: 0.60, at: base, mediaType: 'photo', formulaVersion: 'v2'),
      _ev(
        score: 0.80,
        at: base.add(const Duration(days: 1)),
        mediaType: 'photo',
        formulaVersion: 'v2',
      ),
      _ev(
        score: 0.50,
        at: base.add(const Duration(days: 2)),
        mediaType: 'video',
        formulaVersion: 'v2',
      ),
      _ev(
        score: 0.51,
        at: base.add(const Duration(days: 3)),
        mediaType: 'video',
        formulaVersion: 'v2',
      ),
    ];
    final photos = comparableImprovementSeries(rows, videoOnly: false);
    final videos = comparableImprovementSeries(rows, videoOnly: true);
    expect(photos.length, 2);
    expect(videos.length, 2);
    expect(photos.every((e) => e.mediaType == 'photo'), isTrue);
    expect(videos.every((e) => e.mediaType == 'video'), isTrue);
    expect(computeSkillProgressTrend(photos), SkillProgressTrend.improving);
    expect(computeSkillProgressTrend(videos), SkillProgressTrend.stable);
  });

  test('criterionLevelChanges skips N/A metrics', () {
    final prev = _ev(
      score: 0.7,
      at: DateTime(2026, 5, 1),
      formulaVersion: 'v2',
      criteria: const [
        CriterionScore(
          name: 'Sharpness',
          score: 3,
          explanation: '',
          suggestion: 'Focus carefully',
        ),
        CriterionScore(
          name: 'Motion Stability',
          score: 0,
          explanation: '',
          suggestion: '',
          available: false,
        ),
      ],
    );
    final latest = _ev(
      score: 0.8,
      at: DateTime(2026, 5, 2),
      formulaVersion: 'v2',
      criteria: const [
        CriterionScore(
          name: 'Sharpness',
          score: 4,
          explanation: '',
          suggestion: 'Focus carefully',
        ),
        CriterionScore(
          name: 'Motion Stability',
          score: 0,
          explanation: '',
          suggestion: '',
          available: false,
        ),
      ],
    );
    final changes = criterionLevelChanges(prev, latest);
    expect(changes.map((c) => c.name), ['Sharpness']);
    expect(changes.single.delta, 1);
  });
}
