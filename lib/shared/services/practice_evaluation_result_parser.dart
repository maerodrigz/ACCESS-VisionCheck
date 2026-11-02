import 'dart:convert';

import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// Builds [PhotoEvaluationResult] from GET /evaluations row (criteria_json payload).
PhotoEvaluationResult? photoEvaluationResultFromApiRow(Map<String, dynamic> row) {
  final criteriaRaw = row['criteria_json'];
  Map<String, dynamic>? payload;
  if (criteriaRaw is String && criteriaRaw.trim().isNotEmpty) {
    try {
      payload = Map<String, dynamic>.from(jsonDecode(criteriaRaw) as Map);
    } catch (_) {
      return null;
    }
  } else if (criteriaRaw is Map) {
    payload = Map<String, dynamic>.from(criteriaRaw);
  }
  if (payload == null) return null;

  final parsed = PhotoEvaluationResult.fromJson(payload);
  if (parsed == null) return null;
  return parsed;
}

/// True when GET /evaluations row is ready to show (scores or integrity payload).
bool practiceEvaluationApiRowReady(Map<String, dynamic> row) {
  if (photoEvaluationResultFromApiRow(row) != null) return true;
  final criteriaRaw = row['criteria_json'];
  if (criteriaRaw is String && criteriaRaw.trim().isNotEmpty) return true;
  if (criteriaRaw is Map && criteriaRaw.isNotEmpty) return true;
  final review = (row['review_status'] as String?)?.trim();
  if (review != null && review.isNotEmpty) return true;
  final feedback = (row['feedback'] as String?)?.trim();
  if (feedback != null && feedback.isNotEmpty) return true;
  final score = row['overall_score'];
  return score is num;
}

List<String> qualityWarningsFromEvaluationPayload(Map<String, dynamic> payload) {
  final raw = payload['quality_warnings'];
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
}

List<String> qualityWarningsFromCriteriaJson(String? criteriaRaw) {
  if (criteriaRaw == null || criteriaRaw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(criteriaRaw);
    if (decoded is! Map) return const [];
    return qualityWarningsFromEvaluationPayload(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return const [];
  }
}
