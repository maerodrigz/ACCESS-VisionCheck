import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// UI-only labels for feedback-only supplementary insights (not rubric criteria).
enum SupplementaryInsightKind {
  colorBalance,
  compositionFraming,
  cameraMovement,
}

String supplementaryInsightDisplayTitle(SupplementaryInsightKind kind) {
  switch (kind) {
    case SupplementaryInsightKind.colorBalance:
      return 'Color Balance';
    case SupplementaryInsightKind.compositionFraming:
      return 'Composition / Framing';
    case SupplementaryInsightKind.cameraMovement:
      return 'Camera Movement Insights';
  }
}

/// Short member-facing line for collapsed report/result screens (API feedback unchanged).
String supplementaryInsightConciseLine(
  SupplementaryQualityInsight insight, {
  required SupplementaryInsightKind kind,
}) {
  final status = insight.status.trim().toLowerCase();
  final headline = insight.headline.trim();

  switch (kind) {
    case SupplementaryInsightKind.colorBalance:
      switch (status) {
        case 'warm_cast':
          return 'Warm color tint detected. Adjust white balance if you want neutral colors.';
        case 'cool_cast':
          return 'Cool color tint detected. Adjust white balance if you want neutral colors.';
        case 'neutral':
          return headline.isNotEmpty
              ? '$headline. Reasonable balance for this scene.'
              : 'Colors look reasonably balanced for this scene.';
        case 'inconclusive':
          return 'Color coaching inconclusive for this lighting or exposure.';
        default:
          break;
      }
    case SupplementaryInsightKind.compositionFraming:
      switch (status) {
        case 'edge_proximity':
          return 'Important content may be close to the frame edge. Consider reframing.';
        case 'acceptable':
          return headline.isNotEmpty
              ? '$headline. Lightweight framing check only.'
              : 'Framing looks acceptable for documentation.';
        case 'inconclusive':
          return 'Framing coaching inconclusive for this clip.';
        default:
          break;
      }
    case SupplementaryInsightKind.cameraMovement:
      switch (status) {
        case 'stable_smooth':
          return 'Sampled frames suggest steady camera movement.';
        case 'possible_shake':
          return 'Possible handshake detected. Slow down or brace the camera.';
        case 'inconclusive':
          return 'Movement coaching inconclusive (subject or scene motion).';
        default:
          break;
      }
  }

  return _firstSentenceOrTrim(insight.feedback, maxLen: 140);
}

String _firstSentenceOrTrim(String raw, {required int maxLen}) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final match = RegExp(r'^(.+?[.!?])(\s|$)').firstMatch(text);
  if (match != null) {
    final sentence = match.group(1)!.trim();
    if (sentence.length <= maxLen) return sentence;
  }
  if (text.length <= maxLen) return text;
  final cut = text.substring(0, maxLen);
  final lastSpace = cut.lastIndexOf(' ');
  if (lastSpace > 40) return '${cut.substring(0, lastSpace).trim()}…';
  return '$cut…';
}

int supplementaryInsightVisibleCount(AdditionalQualityInsights insights) {
  var n = 0;
  if (_insightVisible(insights.colorBalance)) n++;
  if (_insightVisible(insights.compositionFraming)) n++;
  if (_insightVisible(insights.motionStability)) n++;
  return n;
}

bool _insightVisible(SupplementaryQualityInsight? insight) =>
    insight != null && !insight.isUnavailable && insight.feedback.trim().isNotEmpty;
