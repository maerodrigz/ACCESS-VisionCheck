import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// Client-side mirror of `access_backend/app/services/integrity_evaluation_policy.py`.
class IntegrityEvaluationPolicy {
  const IntegrityEvaluationPolicy._();

  static const suspiciousMemberMessage =
      'This upload was flagged for integrity review. Technical scores below are provisional '
      'and may change after an officer verifies your media. XP will be awarded if your submission is approved.';

  static const aiGeneratedMemberMessage =
      'This upload was flagged as possible AI-generated content. Quality coaching is paused until '
      'an officer reviews your file. If verified as authentic, your scores and XP will be applied.';

  static String tierFromDetection(AiDetectionResult ai) {
    if (ai.isAiGenerated) return 'ai_generated';
    if (ai.isSuspicious) return 'suspicious';
    return 'authentic';
  }

  static PhotoEvaluationResult apply(PhotoEvaluationResult result) {
    final tier = tierFromDetection(result.aiDetection);
    final xpPreview = _xpPreview(result.overallScore);

    if (tier == 'authentic') {
      return result.copyWithIntegrity(
        integrityTier: tier,
        showQualityFeedback: true,
        qualityProvisional: false,
        xpEligible: true,
        xpMultiplier: 1.0,
        xpPointsPreview: xpPreview,
        xpPending: false,
      );
    }

    if (tier == 'suspicious') {
      final feedback = result.feedback.trim().isEmpty
          ? suspiciousMemberMessage
          : '$suspiciousMemberMessage\n\n${result.feedback}';
      return result.copyWithIntegrity(
        integrityTier: tier,
        showQualityFeedback: true,
        qualityProvisional: true,
        xpEligible: false,
        xpMultiplier: 0.0,
        xpPointsPreview: xpPreview,
        xpPending: true,
        memberIntegrityMessage: suspiciousMemberMessage,
        feedback: feedback,
      );
    }

    return result.copyWithIntegrity(
      integrityTier: tier,
      showQualityFeedback: false,
      qualityProvisional: false,
      xpEligible: false,
      xpMultiplier: 0.0,
      xpPointsPreview: xpPreview,
      xpPending: true,
      memberIntegrityMessage: aiGeneratedMemberMessage,
      feedback: aiGeneratedMemberMessage,
      improvementSuggestions: '',
    );
  }

  static int _xpPreview(double score) {
    final normalized = score <= 1.0 ? score : score / 5.0;
    return (normalized.clamp(0.0, 1.0) * 100).round();
  }
}
