import 'package:access_mobile/web_admin/utils/skill_scoring.dart';

enum SkillLevelTier { beginner, intermediate, advanced, expert }

enum ParticipationStatus { active, inactive, needsTraining, underReview }

enum RankingSort { rank, points, uploads, averageQuality, skillScore, lastActivity }

class MemberRankingRow {
  MemberRankingRow({
    required this.id,
    required this.rank,
    required this.memberName,
    required this.skillLevel,
    required this.skillScore,
    required this.points,
    required this.uploads,
    required this.averageQualityScore,
    required this.approvedUploads,
    required this.totalUploads,
    required this.completedTasks,
    required this.assignedTasks,
    required this.adminEvaluationScore,
    required this.aiAuthenticityScore,
    required this.mediaQualityScore,
    required this.approvedUploadsScore,
    required this.taskParticipationScore,
    required this.aiResultSummary,
    required this.participationStatus,
    required this.lastActivity,
    required this.adminRemarks,
    this.competencyLevelOverride,
    this.competencyRecommendedLevel,
  });

  final int id;
  final int rank;
  final String memberName;
  final String skillLevel;
  final double skillScore;
  final int points;
  final int uploads;
  final double averageQualityScore;
  final int approvedUploads;
  final int totalUploads;
  final int completedTasks;
  final int assignedTasks;
  final double adminEvaluationScore;
  final double aiAuthenticityScore;
  final double mediaQualityScore;
  final double approvedUploadsScore;
  final double taskParticipationScore;
  final String aiResultSummary;
  final ParticipationStatus participationStatus;
  final DateTime? lastActivity;
  final String? adminRemarks;
  final String? competencyLevelOverride;
  final String? competencyRecommendedLevel;

  factory MemberRankingRow.fromMap(Map<String, dynamic> m) {
    final rank = m['rank'] as int? ?? m['rank_position'] as int? ?? 0;
    final avgRaw = (m['average_quality_score'] as num?)?.toDouble() ??
        (m['avg_score'] as num?)?.toDouble() ??
        0;
    final approved = m['approved_uploads'] as int? ?? 0;
    final totalUp = m['total_uploads'] as int? ?? m['uploads'] as int? ?? 0;
    final completed = m['completed_tasks'] as int? ?? 0;
    final assigned = m['assigned_tasks'] as int? ?? 0;
    final adminEval = (m['admin_evaluation_score'] as num?)?.toDouble() ?? 0;
    final human = m['ai_human_count'] as int? ?? 0;
    final flagged = m['ai_flagged_count'] as int? ?? 0;
    final totalChecked = human + flagged;

    Map<String, dynamic> skill;
    if (m['skill_score'] != null && m['skill_level'] != null) {
      skill = {
        'skill_score': (m['skill_score'] as num).toDouble(),
        'skill_level': m['skill_level'] as String,
        'average_quality_score': (m['media_quality_score'] as num?)?.toDouble() ?? mediaQualityPercent(avgRaw),
        'media_quality_score': (m['media_quality_score'] as num?)?.toDouble() ?? mediaQualityPercent(avgRaw),
        'approved_uploads_score': (m['approved_uploads_score'] as num?)?.toDouble() ?? 0,
        'task_participation_score': (m['task_participation_score'] as num?)?.toDouble() ?? 0,
        'admin_evaluation_score': adminEval,
        'ai_authenticity_score': (m['ai_authenticity_score'] as num?)?.toDouble() ?? 100,
      };
    } else {
      skill = buildSkillPayload(
        averageQualityScore: avgRaw,
        approvedUploads: approved,
        totalUploads: totalUp,
        completedTasks: completed,
        assignedTasks: assigned,
        adminEvaluationScore: adminEval,
        humanVerifiedUploads: human,
        totalCheckedUploads: totalChecked > 0 ? totalChecked : 0,
      );
    }

    return MemberRankingRow(
      id: m['id'] as int? ?? m['user_id'] as int? ?? 0,
      rank: rank,
      memberName: m['member_name'] as String? ?? m['name'] as String? ?? 'Unknown',
      skillLevel: skill['skill_level'] as String,
      skillScore: (skill['skill_score'] as num).toDouble(),
      points: m['points'] as int? ?? m['good_evaluations'] as int? ?? 0,
      uploads: totalUp,
      averageQualityScore: (skill['average_quality_score'] as num).toDouble(),
      approvedUploads: approved,
      totalUploads: totalUp,
      completedTasks: completed,
      assignedTasks: assigned,
      adminEvaluationScore: (skill['admin_evaluation_score'] as num).toDouble(),
      aiAuthenticityScore: (skill['ai_authenticity_score'] as num).toDouble(),
      mediaQualityScore: (skill['media_quality_score'] as num).toDouble(),
      approvedUploadsScore: (skill['approved_uploads_score'] as num).toDouble(),
      taskParticipationScore: (skill['task_participation_score'] as num).toDouble(),
      aiResultSummary: m['ai_result_summary'] as String? ?? '—',
      participationStatus: participationStatusFromString(m['participation_status'] as String?),
      lastActivity: _parseDate(m['last_activity']),
      adminRemarks: m['admin_remarks'] as String?,
      competencyLevelOverride: m['competency_level_override'] as String?,
      competencyRecommendedLevel: m['competency_recommended_level'] as String?,
    );
  }

