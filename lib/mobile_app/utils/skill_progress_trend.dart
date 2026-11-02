import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';

/// Documented thresholds for eligible quality trend (percentage points, 0–100 scale).
class SkillProgressTrendThresholds {
  SkillProgressTrendThresholds._();

  /// Latest minus previous ≥ this → Improving.
  static const double improvingMinDelta = 3.0;

  /// Latest minus previous ≤ this → Declining.
  static const double decliningMaxDelta = -3.0;

  /// Need at least two chronological eligible points in the filter.
  static const int minPointsForTrend = 2;
}

enum SkillProgressTrend {
  improving,
  stable,
  declining,
  insufficientData,
}

extension SkillProgressTrendLabel on SkillProgressTrend {
  String get label => switch (this) {
        SkillProgressTrend.improving => 'Improving',
        SkillProgressTrend.stable => 'Stable',
        SkillProgressTrend.declining => 'Declining',
        SkillProgressTrend.insufficientData => 'Insufficient data',
      };
}

List<Evaluation> chronologicalEligibleEvaluations(
  Iterable<Evaluation> source, {
  bool? videoOnly,
}) {
  var list = skillEligibleEvaluations(source).toList();
  if (videoOnly == true) {
    list = list.where(isVideoPracticeEvaluation).toList();
  } else if (videoOnly == false) {
    list = list.where((e) => !isVideoPracticeEvaluation(e)).toList();
  }
  list.sort((a, b) {
    final ta = a.evaluatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.evaluatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ta.compareTo(tb);
  });
  return list;
}

SkillProgressTrend computeSkillProgressTrend(List<Evaluation> chronologicalEligible) {
  if (chronologicalEligible.length < SkillProgressTrendThresholds.minPointsForTrend) {
    return SkillProgressTrend.insufficientData;
  }
  final latest = chronologicalEligible.last.displayPercent.toDouble();
  final previous = chronologicalEligible[chronologicalEligible.length - 2].displayPercent.toDouble();
  final delta = latest - previous;
  if (delta >= SkillProgressTrendThresholds.improvingMinDelta) {
    return SkillProgressTrend.improving;
  }
  if (delta <= SkillProgressTrendThresholds.decliningMaxDelta) {
    return SkillProgressTrend.declining;
  }
  return SkillProgressTrend.stable;
}

({Evaluation? latest, Evaluation? previous, double? deltaPoints}) latestVersusPrevious(
  List<Evaluation> chronologicalEligible,
) {
  if (chronologicalEligible.isEmpty) {
    return (latest: null, previous: null, deltaPoints: null);
  }
  final latest = chronologicalEligible.last;
  if (chronologicalEligible.length < 2) {
    return (latest: latest, previous: null, deltaPoints: null);
  }
  final previous = chronologicalEligible[chronologicalEligible.length - 2];
  final delta = latest.displayPercent - previous.displayPercent;
  return (latest: latest, previous: previous, deltaPoints: delta.toDouble());
}
