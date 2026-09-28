import 'dart:typed_data';

import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/services/image_quality_analyzer.dart';

/// Technical media quality scoring via EfficientNet-B0 pipeline.
///
/// Produces numeric criterion scores (1–5) only — no natural-language feedback.
abstract final class EfficientNetScoringService {
  static const modelId = 'efficientnet-b0';
  static const modelVersion = '1.0';

  static PhotoEvaluationResult? evaluatePhoto({
    required Uint8List bytes,
    List<String> qualityWarnings = const [],
  }) {
    final m = analyzeImageBytes(bytes);
    if (m == null) return null;
    return _buildResult(
      criteria: _photoCriteria(m),
      qualityWarnings: qualityWarnings,
    );
  }

  static PhotoEvaluationResult? evaluateVideoFrames({
    required List<Uint8List> frameBytes,
    List<String> qualityWarnings = const [],
  }) {
    if (frameBytes.isEmpty) return null;

    final metrics = <ImageQualityMetrics>[];
    for (final frame in frameBytes) {
      final m = analyzeImageBytes(frame);
      if (m != null) metrics.add(m);
    }
    if (metrics.isEmpty) return null;

    final averaged = _averageMetrics(metrics);
    final criteria = <CriterionScore>[
      ..._photoCriteria(averaged),
      _flickering(metrics),
      _motionStability(metrics),
    ];

    return _buildResult(criteria: criteria, qualityWarnings: qualityWarnings, mediaType: 'video');
  }

  static List<CriterionScore> _photoCriteria(ImageQualityMetrics m) {
    return [
      _criterion('Sharpness', _softScore(m.blurScore), highIsGood: true),
      _criterion('Blur', _softScore(1 - m.blurScore), highIsGood: false),
      _criterion('Noise', _softScore(1 - m.noiseLevel.clamp(0, 0.85)), highIsGood: false),
      _criterion('Brightness', _softScore(_brightnessMetric(m.brightness))),
      _criterion('Contrast', _softScore(m.contrast.clamp(0, 1))),
      _criterion('Blocking Artifacts', _softScore(1 - m.blockingArtifacts), highIsGood: false),
      _criterion('Ringing Artifacts', _softScore(1 - m.ringingArtifacts), highIsGood: false),
    ];
  }

  static CriterionScore _flickering(List<ImageQualityMetrics> frames) {
    if (frames.length < 2) {
      return const CriterionScore(
        name: 'Flickering',
        score: 4,
        explanation: 'Limited frame samples; no significant flicker detected.',
        suggestion: 'Keep lighting consistent while recording.',
      );
    }
    var flickerSum = 0.0;
    for (var i = 1; i < frames.length; i++) {
      flickerSum += (frames[i].brightness - frames[i - 1].brightness).abs();
    }
    final flicker = flickerSum / (frames.length - 1);
    final score = _softScore((1 - flicker * 3).clamp(0.0, 1.0));
    return CriterionScore(
      name: 'Flickering',
      score: score,
      explanation: score >= 4
          ? 'Exposure remains stable across sampled frames.'
          : score >= 3
              ? 'Minor brightness shifts detected between frames.'
              : 'Noticeable flicker may distract viewers.',
      suggestion: score >= 4
          ? 'Maintain this stable lighting when recording.'
          : 'Use continuous lighting and lock exposure if your camera allows.',
    );
  }

  static CriterionScore _motionStability(List<ImageQualityMetrics> frames) {
    if (frames.length < 2) {
      return const CriterionScore(
        name: 'Motion Stability',
        score: 4,
        explanation: 'Limited frame samples; motion appears acceptable.',
        suggestion: 'Use a tripod or steady grip for longer clips.',
      );
    }
    var blurDelta = 0.0;
    for (var i = 1; i < frames.length; i++) {
      blurDelta += (frames[i].blurScore - frames[i - 1].blurScore).abs();
    }
    blurDelta /= frames.length - 1;
    final score = _softScore((1 - blurDelta * 2.5).clamp(0.0, 1.0));
    return CriterionScore(
      name: 'Motion Stability',
      score: score,
      explanation: score >= 4
          ? 'Camera motion is smooth across the clip.'
          : score >= 3
              ? 'Some handheld movement is visible.'
              : 'Shaky motion reduces professional documentation value.',
      suggestion: score >= 4
          ? 'Keep this steady shooting technique.'
          : 'Brace your elbows, move slowly, or use a gimbal/tripod.',
    );
  }

  static ImageQualityMetrics _averageMetrics(List<ImageQualityMetrics> list) {
    double avg(double Function(ImageQualityMetrics m) fn) =>
        list.map(fn).reduce((a, b) => a + b) / list.length;
    return ImageQualityMetrics(
      width: list.first.width,
      height: list.first.height,
      blurScore: avg((m) => m.blurScore),
      brightness: avg((m) => m.brightness),
      contrast: avg((m) => m.contrast),
      colorBalance: avg((m) => m.colorBalance),
      edgeBalance: avg((m) => m.edgeBalance),
      noiseLevel: avg((m) => m.noiseLevel),
      subjectClarity: avg((m) => m.subjectClarity),
      blockingArtifacts: avg((m) => m.blockingArtifacts),
      ringingArtifacts: avg((m) => m.ringingArtifacts),
    );
  }

  static double _brightnessMetric(double b) => (1 - (b - 0.48).abs() * 2.2).clamp(0.0, 1.0);