  SkillLevelTier get skillTier => skillLevelFromString(skillLevel);

  String get skillScorePercent => '${skillScore.round()}%';

  String get qualityPercent =>
      averageQualityScore > 0 ? '${averageQualityScore.round()}%' : '—';

  String get adminEvaluationLabel =>
      adminEvaluationScore > 0 ? '${adminEvaluationScore.round()}%' : 'Not yet evaluated';

  String get recommendedAction => recommendedActionFor(this);

  MemberRankingRow copyWith({int? rank, String? adminRemarks}) => MemberRankingRow(
        id: id,
        rank: rank ?? this.rank,
        memberName: memberName,
        skillLevel: skillLevel,
        skillScore: skillScore,
        points: points,
        uploads: uploads,
        averageQualityScore: averageQualityScore,
        approvedUploads: approvedUploads,
        totalUploads: totalUploads,
        completedTasks: completedTasks,
        assignedTasks: assignedTasks,
        adminEvaluationScore: adminEvaluationScore,
        aiAuthenticityScore: aiAuthenticityScore,
        mediaQualityScore: mediaQualityScore,
        approvedUploadsScore: approvedUploadsScore,
        taskParticipationScore: taskParticipationScore,
        aiResultSummary: aiResultSummary,
        participationStatus: participationStatus,
        lastActivity: lastActivity,
        adminRemarks: adminRemarks ?? this.adminRemarks,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

SkillLevelTier skillLevelFromString(String raw) {
  final n = raw.toLowerCase();
  if (n.contains('expert')) return SkillLevelTier.expert;
  if (n.contains('advanced')) return SkillLevelTier.advanced;
  if (n.contains('intermediate')) return SkillLevelTier.intermediate;
  return SkillLevelTier.beginner;
}

ParticipationStatus participationStatusFromString(String? raw) {
  if (raw == null) return ParticipationStatus.active;
  final n = raw.toLowerCase();
  if (n.contains('inactive')) return ParticipationStatus.inactive;
  if (n.contains('training')) return ParticipationStatus.needsTraining;
  if (n.contains('review')) return ParticipationStatus.underReview;
  return ParticipationStatus.active;
}

String formatLastActivity(DateTime? dt) {
  if (dt == null) return 'No activity';
  final local = dt.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

const kSkillScoreTooltip = '''
Skill Score combines:
• Media Quality — 70%
• Media Integrity (AI authenticity) — 30%

Expert: 90–100 | Advanced: 75–89 | Intermediate: 60–74 | Beginner: below 60''';

String recommendedActionFor(MemberRankingRow r) {
  if (r.skillScore >= 90 && r.participationStatus == ParticipationStatus.active) {
    return 'Ready for advanced assignments';
  }
  final ai = r.aiResultSummary.toLowerCase();
  if (ai.contains('ai') && !ai.contains('0 ai') && !ai.contains('no scans')) {
    if (r.participationStatus == ParticipationStatus.underReview) {
      return 'Requires media review';
    }
  }
  if (r.uploads == 0) return 'Encourage participation';
  if (r.skillScore < 60) return 'Needs training';
  if (r.participationStatus == ParticipationStatus.inactive) {
    return 'Encourage participation';
  }
  return 'Continue monitoring';
}

class RankingsSummary {
  const RankingsSummary({
    required this.totalRanked,
    required this.topPerformerName,
    required this.topPerformerPoints,
    required this.mostActiveUploaderName,
    required this.mostActiveUploads,
    required this.needsImprovementCount,
  });

  final int totalRanked;
  final String topPerformerName;
  final int topPerformerPoints;
  final String mostActiveUploaderName;
  final int mostActiveUploads;
  final int needsImprovementCount;

  factory RankingsSummary.fromMap(Map<String, dynamic> m) => RankingsSummary(
        totalRanked: m['total_ranked'] as int? ?? 0,
        topPerformerName: m['top_performer_name'] as String? ?? '—',
        topPerformerPoints: m['top_performer_points'] as int? ?? 0,
        mostActiveUploaderName: m['most_active_uploader_name'] as String? ?? '—',
        mostActiveUploads: m['most_active_uploads'] as int? ?? 0,
        needsImprovementCount: m['needs_improvement_count'] as int? ?? 0,
      );
}
