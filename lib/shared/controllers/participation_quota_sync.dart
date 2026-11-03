/// Serializes participation quota refreshes so stale responses cannot overwrite
/// newer results or apply after account switch.
class ParticipationRefreshGuard {
  int _generation = 0;
  int? _boundUserId;

  int begin(int userId) {
    _generation += 1;
    _boundUserId = userId;
    return _generation;
  }

  void reset() {
    _generation += 1;
    _boundUserId = null;
  }

  bool shouldApply(int token, int? currentUserId) {
    if (currentUserId == null || _boundUserId == null) return false;
    return token == _generation && currentUserId == _boundUserId;
  }

  bool isLatestToken(int token) => token == _generation;
}

String? authoritativeSkillTierFromProfile(Map<String, dynamic> profile) {
  final effective = profile['skill_effective_tier'] as String?;
  if (effective != null && effective.trim().isNotEmpty) {
    return effective.trim();
  }
  final level = profile['skill_level'] as String?;
  if (level != null && level.trim().isNotEmpty) {
    return level.trim();
  }
  return null;
}

Map<String, dynamic> participationFieldsFromApi(Map<String, dynamic> participation) {
  return {
    'uploads_count': participation['uploads_count'] as int? ?? 0,
    'assignments_completed': participation['assignments_completed'] as int? ?? 0,
    'average_score': (participation['average_score'] as num?)?.toDouble() ?? 0,
    'total_points': participation['total_points'] as int? ?? 0,
    'evaluations_count': participation['evaluations_count'] as int? ?? 0,
    'skill_eligible_evaluations_count':
        participation['skill_eligible_evaluations_count'] as int? ?? 0,
    'evaluations_today': participation['evaluations_today'] as int? ?? 0,
    'daily_evaluation_limit': participation['daily_evaluation_limit'] as int? ?? 3,
    'evaluation_max_upload_mb': participation['evaluation_max_upload_mb'] as int? ?? 350,
    'evaluation_max_video_seconds':
        participation['evaluation_max_video_seconds'] as int? ?? 30,
    'evaluation_daily_timezone':
        participation['evaluation_daily_timezone'] as String? ?? 'Asia/Manila',
    'skill_eligible_distinct_upload_days':
        participation['skill_eligible_distinct_upload_days'] as int? ?? 0,
    'skill_quality_average':
        (participation['skill_quality_average'] as num?)?.toDouble(),
    'skill_computed_tier': participation['skill_computed_tier'] as String?,
    'skill_effective_tier': participation['skill_effective_tier'] as String?,
    'skill_computed_tier_v2_preview':
        participation['skill_computed_tier_v2_preview'] as String?,
    'skill_next_tier_required_evaluations':
        participation['skill_next_tier_required_evaluations'] as int?,
    'skill_next_tier_required_days':
        participation['skill_next_tier_required_days'] as int?,
    'skill_progression_policy_version':
        participation['skill_progression_policy_version'] as String? ?? 'v1',
    'skill_remaining_eligible_evaluations':
        participation['skill_remaining_eligible_evaluations'] as int? ?? 0,
    'skill_remaining_distinct_upload_days':
        participation['skill_remaining_distinct_upload_days'] as int? ?? 0,
    'skill_remaining_quality_points':
        participation['skill_remaining_quality_points'] as int? ?? 0,
  };
}
