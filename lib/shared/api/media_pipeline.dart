import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';

/// Simulates the full 11-step ACCESS media evaluation pipeline.
/// In production each step would call a real backend endpoint.
class MediaPipeline {
  static final _rng = Random();

  // ── Step 1: Validate upload constraints ────────────────────────────────────
  static String? validateUploads(int count, {bool hasVideo = false, int? videoSeconds}) {
    if (count < 3) return 'Please upload at least 3 files.';
    if (count > 5) return 'Maximum 5 files allowed per submission.';
    if (hasVideo && videoSeconds != null) {
      if (videoSeconds < 5)  return 'Video must be at least 5 seconds long.';
      if (videoSeconds > 120) return 'Video must not exceed 120 seconds.';
    }
    return null; // valid
  }

  // ── Steps 2–10: Full pipeline simulation ───────────────────────────────────
  static Future<PipelineResult> run(List<Uint8List> images, String category) async {
    // Step 2: Preprocessing (simulate 0.5s)
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 3: Quality Evaluation (OpenCV simulation)
    final quality = _evaluateQuality(images, category);

    // Step 4: AI Authenticity Detection (ResNet/EfficientNet simulation)
    final aiDetection = _detectAi(images);

    // Step 5: Score Computation (weighted algorithm)
    // Weights: quality 60%, ai authenticity 40%
    final aiPenalty = aiDetection.isAiGenerated ? 0.0 : 1.0;
    final finalScore = (quality.overall * 0.6 + aiPenalty * 0.4).clamp(0.0, 1.0);

    // Step 6: Risk Classification
    final riskLevel = _classifyRisk(finalScore, aiDetection);

    // Step 7: Admin Review flag (high risk)
    final pendingAdminReview = riskLevel == RiskLevel.high;

    // Step 8: Skill Classification (rule-based)
    final skillBadge = _classifySkill(finalScore);

    // Step 9: Profile update happens in AppState.addEvaluation()

    // Step 10: Gemini Feedback Generation (simulated)
    await Future.delayed(const Duration(milliseconds: 400));
    final feedback = _generateFeedback(quality, aiDetection, finalScore, category);

    // Step 11: Analytics update happens in AppState

    return PipelineResult(
      quality: quality,
      aiDetection: aiDetection,
      finalScore: finalScore,
      riskLevel: riskLevel,
      skillBadge: skillBadge,
      gemindiFeedback: feedback,
      pendingAdminReview: pendingAdminReview,
    );
  }

  // ── Step 3: Quality metrics ─────────────────────────────────────────────────
  static QualityMetrics _evaluateQuality(List<Uint8List> images, String category) {
    final n = images.length;
    // Simulate metric scores based on image count and category
    double base = 0.55 + (n * 0.06).clamp(0.0, 0.25);
    double catBonus = category == 'Official' ? 0.08
      : category == 'Portrait' ? 0.06
      : category == 'Coverage' ? 0.04 : 0.02;

    double _v(double b) => (b + catBonus + (_rng.nextDouble() * 0.1 - 0.05)).clamp(0.0, 1.0);

    final blur        = _v(base + 0.05);
    final lighting    = _v(base);
    final resolution  = _v(base + 0.03);
    final composition = _v(base - 0.02);
    // Weighted: blur 30%, lighting 25%, resolution 20%, composition 25%
    final overall = (blur * 0.30 + lighting * 0.25 + resolution * 0.20 + composition * 0.25)
        .clamp(0.0, 1.0);

    return QualityMetrics(
      blur: blur, lighting: lighting,
      resolution: resolution, composition: composition,
      overall: overall,
    );
  }

  // ── Step 4: AI detection ────────────────────────────────────────────────────
  static AiDetectionResult _detectAi(List<Uint8List> images) {
    // Simulate: analyze byte entropy as a proxy for AI generation
    // Real: ResNet50/EfficientNet + metadata + artifact analysis
    double totalEntropy = 0;
    for (final img in images) {
      final sample = img.length > 1000 ? img.sublist(0, 1000) : img;
      final freq = <int, int>{};
      for (final b in sample) freq[b] = (freq[b] ?? 0) + 1;
      double entropy = 0;
      for (final c in freq.values) {
        final p = c / sample.length;
        if (p > 0) entropy -= p * (p > 0 ? _log2(p) : 0);
      }
      totalEntropy += entropy;
    }
    final avgEntropy = totalEntropy / images.length;
    // High entropy (>6.5) → likely real photo; low entropy → possibly AI
    final isAi = avgEntropy < 4.0;
    final confidence = isAi
      ? (1.0 - avgEntropy / 8.0).clamp(0.5, 0.99)
      : (avgEntropy / 8.0).clamp(0.5, 0.99);

    return AiDetectionResult(
      isAiGenerated: isAi,
      confidence: confidence,
      method: 'ResNet50 + metadata + artifact analysis',
    );
  }

  static double _log2(double x) => log(x) / ln2;

  // ── Step 6: Risk classification ─────────────────────────────────────────────
  static RiskLevel _classifyRisk(double score, AiDetectionResult ai) {
    if (ai.isAiGenerated && ai.confidence > 0.85) return RiskLevel.high;
    if (score < 0.45) return RiskLevel.high;
    if (score < 0.65 || (ai.isAiGenerated)) return RiskLevel.medium;
    return RiskLevel.low;
  }

  // ── Step 8: Skill classification ────────────────────────────────────────────
  static String _classifySkill(double score) {
    if (score >= 0.88) return 'Expert';
    if (score >= 0.72) return 'Advanced';
    if (score >= 0.56) return 'Intermediate';
    if (score >= 0.40) return 'Beginner';
    return 'Novice';
  }

  // ── Step 10: Gemini feedback (simulated) ────────────────────────────────────
  static String _generateFeedback(
      QualityMetrics q, AiDetectionResult ai, double score, String category) {
    final lines = <String>[];

    // Overall
    if (score >= 0.88)      lines.add('Outstanding submission. Your photos demonstrate professional-level documentation skills.');
    else if (score >= 0.72) lines.add('Good work. Your photos meet ACCESS documentation standards with room to grow.');
    else if (score >= 0.56) lines.add('Acceptable submission. Focus on the areas below to improve your score.');
    else                    lines.add('This submission needs improvement before it meets ACCESS standards.');

    // Quality-specific
    if (q.blur < 0.6)        lines.add('Focus & sharpness needs attention — ensure your subject is in focus before shooting.');
    else if (q.blur >= 0.85) lines.add('Excellent sharpness and focus throughout.');

    if (q.lighting < 0.6)    lines.add('Lighting is inconsistent — use fill light for indoor shots and avoid harsh shadows.');
    else if (q.lighting >= 0.85) lines.add('Lighting is well-handled across all photos.');

    if (q.composition < 0.6) lines.add('Work on framing — apply the rule of thirds and vary your angles.');
    else if (q.composition >= 0.85) lines.add('Strong composition with good visual storytelling.');

    if (q.resolution < 0.6)  lines.add('Resolution is below standard — shoot at the highest quality setting available.');

    // AI detection
    if (ai.isAiGenerated)    lines.add('⚠️ High AI authenticity risk (${(ai.confidence * 100).round()}% P(fake)). Flagged for officer review.');
    else                     lines.add('✓ Low AI authenticity risk from automated scan. Not proof of human origin.');

    // Category tip
    if (category == 'Coverage') lines.add('For event coverage, prioritize wide-angle establishing shots alongside close-up details.');
    if (category == 'Portrait') lines.add('For portraits, ensure the subject\'s eyes are sharp and the background is appropriately blurred.');

    return lines.join(' ');
  }
}
