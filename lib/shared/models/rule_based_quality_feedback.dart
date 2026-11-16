/// Deterministic, metric-grounded photo quality feedback (Gemini-independent).
/// Mirrors `access_backend/app/services/rule_based_quality_feedback.py`.
///
/// Kept free of imports from [photo_evaluation_result.dart] to avoid circular deps.
class RuleBasedQualityInput {
  const RuleBasedQualityInput({
    required this.name,
    required this.score,
    this.available = true,
    this.explanation = '',
    this.suggestion = '',
  });

  final String name;
  final int score;
  final bool available;
  final String explanation;
  final String suggestion;
}

class RuleBasedQualityOutput {
  const RuleBasedQualityOutput({
    required this.explanation,
    required this.strengths,
    required this.improvements,
    required this.tips,
    required this.closingMessage,
    this.insufficientMetrics = false,
  });

  final String explanation;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> tips;
  final String closingMessage;
  final bool insufficientMetrics;
}

class RuleBasedQualityFeedback {
  RuleBasedQualityFeedback._();

  static const strengthMin = 4;
  static const weakMax = 2;
  static const fair = 3;
  static const maxStrengths = 3;
  static const maxImprovements = 3;
  static const maxTips = 3;

  /// Score-like fragments that must not appear in member-facing narrative text.
  static final RegExp narrativeMeasurementPattern = RegExp(
    r'\b\d+(?:\.\d+)?\s*/\s*(?:5|100)\b|\b\d+(?:\.\d+)?\s*%|\(\s*\d+(?:\.\d+)?\s*/\s*5\s*\)|\bscored\s+\d+(?:\.\d+)?\b|\baround\s+\d+(?:\.\d+)?\s*/\s*5\b',
    caseSensitive: false,
  );

  static bool narrativeContainsMeasurements(String text) =>
      narrativeMeasurementPattern.hasMatch(text);

