/// Overall quality labels for the displayed 0–100 score.
///
/// Criterion scores stay on the 1–5 scale. Poor 0–59, Fair 60–74,
/// Good 75–89, Excellent 90–100.
int overallPercentFromFivePoint(double overall) {
  return ((overall / 5) * 100).round().clamp(0, 100);
}

String overallQualityLabelFromPercent(int percent) {
  final value = percent.clamp(0, 100);
  if (value >= 90) return 'Excellent';
  if (value >= 75) return 'Good';
  if (value >= 60) return 'Fair';
  return 'Poor';
}

String overallQualityLabelFromFivePoint(double overall) {
  return overallQualityLabelFromPercent(overallPercentFromFivePoint(overall));
}

String overallQualityHeadline(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return 'Quality Result';
  return trimmed.toLowerCase().contains('quality') ? trimmed : '$trimmed Quality';
}

/// Rewrites only the overall-quality sentence so it matches [label].
/// Criterion sentences that mention fair, good, or poor are left unchanged.
String alignOverallQualityWording(String text, String label) {
  final word = label.trim();
  if (word.isEmpty || text.trim().isEmpty) return text;
  final lower = word.toLowerCase();
  final names = 'poor|fair|good|excellent|needs improvement';
  String swapLabel(Match match, String replacement) {
    final full = match.group(0)!;
    final old = match.group(1)!;
    final index = full.lastIndexOf(old);
    return full.replaceRange(index, index + old.length, replacement);
  }

  var aligned = text.replaceAllMapped(
    RegExp('overall quality looks ($names)', caseSensitive: false),
    (match) => swapLabel(match, lower),
  );
  aligned = aligned.replaceAllMapped(
    RegExp('overall documentation quality is ($names)', caseSensitive: false),
    (match) => swapLabel(match, word),
  );
  aligned = aligned.replaceAllMapped(
    RegExp('strong overall \\(($names)\\)', caseSensitive: false),
    (match) => swapLabel(match, word),
  );
  return aligned;
}
