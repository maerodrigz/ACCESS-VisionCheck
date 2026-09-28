import 'dart:typed_data';

import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/services/image_quality_analyzer.dart';

/// Deterministic photo evaluation for ACCESS documentation (1–5 per criterion).
class ImageEvaluationService {
  ImageEvaluationService._();

  static PhotoEvaluationResult? evaluate({
    required Uint8List bytes,
    String? eventTheme,
    List<String> qualityWarnings = const [],
  }) {
    final m = analyzeImageBytes(bytes);
    if (m == null) return null;

    final criteria = <CriterionScore>[
      _composition(m),
      _lighting(m),
      _focus(m),
      _color(m),
      _subjectClarity(m),
      _creativity(m),
      _relevance(m, eventTheme),
      _technical(m),
      _documentationValue(m),
    ];

    final total = criteria.fold<int>(0, (s, c) => s + c.score);
    final overall = total / criteria.length;
    final qualityLevel = _qualityLevel(overall);
    final recommendation = _recommendation(overall, m);
    var feedback = _buildFeedback(criteria, overall, qualityLevel, recommendation);
    if (qualityWarnings.isNotEmpty) {
      feedback =
          '${ImageValidationResult.acceptedWithIssuesMessage}\n\n$feedback';
    }
    final suggestions = criteria.map((c) => c.suggestion).where((s) => s.isNotEmpty).join('\n• ');
    final aiDetection = _aiDetection(m);

    return PhotoEvaluationResult(
      criteria: criteria,
      overallScore: double.parse(overall.toStringAsFixed(2)),
      qualityLevel: qualityLevel,
      feedback: feedback,
      improvementSuggestions: suggestions.isEmpty ? 'Keep practicing event documentation.' : '• $suggestions',
      recommendation: recommendation,
      aiDetection: aiDetection,
    );
  }

  /// Generous curve so typical school event photos score Fair–Good, not auto-reject.
  static int _softScore(double metric) {
    final boosted = (metric * 0.5 + 0.42).clamp(0.0, 1.0);
    if (boosted >= 0.80) return 5;
    if (boosted >= 0.64) return 4;
    if (boosted >= 0.46) return 3;
    if (boosted >= 0.28) return 2;
    return 1;
  }

