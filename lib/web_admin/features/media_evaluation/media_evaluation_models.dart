import 'dart:convert';

/// Normalized media evaluation row for admin UI.
class MediaEvaluationRow {
  MediaEvaluationRow({
    required this.id,
    required this.mediaId,
    required this.mediaName,
    required this.memberName,
    required this.fileUrl,
    required this.sharpnessScore,
    required this.brightnessScore,
    required this.contrastScore,
    required this.overallScore,
    required this.aiResult,
    required this.adminRemarks,
    required this.evaluatedAt,
    this.qualityLevel,
    this.recommendation,
    this.criteria = const [],
    this.isStandalone = true,
    this.sourceLabel = 'Practice evaluation',
  });

  final int id;
  final int mediaId;
  final String mediaName;
  final String memberName;
  final String fileUrl;
  final double sharpnessScore;
  final double brightnessScore;
  final double contrastScore;
  final double overallScore;
  final String? aiResult;
  final String? adminRemarks;
  final DateTime? evaluatedAt;
  final String? qualityLevel;
  final String? recommendation;
  final List<EvaluationCriterionRow> criteria;
  final bool isStandalone;
  final String sourceLabel;

  factory MediaEvaluationRow.fromMap(Map<String, dynamic> m) {
    final criteria = _parseCriteria(m['criteria_json']);
    return MediaEvaluationRow(
      id: m['id'] as int? ?? 0,
      mediaId: m['media_id'] as int? ?? 0,
      mediaName: m['media_name'] as String? ?? m['file_name'] as String? ?? 'Untitled',
      memberName: m['member_name'] as String? ?? m['uploader_name'] as String? ?? 'Unknown',
      fileUrl: m['file_url'] as String? ?? '',
      sharpnessScore: _toScore(m['sharpness_score']),
      brightnessScore: _toScore(m['brightness_score']),
      contrastScore: _toScore(m['contrast_score']),
      overallScore: _toScore(m['overall_score']),
      aiResult: m['ai_result'] as String? ?? m['detection_result'] as String?,
      adminRemarks: m['admin_remarks'] as String? ?? m['feedback'] as String?,
      evaluatedAt: _parseDate(m['created_at'] ?? m['evaluated_at']),
      qualityLevel: m['quality_level'] as String?,
      recommendation: m['recommendation'] as String?,
      criteria: criteria,
      isStandalone: m['is_standalone'] as bool? ?? m['request_id'] == null,
      sourceLabel: m['source_label'] as String? ??
          ((m['is_standalone'] as bool? ?? m['request_id'] == null)
              ? 'Practice evaluation'
              : (m['event_title'] as String? ?? 'Event coverage')),
    );
  }

  static List<EvaluationCriterionRow> _parseCriteria(dynamic raw) {
    if (raw == null) return [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return [];
      final list = decoded['criteria'];
      if (list is! List) return [];
      return list
          .map((e) => EvaluationCriterionRow.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static double _toScore(dynamic v) => (v as num?)?.toDouble() ?? 0;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  double get overallScore15 {
    if (criteria.isNotEmpty) {
      return criteria.map((c) => c.score).reduce((a, b) => a + b) / criteria.length;
    }
    return overallScore * 5;
  }

  int get overallPercent => (overallScore * 100).round().clamp(0, 100);

  QualityStatus get qualityStatus {
    if (qualityLevel != null) {
      return switch (qualityLevel!.toLowerCase()) {
        'excellent' => QualityStatus.excellent,
        'good' => QualityStatus.good,
        'fair' => QualityStatus.fair,
        _ => QualityStatus.needsImprovement,
      };
    }
    return qualityStatusForScore(overallScore);
  }

  AiResultLabel get aiLabel => aiLabelForResult(aiResult);

  MediaEvaluationRow copyWith({String? adminRemarks}) => MediaEvaluationRow(
        id: id,
        mediaId: mediaId,
        mediaName: mediaName,
        memberName: memberName,
        fileUrl: fileUrl,
        sharpnessScore: sharpnessScore,
        brightnessScore: brightnessScore,
        contrastScore: contrastScore,
        overallScore: overallScore,
        aiResult: aiResult,
        adminRemarks: adminRemarks ?? this.adminRemarks,
        evaluatedAt: evaluatedAt,
        qualityLevel: qualityLevel,
        recommendation: recommendation,
        criteria: criteria,
        isStandalone: isStandalone,
        sourceLabel: sourceLabel,
      );
}

class EvaluationCriterionRow {
  EvaluationCriterionRow({
    required this.name,
    required this.score,
    required this.label,
    required this.explanation,
  });

  final String name;
  final int score;
  final String label;
  final String explanation;

  factory EvaluationCriterionRow.fromMap(Map<String, dynamic> m) => EvaluationCriterionRow(
        name: m['name'] as String? ?? '',
        score: (m['score'] as num?)?.round() ?? 3,
        label: m['label'] as String? ?? 'Fair',
        explanation: m['explanation'] as String? ?? '',
      );
}

enum QualityStatus { excellent, good, fair, needsImprovement }

enum AiResultLabel { human, aiGenerated, suspicious, pending }

QualityStatus qualityStatusForScore(double score) {
  final pct = score * 100;
  if (pct >= 80) return QualityStatus.excellent;
  if (pct >= 60) return QualityStatus.good;
  if (pct >= 40) return QualityStatus.fair;
  return QualityStatus.needsImprovement;
}

AiResultLabel aiLabelForResult(String? raw) {
  if (raw == null || raw.isEmpty) return AiResultLabel.pending;
  final n = raw.toLowerCase().replaceAll(' ', '_');
  if (n.contains('ai') || n.contains('generated')) return AiResultLabel.aiGenerated;
  if (n.contains('suspicious')) return AiResultLabel.suspicious;
  if (n.contains('human') || n.contains('authentic')) return AiResultLabel.human;
  return AiResultLabel.pending;
}

String scoreToPercent(double score) => '${(score * 100).round()}%';

String formatEvaluatedDate(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final y = local.year;
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}

class MediaEvaluationSummary {
  const MediaEvaluationSummary({
    required this.totalEvaluated,
    required this.averageOverallScore,
    required this.humanMediaCount,
    required this.aiSuspiciousCount,
  });

  final int totalEvaluated;
  final double averageOverallScore;
  final int humanMediaCount;
  final int aiSuspiciousCount;

  factory MediaEvaluationSummary.fromMap(Map<String, dynamic> m) => MediaEvaluationSummary(
        totalEvaluated: m['total_evaluated'] as int? ?? 0,
        averageOverallScore: (m['average_overall_score'] as num?)?.toDouble() ?? 0,
        humanMediaCount: m['human_media_count'] as int? ?? 0,
        aiSuspiciousCount: m['ai_suspicious_count'] as int? ?? 0,
      );

  String get averagePercent => '${(averageOverallScore * 100).round()}%';
}
