// Client-side skill score (mirrors backend skill_scoring.py).

double mediaQualityPercent(double averageQualityScore) {
  if (averageQualityScore <= 0) return 0;
  if (averageQualityScore <= 1) return averageQualityScore * 100;
  return averageQualityScore.clamp(0, 100);
}

double _pct(double num, double den, {double defaultValue = 0}) {
  if (den <= 0) return defaultValue;
  return (num / den * 100).clamp(0, 100);
}

double approvedUploadsPercent(int approved, int total) => _pct(approved.toDouble(), total.toDouble());

double taskParticipationPercent(int completed, int assigned) =>
    _pct(completed.toDouble(), assigned.toDouble());

double aiAuthenticityPercent(int humanVerified, int totalChecked) {
  if (totalChecked <= 0) return 100;
  return _pct(humanVerified.toDouble(), totalChecked.toDouble());
}

/// Skill level uses evaluation quality + media integrity only (mirrors backend).
double computeSkillScore({
  required double mediaQualityScore,
  required double aiAuthenticityScore,
}) {
  return mediaQualityScore * 0.70 + aiAuthenticityScore * 0.30;
}

String skillLevelFromScore(double skillScore) {
  if (skillScore >= 90) return 'Expert';
  if (skillScore >= 75) return 'Advanced';
  if (skillScore >= 60) return 'Intermediate';
  return 'Beginner';
}

Map<String, dynamic> buildSkillPayload({
  required double averageQualityScore,
  required int approvedUploads,
  required int totalUploads,
  required int completedTasks,
  required int assignedTasks,
  required double adminEvaluationScore,
  required int humanVerifiedUploads,
  required int totalCheckedUploads,
}) {
  final mediaQ = mediaQualityPercent(averageQualityScore);
  final approvedQ = approvedUploadsPercent(approvedUploads, totalUploads);
  final taskQ = taskParticipationPercent(completedTasks, assignedTasks);
  final adminQ = adminEvaluationScore.clamp(0, 100).toDouble();
  final aiQ = aiAuthenticityPercent(humanVerifiedUploads, totalCheckedUploads);
  final skillScore = computeSkillScore(
    mediaQualityScore: mediaQ,
    aiAuthenticityScore: aiQ,
  );
  return {
    'average_quality_score': mediaQ,
    'approved_uploads': approvedUploads,
    'total_uploads': totalUploads,
    'completed_tasks': completedTasks,
    'assigned_tasks': assignedTasks,
    'admin_evaluation_score': adminQ,
    'ai_authenticity_score': aiQ,
    'media_quality_score': mediaQ,
    'approved_uploads_score': approvedQ,
    'task_participation_score': taskQ,
    'skill_score': skillScore,
    'skill_level': skillLevelFromScore(skillScore),
  };
}