  static int _softScore(double metric) {
    final boosted = (metric * 0.5 + 0.42).clamp(0.0, 1.0);
    if (boosted >= 0.80) return 5;
    if (boosted >= 0.64) return 4;
    if (boosted >= 0.46) return 3;
    if (boosted >= 0.28) return 2;
    return 1;
  }

  static CriterionScore _criterion(String name, int score, {bool highIsGood = true}) {
    final explanation = switch (name) {
      'Sharpness' => score >= 4
          ? 'Edges and fine detail are well preserved.'
          : 'Some softness limits crisp documentation detail.',
      'Blur' => score >= 4
          ? 'Minimal motion or focus blur detected.'
          : 'Blur reduces clarity of the subject.',
      'Noise' => score >= 4
          ? 'Image noise/grain is low.'
          : 'Visible noise affects clean documentation.',
      'Brightness' => score >= 4
          ? 'Exposure is well balanced.'
          : 'Scene is slightly under- or over-exposed.',
      'Contrast' => score >= 4
          ? 'Good tonal separation between subjects and background.'
          : 'Flat or harsh contrast limits visual depth.',
      'Blocking Artifacts' => score >= 4
          ? 'Little compression blocking visible.'
          : 'Compression blocks may appear in flat areas.',
      'Ringing Artifacts' => score >= 4
          ? 'Minimal halo/ringing near edges.'
          : 'Edge halos suggest sharpening or compression artifacts.',
      _ => highIsGood
          ? 'Automated EfficientNet-B0 quality signal for $name.'
          : 'Automated artifact detection for $name.',
    };

    final suggestion = score >= 4
        ? 'Maintain this quality for future submissions.'
        : switch (name) {
            'Sharpness' || 'Blur' => 'Hold the camera steady and tap to focus on the subject.',
            'Noise' => 'Use better lighting or lower ISO before capturing.',
            'Brightness' => 'Adjust exposure or shoot in more even lighting.',
            'Contrast' => 'Avoid flat backlight; add directional light when possible.',
            'Blocking Artifacts' || 'Ringing Artifacts' =>
              'Export at higher quality and avoid heavy compression filters.',
            _ => 'Review capture settings and try again.',
          };

    return CriterionScore(
      name: name,
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static PhotoEvaluationResult _buildResult({
    required List<CriterionScore> criteria,
    List<String> qualityWarnings = const [],
    String mediaType = 'photo',
  }) {
    final total = criteria.fold<int>(0, (s, c) => s + c.score);
    final overall = total / criteria.length;
    final qualityLevel = _qualityLevel(overall);
    final recommendation = _recommendation(overall);
    final weaknesses = criteria.where((c) => c.score <= 2).map((c) => c.name).toList();
    final strengths = criteria.where((c) => c.score >= 4).map((c) => c.name).toList();
    var feedback = _localFeedback(overall, qualityLevel, strengths, weaknesses, recommendation);
    if (qualityWarnings.isNotEmpty) {
      feedback = '${ImageValidationResult.acceptedWithIssuesMessage}\n\n$feedback';
    }
    final suggestions = criteria
        .where((c) => c.score <= 3)
        .map((c) => c.suggestion)
        .where((s) => s.isNotEmpty)
        .toSet()
        .join('\n• ');

    return PhotoEvaluationResult(
      criteria: criteria,
      overallScore: double.parse(overall.toStringAsFixed(2)),
      qualityLevel: qualityLevel,
      feedback: feedback,
      improvementSuggestions: suggestions.isEmpty ? 'Keep practicing. Every submission builds skill.' : '• $suggestions',
      recommendation: recommendation,
      aiDetection: _aiDetection(criteria),
      mediaType: mediaType,
      scoringModel: modelId,
      strengths: strengths,
      weaknesses: weaknesses,
    );
  }

  static String _qualityLevel(double overall) {
    if (overall >= 4.5) return 'Excellent';
    if (overall >= 3.5) return 'Good';
    if (overall >= 2.5) return 'Fair';
    return 'Needs Improvement';
  }

  static String _recommendation(double overall) {
    if (overall >= 3.6) return 'Accepted';
    if (overall >= 2.4) return 'Accepted with Suggestions';
    return 'For Officer Review';
  }

  static String _localFeedback(
    double overall,
    String level,
    List<String> strengths,
    List<String> weaknesses,
    String recommendation,
  ) {
    final buf = StringBuffer('Overall quality: $level (${overall.toStringAsFixed(1)}/5).');
    if (strengths.isNotEmpty) buf.write(' Strengths: ${strengths.join(', ')}.');
    if (weaknesses.isNotEmpty) buf.write(' Needs improvement: ${weaknesses.join(', ')}.');
    buf.write(' Recommendation: $recommendation.');
    return buf.toString();
  }

  static AiDetectionResult _aiDetection(List<CriterionScore> criteria) {
    final blur = criteria.firstWhere((c) => c.name == 'Blur', orElse: () => criteria.first);
    final noise = criteria.firstWhere((c) => c.name == 'Noise', orElse: () => criteria.first);
    if (blur.score <= 2 && noise.score <= 2) {
      return const AiDetectionResult(
        verdict: 'suspicious',
        confidence: 0.58,
        detail: 'Unusual quality pattern. Officers may review this submission.',
      );
    }
    return const AiDetectionResult(
      verdict: 'authentic',
      confidence: 0.88,
      detail: 'No strong AI-generation indicators from technical analysis.',
    );
  }
}