  static CriterionScore _composition(ImageQualityMetrics m) {
    final score = _softScore(m.edgeBalance * 0.6 + m.resolutionScore * 0.4);
    final explanation = switch (score) {
      5 => 'The subject is well-framed with balanced spacing and clear visual hierarchy.',
      4 => 'Framing is solid; minor empty space or slight tilt does not hurt readability.',
      3 => 'The subject is visible, but the frame has too much empty space or uneven balance.',
      2 => 'Composition feels crowded or off-center, reducing documentation impact.',
      _ => 'Poor framing makes it hard to identify the event subject or context.',
    };
    final suggestion = score >= 4
        ? 'Maintain this framing for future event shots.'
        : 'Step closer or reframe so the main subject fills more of the frame.';
    return CriterionScore(
      name: 'Composition and Framing',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _lighting(ImageQualityMetrics m) {
    final ideal = 1 - (m.brightness - 0.48).abs() * 2.2;
    final exposurePenalty = m.noiseLevel > 0.15 ? 0.15 : 0;
    final metric = (ideal - exposurePenalty).clamp(0.0, 1.0);
    final score = _softScore(metric);
    final explanation = switch (score) {
      5 => 'Lighting is even and preserves detail in both subject and background.',
      4 => 'Exposure is good with only minor shadow or highlight loss.',
      3 => 'Lighting is slightly dim or bright, which reduces detail in parts of the scene.',
      2 => 'Uneven lighting hides important event details.',
      _ => 'The image is too dark or overexposed for reliable documentation.',
    };
    final suggestion = m.brightness < 0.35
        ? 'Shoot near a window or increase exposure before capturing.'
        : m.brightness > 0.75
            ? 'Avoid direct harsh light; slightly reduce exposure or change angle.'
            : 'Keep the current lighting approach for similar events.';
    return CriterionScore(
      name: 'Lighting and Exposure',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _focus(ImageQualityMetrics m) {
    final score = _softScore(m.blurScore);
    final explanation = switch (score) {
      5 => 'The image is sharp with crisp edges on the main subject.',
      4 => 'Focus is strong enough for documentation and social posting.',
      3 => 'Some softness is visible; the subject is still recognizable.',
      2 => 'Noticeable blur reduces professional documentation value.',
      _ => 'Heavy blur makes the photo unsuitable for official records.',
    };
    final suggestion = score >= 4
        ? 'Hold steady or use burst mode to keep this sharpness.'
        : 'Tap to focus on the subject and hold the phone still for a second before shooting.';
    return CriterionScore(
      name: 'Focus and Sharpness',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _color(ImageQualityMetrics m) {
    final score = _softScore(m.colorBalance * 0.7 + m.contrast * 0.3);
    final explanation = switch (score) {
      5 => 'Colors look natural with balanced white balance and good separation.',
      4 => 'Color rendering is pleasing with only minor cast or flat areas.',
      3 => 'Colors look natural, but shadows or casts affect clarity in some areas.',
      2 => 'Color imbalance or low contrast makes the scene feel dull.',
      _ => 'Strong color cast or clipping hurts documentation authenticity.',
    };
    final suggestion = score >= 4
        ? 'Continue shooting in similar lighting for consistent color.'
        : 'Avoid mixed tungsten/daylight; adjust white balance if your camera allows.';
    return CriterionScore(
      name: 'Color and White Balance',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _subjectClarity(ImageQualityMetrics m) {
    final score = _softScore(m.subjectClarity);
    final explanation = switch (score) {
      5 => 'The main subject is immediately clear and dominates the story.',
      4 => 'Subject identity and action are easy to follow at a glance.',
      3 => 'The subject is visible but competes with background clutter.',
      2 => 'It takes effort to identify who or what the photo documents.',
      _ => 'The subject is unclear or lost in the scene.',
    };
    final suggestion = score >= 4
        ? 'Document key moments the same way for officer review.'
        : 'Move closer or wait for a clearer moment when the subject is isolated.';
    return CriterionScore(
      name: 'Subject Clarity',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _creativity(ImageQualityMetrics m) {
    final creative = (m.contrast * 0.4 + m.edgeBalance * 0.35 + m.subjectClarity * 0.25)
        .clamp(0.0, 1.0);
    final score = _softScore(creative);
    final explanation = switch (score) {
      5 => 'The angle and moment tell a compelling event story.',
      4 => 'Good timing and perspective add interest beyond a snapshot.',
      3 => 'The photo documents the event but lacks a distinctive storytelling angle.',
      2 => 'Feels like a casual snapshot with limited narrative impact.',
      _ => 'Little visual interest or context for the event story.',
    };
    final suggestion = score >= 4
        ? 'Capture alternate angles (wide + detail) for richer event albums.'
        : 'Try a lower or higher angle, or shoot during peak action.';
    return CriterionScore(
      name: 'Creativity and Storytelling',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _relevance(ImageQualityMetrics m, String? theme) {
    final base = m.resolutionScore * 0.35 + m.subjectClarity * 0.45 + m.brightness * 0.2;
    final score = _softScore(base.clamp(0.0, 1.0));
    final themeNote = (theme != null && theme.trim().isNotEmpty)
        ? ' Event context: "${theme.trim()}".'
        : '';
    final explanation = switch (score) {
      5 => 'Strong fit as official ACCESS event documentation.$themeNote',
      4 => 'Clearly supports event reporting with identifiable context.$themeNote',
      3 => 'Usable for documentation but context could be stronger.$themeNote',
      2 => 'Weak event context; harder to tie to ACCESS reporting.$themeNote',
      _ => 'Does not clearly document an ACCESS event moment.$themeNote',
    };
    final suggestion = score >= 4
        ? 'Include signage, uniforms, or venue cues when possible.'
        : 'Capture wider shots that show the event name, venue, or activity type.';
    return CriterionScore(
      name: 'Relevance to Event Theme',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _technical(ImageQualityMetrics m) {
    final noisePenalty = m.noiseLevel > 0.2 ? 0.2 : 0;
    final metric = (m.blurScore * 0.35 +
            m.resolutionScore * 0.35 +
            m.contrast * 0.2 +
            m.colorBalance * 0.1 -
            noisePenalty)
        .clamp(0.0, 1.0);
    final score = _softScore(metric);
    final explanation = switch (score) {
      5 => 'Technical quality meets professional student-media standards.',
      4 => 'Minor noise or compression; still excellent for archives.',
      3 => 'Acceptable technical quality with some grain or softness.',
      2 => 'Technical issues (noise, resolution, or compression) limit reuse.',
      _ => 'Technical flaws significantly reduce documentation usability.',
    };
    final suggestion = score >= 4
        ? 'Export at high quality when submitting to ACCESS.'
        : 'Use the highest resolution setting and avoid heavy filters.';
    return CriterionScore(
      name: 'Technical Quality',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static CriterionScore _documentationValue(ImageQualityMetrics m) {
    final metric = (m.blurScore * 0.25 +
            m.brightness.clamp(0.25, 0.75) * 0.2 +
            m.subjectClarity * 0.3 +
            m.resolutionScore * 0.25)
        .clamp(0.0, 1.0);
    final score = _softScore(metric);
    final explanation = switch (score) {
      5 => 'Highly suitable for ACCESS archives, reports, and officer approval.',
      4 => 'Good documentation value with minor polish opportunities.',
      3 => 'Fair for internal use; may need improvement before public release.',
      2 => 'Still usable for documentation, but retaking would improve officer review.',
      _ => 'Very low quality, but still evaluated. Officers will review carefully.',
    };
    final suggestion = score >= 4
        ? 'Submit this style of photo for similar future events.'
        : 'Re-shoot with better light, focus, and framing before final submission.';
    return CriterionScore(
      name: 'Overall Documentation Value',
      score: score,
      explanation: explanation,
      suggestion: suggestion,
    );
  }

  static String _qualityLevel(double overall) {
    if (overall >= 4.5) return 'Excellent';
    if (overall >= 3.5) return 'Good';
    if (overall >= 2.5) return 'Fair';
    return 'Needs Improvement';
  }

  static String _recommendation(double overall, ImageQualityMetrics m) {
    if (overall >= 3.6) return 'Accepted';
    if (overall >= 2.4) return 'Accepted with Suggestions';
    return 'For Officer Review';
  }

  static String _buildFeedback(
    List<CriterionScore> criteria,
    double overall,
    String qualityLevel,
    String recommendation,
  ) {
    final strengths = criteria.where((c) => c.score >= 4).map((c) => c.name).toList();
    final weaknesses = criteria.where((c) => c.score <= 2).map((c) => c.name).toList();
    final buf = StringBuffer()
      ..writeln(
        'Overall documentation quality is $qualityLevel (${overall.toStringAsFixed(1)}/5).',
      );
    if (strengths.isNotEmpty) {
      buf.writeln('Strengths: ${strengths.join(', ')}.');
    }
    if (weaknesses.isNotEmpty) {
      buf.writeln('Areas to improve: ${weaknesses.join(', ')}.');
    }
    buf.writeln('Final recommendation: $recommendation.');
    return buf.toString().trim();
  }

  static AiDetectionResult _aiDetection(ImageQualityMetrics m) {
    final suspicion = (m.noiseLevel > 0.35 && m.blurScore < 0.35) ||
        (m.contrast < 0.08 && m.colorBalance > 0.95);
    if (suspicion) {
      return const AiDetectionResult(
        verdict: 'suspicious',
        confidence: 0.62,
        detail:
            'Suspicious indicators detected. Officers will review this submission carefully.',
      );
    }
    return AiDetectionResult(
      verdict: 'authentic',
      confidence: (0.75 + m.blurScore * 0.15 + m.contrast * 0.1).clamp(0.7, 0.98),
      detail: 'No strong AI-generation artifacts detected from image statistics.',
    );
  }
}