  static String stripNarrativeMeasurements(String text) {
    var cleaned = text.replaceAll(narrativeMeasurementPattern, '');
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+([,.;:!?)])'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\(\s*\)'), '');
    return cleaned.replaceAll(RegExp(r'^[\s:;\-]+|[\s:;\-]+$'), '');
  }

  static RuleBasedQualityOutput sanitize(RuleBasedQualityOutput feedback) {
    return RuleBasedQualityOutput(
      explanation: stripNarrativeMeasurements(feedback.explanation),
      strengths: feedback.strengths.map(stripNarrativeMeasurements).where((s) => s.isNotEmpty).toList(),
      improvements:
          feedback.improvements.map(stripNarrativeMeasurements).where((s) => s.isNotEmpty).toList(),
      tips: feedback.tips.map(stripNarrativeMeasurements).where((s) => s.isNotEmpty).toList(),
      closingMessage: stripNarrativeMeasurements(feedback.closingMessage),
      insufficientMetrics: feedback.insufficientMetrics,
    );
  }

  static RuleBasedQualityOutput build({
    required List<RuleBasedQualityInput> criteria,
    required bool isVideo,
    required double overallScore,
    required String qualityLevel,
    String? memberFirstName,
    List<String> qualityWarnings = const [],
  }) {
    final mediaLabel = isVideo ? 'video' : 'photo';
    final namePrefix =
        (memberFirstName != null && memberFirstName.trim().isNotEmpty) ? '${memberFirstName.trim()}, ' : '';
    final warnings = [
      for (final w in qualityWarnings)
        if (w.trim().isNotEmpty) w.trim(),
    ];

    final rows = criteria
        .where((c) => c.available && c.score >= 1 && c.score <= 5)
        .map(
          (c) => _Row(
            name: c.name,
            score: c.score,
            explanation: c.explanation.trim(),
            suggestion: c.suggestion.trim(),
          ),
        )
        .toList();

    if (rows.length < 2) {
      return sanitize(
        RuleBasedQualityOutput(
          explanation:
              '${namePrefix}Thanks for sharing this $mediaLabel. Detailed quality feedback is limited because too few technical measures were available for this submission.',
          strengths: const [],
          improvements: const [
            'Detailed quality feedback is limited until more quality measures are available.',
          ],
          tips: const [
            'Try another clear, well-lit capture so more quality checks can run successfully.',
          ],
          closingMessage: 'Keep practicing and submit again when you can!',
          insufficientMetrics: true,
        ),
      );
    }

    final scores = {for (final r in rows) r.name: r.score};
    final byName = {for (final r in rows) r.name: r};
    final strongRows = [...rows.where((r) => r.score >= strengthMin)]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.name.compareTo(b.name);
      });
    final topStrong = strongRows.take(maxStrengths).toList();

    final themes = _prioritizedWeakNames(scores);
    final clarityCombined = themes.contains('Clarity');

    var strengths = topStrong.map(_strengthLine).toList();
    if (clarityCombined) {
      strengths = strengths
          .where((s) => !s.startsWith('Sharpness') && !s.startsWith('Blur'))
          .toList();
    }

    final improvements = <String>[];
    final tips = <String>[];
    for (final theme in themes) {
      if (theme == 'Clarity') {
        final worst = [
          scores['Sharpness'] ?? 5,
          scores['Blur'] ?? 5,
        ].reduce((a, b) => a < b ? a : b);
        improvements.add(_improvementLine('Sharpness', worst, clarityCombined: true));
        final tip = _tipFor('Sharpness', worst, null, warnings: warnings, clarityCombined: true);
        if (!tips.contains(tip)) tips.add(tip);
        continue;
      }
      final row = byName[theme];
      final score = scores[theme] ?? fair;
      improvements.add(_improvementLine(theme, score));
      final tip = _tipFor(theme, score, row, warnings: warnings);
      if (!tips.contains(tip)) tips.add(tip);
      if (tips.length >= maxTips) break;
    }

    final cappedTips = tips.take(maxTips).toList();
    final cappedImprovements = improvements.take(maxImprovements).toList();
    final allGood = rows.every((r) => r.score >= strengthMin);

    final level = qualityLevel.trim().isNotEmpty
        ? qualityLevel
        : (overallScore >= 4.5
            ? 'Excellent'
            : overallScore >= 3.5
                ? 'Good'
                : overallScore >= 2.5
                    ? 'Fair'
                    : 'Needs Improvement');

    late final String explanation;
    late final List<String> finalImprovements;
    late final List<String> finalTips;

    if (allGood) {
      final strengthNames = topStrong.map((r) => r.name.toLowerCase()).join(', ');
      explanation =
          '${namePrefix}Great work on this $mediaLabel! Your measured quality looks strong overall ($level), especially in ${strengthNames.isEmpty ? 'technical quality' : strengthNames}.';
      finalImprovements = const [];
      finalTips = const [
        'Keep using steady focus and even lighting on your next capture.',
        'When exporting, prefer higher quality settings to protect fine detail.',
      ];
    } else if (topStrong.isNotEmpty) {
      final strengthNames = topStrong.map((r) => r.name.toLowerCase()).join(', ');
      final focus = themes.isNotEmpty ? themes.first : 'a few technical details';
      final focusLabel = focus == 'Clarity' ? 'clarity' : focus.toLowerCase();
      explanation =
          '${namePrefix}Nice effort on this $mediaLabel! Overall quality looks ${level.toLowerCase()}. You are already doing well with $strengthNames. The most useful next step is improving $focusLabel.';
      finalImprovements = cappedImprovements;
      finalTips = cappedTips;
    } else {
      explanation =
          '${namePrefix}Thank you for sharing this $mediaLabel. Overall quality looks ${level.toLowerCase()}. There is clear potential here, and a few focused capture adjustments should make the next submission stronger.';
      finalImprovements = cappedImprovements;
      finalTips = cappedTips;
    }

    final finalStrengths = strengths.isNotEmpty || allGood
        ? strengths
        : [
            'You submitted the photo for evaluation, which is a solid step toward better documentation practice.',
          ];

    return sanitize(
      RuleBasedQualityOutput(
        explanation: explanation,
        strengths: finalStrengths,
        improvements: finalImprovements,
        tips: finalTips,
        closingMessage: 'Keep practicing and submitting. Consistency is how great documenters are made!',
      ),
    );
  }

  static List<String> _prioritizedWeakNames(Map<String, int> scores) {
    final weak = scores.entries.where((e) => e.value <= weakMax).toList()
      ..sort((a, b) {
        final byScore = a.value.compareTo(b.value);
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });

    if (weak.isEmpty) {
      final fairRows = scores.entries.where((e) => e.value == fair).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      return fairRows.take(2).map((e) => e.key).toList();
    }

    final sharp = scores['Sharpness'];
    final blur = scores['Blur'];
    final clarityIssue = sharp != null && blur != null && sharp <= weakMax && blur <= weakMax;

    final out = <String>[];
    if (clarityIssue) out.add('Clarity');
    for (final e in weak) {
      if (clarityIssue && (e.key == 'Sharpness' || e.key == 'Blur')) continue;
      if (!out.contains(e.key)) out.add(e.key);
      if (out.length >= maxImprovements) break;
    }
    return out.take(maxImprovements).toList();
  }

  static String _strengthLine(_Row row) {
    const canned = {
      'Sharpness': 'Fine detail and edges look crisp enough for clear documentation.',
      'Blur': 'Motion and focus blur look well controlled.',
      'Brightness': 'Exposure looks well balanced for readable detail.',
      'Contrast': 'Tonal separation helps subjects stand out clearly.',
      'Blocking Artifacts': 'Compression artifacts look minimal.',
      'Color Balance': 'White balance looks acceptable for documentation.',
      'Color Saturation': 'Color intensity looks suitable for documentation.',
    };
    final expl = row.explanation;
    if (expl.isNotEmpty && row.score >= 4 && expl.length < 160) {
      var cleaned = expl;
      if (cleaned.toLowerCase().contains('heuristic')) {
        cleaned = cleaned.split('(').first.trim();
      }
      cleaned = stripNarrativeMeasurements(cleaned);
      if (cleaned.isNotEmpty && !cleaned.toLowerCase().startsWith('efficientnet')) {
        return '${row.name}: $cleaned';
      }
    }
    final base = canned[row.name];
    if (base != null) return '${row.name}: $base';
    return '${row.name}: this quality aspect looks solid.';
  }

  static String _improvementLine(String name, int score, {bool clarityCombined = false}) {
    // score is used only for prioritization upstream; never shown to members.
    if (clarityCombined) {
      return 'Clarity: the photo looks softer than ideal for crisp documentation detail.';
    }
    switch (name) {
      case 'Sharpness':
        return 'Sharpness: fine detail looks softer than ideal.';
      case 'Blur':
        return 'Blur: blur is reducing subject clarity.';
      case 'Brightness':
        return 'Brightness: exposure looks uneven for documentation.';
      case 'Contrast':
        return 'Contrast: tonal separation looks weak or uneven.';
      case 'Blocking Artifacts':
        return 'Blocking Artifacts: compression blocks may be visible.';
      case 'Color Balance':
        return 'Color Balance: a color cast may affect natural appearance.';
      case 'Color Saturation':
        return 'Color Saturation: color intensity may need a conservative adjustment.';
      default:
        return '$name: this quality aspect needs improvement.';
    }
  }

  /// Matches Python `_brightness_direction`: warnings + explanation + suggestion.
  static String? _brightnessDirection(_Row? row, List<String> warnings) {
    final blob = [
      ...warnings,
      row?.explanation ?? '',
      row?.suggestion ?? '',
    ].join(' ').toLowerCase();
    const underKeys = ['underex', 'too dark', 'quite dark', 'under-expos', 'needs more light', 'increase exposure'];
    const overKeys = ['overexpos', 'too bright', 'washed out', 'over-expos', 'reduce exposure', 'highlights'];
    final under = underKeys.any(blob.contains);
    final over = overKeys.any(blob.contains);
    if (under && !over) return 'under';
    if (over && !under) return 'over';
    return null;
  }

  static String? _saturationDirection(_Row? row) {
    final blob = '${row?.explanation ?? ''} ${row?.suggestion ?? ''}'.toLowerCase();
    if (['oversatur', 'too intense', 'heavily oversaturated', 'quite high'].any(blob.contains)) {
      return 'over';
    }
    if (['muted', 'washed out', 'undersatur', 'too low', 'increase vibrance'].any(blob.contains)) {
      return 'under';
    }
    return null;
  }

  static String _tipFor(
    String name,
    int score,
    _Row? row, {
    List<String> warnings = const [],
    bool clarityCombined = false,
  }) {
    if (clarityCombined) {
      return 'Check focus on the main subject and keep the camera steady to reduce softness and blur in one step.';
    }
    switch (name) {
      case 'Sharpness':
        return 'Tap to focus on the main subject and keep the camera steady when capturing.';
      case 'Blur':
        return 'Reduce camera or subject movement; use a faster shutter or brace your stance.';
      case 'Brightness':
        final direction = _brightnessDirection(row, warnings);
        if (direction == 'under') {
          return 'Add light or raise exposure carefully so important details are easier to see.';
        }
        if (direction == 'over') {
          return 'Reduce intense light or lower exposure so highlights are less washed out.';
        }
        return 'Review lighting and exposure. Aim for even light so important details stay visible without guessing whether the frame is too dark or too bright.';
      case 'Contrast':
        return 'Improve tonal separation with gentle directional light when possible. Avoid assuming that more contrast is always better.';
      case 'Blocking Artifacts':
        return 'Avoid heavy compression and repeated low-quality exports. Save or share at a higher quality setting when you can.';
      case 'Color Balance':
        return 'Check lighting and white balance if natural colors are important. A mild cast can be intentional, so correct it only when true-to-life color is needed.';
      case 'Color Saturation':
        final direction = _saturationDirection(row);
        if (direction == 'over') {
          return 'Reduce saturation or vibrance slightly if natural documentation color is preferred.';
        }
        if (direction == 'under') {
          return 'Increase vibrance slightly only if the scene should look more vivid.';
        }
        return 'Adjust saturation conservatively. Do not push color intensity without checking how natural the subject looks.';
      default:
        if (row?.suggestion.isNotEmpty == true) return row!.suggestion;
        return 'Review capture settings related to ${name.toLowerCase()} and try another photo.';
    }
  }
}

class _Row {
  const _Row({
    required this.name,
    required this.score,
    required this.explanation,
    required this.suggestion,
  });

  final String name;
  final int score;
  final String explanation;
  final String suggestion;
}
