import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
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

  /// Active Clarity Option C formula for comparable trends.
  static const String preferredFormulaVersion = 'v2';
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

/// Quality overall on the member-facing 1–5 scale (excludes AI risk / MUSIQ OPQ).
double qualityScoreOutOfFive(Evaluation e) =>
    (e.displayScore * 5.0).clamp(0.0, 5.0);

String formatQualityOutOfFive(double score) =>
    '${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1)}/5';

String formatQualityDeltaOutOfFive(double? deltaPoints) {
  if (deltaPoints == null) return 'N/A';
  // Percentage points → /5 scale (20 pp = 1.0 on the five-level score).
  final deltaFive = (deltaPoints / 20.0 * 10).round() / 10.0;
  if (deltaFive == 0) return '0.0';
  final sign = deltaFive > 0 ? '+' : '';
  return '$sign${deltaFive.toStringAsFixed(1)}';
}

/// Effective scoring formula (`v1` when missing — historical rows).
String evaluationFormulaVersion(Evaluation e) {
  final parsed = e.parsedEvaluation?.scoringFormulaVersionEffective;
  if (parsed != null && parsed.trim().isNotEmpty) {
    return parsed.trim().toLowerCase();
  }
  return 'v1';
}

List<Evaluation> chronologicalEligibleEvaluations(
  Iterable<Evaluation> source, {
  bool? videoOnly,
  String? formulaVersion,
}) {
  var list = skillEligibleEvaluations(source).toList();
  if (videoOnly == true) {
    list = list.where(isVideoPracticeEvaluation).toList();
  } else if (videoOnly == false) {
    list = list.where((e) => !isVideoPracticeEvaluation(e)).toList();
  }
  if (formulaVersion != null && formulaVersion.trim().isNotEmpty) {
    final want = formulaVersion.trim().toLowerCase();
    list = list.where((e) => evaluationFormulaVersion(e) == want).toList();
  }
  list.sort((a, b) {
    final ta = a.evaluatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.evaluatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ta.compareTo(tb);
  });
  return list;
}

/// Prefer current v2 Clarity Option C series; never mix v1 into the same trend.
List<Evaluation> comparableImprovementSeries(
  Iterable<Evaluation> source, {
  required bool videoOnly,
}) {
  final v2 = chronologicalEligibleEvaluations(
    source,
    videoOnly: videoOnly,
    formulaVersion: SkillProgressTrendThresholds.preferredFormulaVersion,
  );
  if (v2.length >= SkillProgressTrendThresholds.minPointsForTrend) {
    return v2;
  }
  // Fewer than 2 v2 points: still return the v2-only list (may be 0–1) so UI
  // shows empty/insufficient rather than blending legacy v1 scores.
  return v2;
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

/// Criterion deltas between two comparable evaluations (N/A metrics excluded).
List<({String name, int? previous, int? latest, int? delta, String? suggestion})>
    criterionLevelChanges(Evaluation? previous, Evaluation? latest) {
  if (latest == null) return const [];
  final latestByName = <String, CriterionScore>{
    for (final c in latest.criteria)
      if (c.name.trim().isNotEmpty) c.name.trim(): c,
  };
  final previousByName = <String, CriterionScore>{
    for (final c in previous?.criteria ?? const <CriterionScore>[])
      if (c.name.trim().isNotEmpty) c.name.trim(): c,
  };
  final names = <String>{...latestByName.keys, ...previousByName.keys}.toList()
    ..sort();
  final out = <({String name, int? previous, int? latest, int? delta, String? suggestion})>[];
  for (final name in names) {
    final a = previousByName[name];
    final b = latestByName[name];
    final aOk = a?.available == true;
    final bOk = b?.available == true;
    if (!aOk && !bOk) continue;
    final prevScore = aOk ? a!.score : null;
    final latestScore = bOk ? b!.score : null;
    final delta = (prevScore != null && latestScore != null)
        ? latestScore - prevScore
        : null;
    final tip = (b?.suggestion.trim().isNotEmpty == true)
        ? b!.suggestion.trim()
        : (a?.suggestion.trim().isNotEmpty == true ? a!.suggestion.trim() : null);
    out.add((
      name: name,
      previous: prevScore,
      latest: latestScore,
      delta: delta,
      suggestion: tip,
    ));
  }
  return out;
}
