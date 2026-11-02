import 'package:access_mobile/mobile_app/utils/skill_progress_trend.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _ev({required double score, required DateTime at}) {
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
  });
}
