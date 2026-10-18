import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// Gemini narrative generation via the ACCESS backend (no client API key).
class GeminiService {
  static Future<MediaEvaluationFeedback?> generateMediaEvaluationFeedback({
    required PhotoEvaluationResult scoresOnly,
  }) async {
    try {
      final raw = await memberApiService.fetchGeminiMediaFeedback(scoresOnly.toGeminiRequestJson());
      if (raw == null) return null;
      final feedback = MediaEvaluationFeedback.fromJson(raw);
      return feedback.copyWithEnergeticTone();
    } catch (_) {
      return null;
    }
  }

  /// Generates photography feedback based on rubric scores.
  /// Returns null if the backend is unavailable (falls back to local feedback).
  static Future<String?> generateFeedback({
    required Map<String, int> scores,
    required String title,
    required int totalScore,
    required int maxScore,
  }) async {
    try {
      return await memberApiService.fetchGeminiRubricFeedback(
        scores: scores,
        title: title,
        totalScore: totalScore,
        maxScore: maxScore,
      );
    } catch (_) {
      return null;
    }
  }

  /// Short operational summary for the admin home dashboard.
  static Future<String?> generateDailySummary({
    required int pendingRequests,
    required int todayEvents,
    required int mediaPending,
    required int unreadNotifications,
    required int pendingMembers,
  }) async {
    try {
      return await adminApi.fetchGeminiDailySummary(
        pendingRequests: pendingRequests,
        todayEvents: todayEvents,
        mediaPending: mediaPending,
        unreadNotifications: unreadNotifications,
        pendingMembers: pendingMembers,
      );
    } catch (_) {
      return null;
    }
  }
}
