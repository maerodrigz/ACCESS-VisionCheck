/// Strip leftover technical disclaimers from stored criterion explanations.
///
/// Newer evaluations already emit clean copy. Historical rows may still contain
/// phrases like "Experimental heuristic". Scoring values are unchanged.
String sanitizeCriterionExplanation(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return text;

  const phrases = <String>[
    'Experimental heuristic based on sparse feature tracking between FFmpeg samples.',
    'Experimental heuristic; sparse sampling limits certainty.',
    'Experimental heuristic; not a full optical-stabilization analysis.',
    'Experimental heuristic; not a calibrated flicker meter.',
    'Experimental heuristic using OpenCV mean brightness on FFmpeg samples (not EfficientNet).',
    'Experimental heuristic.',
    'Heuristic estimate; not a validated aesthetic score.',
    'Heuristic estimate; artistic mute looks are not automatically wrong.',
    'Heuristic estimate.',
    '(Heuristic estimate; not a validated aesthetic score.)',
    '(Heuristic estimate; artistic mute looks are not automatically wrong.)',
    '(Heuristic estimate.)',
    'Sparse sampling limits certainty.',
    'Not a validated aesthetic score.',
  ];

  for (final phrase in phrases) {
    text = text.replaceAll(phrase, '');
  }

  text = text
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'\s+([.,;:])'), r'$1')
      .trim();
  while (text.endsWith('..')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
