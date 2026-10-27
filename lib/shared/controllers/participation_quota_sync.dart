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

Map<String, dynamic> participationFieldsFromApi(Map<String, dynamic> participation) {
  return {
    'uploads_count': participation['uploads_count'] as int? ?? 0,
    'assignments_completed': participation['assignments_completed'] as int? ?? 0,
    'average_score': (participation['average_score'] as num?)?.toDouble() ?? 0,
    'total_points': participation['total_points'] as int? ?? 0,
    'evaluations_count': participation['evaluations_count'] as int? ?? 0,
    'evaluations_today': participation['evaluations_today'] as int? ?? 0,
    'daily_evaluation_limit': participation['daily_evaluation_limit'] as int? ?? 5,
    'evaluation_max_upload_mb': participation['evaluation_max_upload_mb'] as int? ?? 350,
    'evaluation_max_video_seconds':
        participation['evaluation_max_video_seconds'] as int? ?? 30,
    'evaluation_daily_timezone':
        participation['evaluation_daily_timezone'] as String? ?? 'Asia/Manila',
  };
}
