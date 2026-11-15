/// Backend quality Skill Classification (Photo/Video). Not XP / skill progression tiers.
class MediaQualityClassification {
  const MediaQualityClassification({
    required this.mediaKind,
    required this.title,
    required this.qualifyingEvaluations,
    required this.classified,
    this.averageScore,
    this.averageScoreDisplay,
    this.windowSize = 10,
    this.formulaVersion,
    this.nextTitle,
    this.scoreGap,
    this.evaluationsGap,
    this.progressSummary = '',
  });

  final String mediaKind;
  final String title;
  final double? averageScore;
  final double? averageScoreDisplay;
  final int qualifyingEvaluations;
  final int windowSize;
  final String? formulaVersion;
  final String? nextTitle;
  final double? scoreGap;
  final int? evaluationsGap;
  final String progressSummary;
  final bool classified;

  factory MediaQualityClassification.fromJson(Map<String, dynamic> j) {
    return MediaQualityClassification(
      mediaKind: j['media_kind'] as String? ?? 'photo',
      title: j['title'] as String? ?? 'Not Yet Classified',
      averageScore: (j['average_score'] as num?)?.toDouble(),
      averageScoreDisplay: (j['average_score_display'] as num?)?.toDouble(),
      qualifyingEvaluations: (j['qualifying_evaluations'] as num?)?.toInt() ?? 0,
      windowSize: (j['window_size'] as num?)?.toInt() ?? 10,
      formulaVersion: j['formula_version'] as String?,
      nextTitle: j['next_title'] as String?,
      scoreGap: (j['score_gap'] as num?)?.toDouble(),
      evaluationsGap: (j['evaluations_gap'] as num?)?.toInt(),
      progressSummary: j['progress_summary'] as String? ?? '',
      classified: j['classified'] == true,
    );
  }

  String get averageLabel {
    final v = averageScoreDisplay ?? averageScore;
    if (v == null) return 'N/A';
    return '${v.toStringAsFixed(2)}/5';
  }
}

class QualitySkillGuideTier {
  const QualitySkillGuideTier({
    required this.title,
    required this.meaning,
    required this.scoreRange,
    required this.minimumEvaluations,
    required this.focus,
    this.nextTitle,
    this.nextMinimumAverage,
    this.nextMinimumEvaluations,
  });

  final String title;
  final String meaning;
  final String scoreRange;
  final int minimumEvaluations;
  final String focus;
  final String? nextTitle;
  final double? nextMinimumAverage;
  final int? nextMinimumEvaluations;

  factory QualitySkillGuideTier.fromJson(Map<String, dynamic> j) {
    final next = j['next'];
    Map<String, dynamic>? nextMap;
    if (next is Map) {
      nextMap = Map<String, dynamic>.from(next);
    }
    return QualitySkillGuideTier(
      title: j['title'] as String? ?? '',
      meaning: j['meaning'] as String? ?? '',
      scoreRange: j['score_range'] as String? ?? '',
      minimumEvaluations: (j['minimum_evaluations'] as num?)?.toInt() ?? 0,
      focus: j['focus'] as String? ?? '',
      nextTitle: nextMap?['title'] as String?,
      nextMinimumAverage: (nextMap?['minimum_average_score'] as num?)?.toDouble(),
      nextMinimumEvaluations: (nextMap?['minimum_evaluations'] as num?)?.toInt(),
    );
  }
}

class QualitySkillClassificationSnapshot {
  const QualitySkillClassificationSnapshot({
    required this.photo,
    required this.video,
    required this.disclaimer,
    this.guide = const [],
  });

  final MediaQualityClassification photo;
  final MediaQualityClassification video;
  final String disclaimer;
  final List<QualitySkillGuideTier> guide;

  factory QualitySkillClassificationSnapshot.fromJson(Map<String, dynamic> j) {
    final photoRaw = j['photo'];
    final videoRaw = j['video'];
    final guideRaw = j['guide'];
    return QualitySkillClassificationSnapshot(
      photo: photoRaw is Map
          ? MediaQualityClassification.fromJson(Map<String, dynamic>.from(photoRaw))
          : const MediaQualityClassification(
              mediaKind: 'photo',
              title: 'Not Yet Classified',
              qualifyingEvaluations: 0,
              classified: false,
            ),
      video: videoRaw is Map
          ? MediaQualityClassification.fromJson(Map<String, dynamic>.from(videoRaw))
          : const MediaQualityClassification(
              mediaKind: 'video',
              title: 'Not Yet Classified',
              qualifyingEvaluations: 0,
              classified: false,
            ),
      disclaimer: j['disclaimer'] as String? ??
          'Classifications are automated media-quality assessments, not professional certifications.',
      guide: guideRaw is List
          ? guideRaw
              .whereType<Map>()
              .map((e) => QualitySkillGuideTier.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  MediaQualityClassification forMedia({required bool isVideo}) =>
      isVideo ? video : photo;

  /// Compact chip for Home / Rankings (never invents titles).
  String get compactChipLabel {
    final photoOk = photo.classified;
    final videoOk = video.classified;
    if (!photoOk && !videoOk) return 'Not Yet Classified';
    if (photoOk && videoOk) {
      return 'Photo Skill ${photo.title} · Video Skill ${video.title}';
    }
    if (photoOk) return 'Photo Skill: ${photo.title}';
    return 'Video Skill: ${video.title}';
  }

  String get photoLine => 'Photo Skill: ${photo.title}';
  String get videoLine => 'Video Skill: ${video.title}';
}
