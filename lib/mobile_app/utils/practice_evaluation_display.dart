import 'package:access_mobile/shared/controllers/app_state.dart';

/// Merges completed evaluations with in-progress practice uploads (no score yet).
List<Evaluation> practiceEvaluationsForDisplay({
  required List<Evaluation> evaluations,
  required List<GalleryItem> practiceMedia,
}) {
  if (practiceMedia.isEmpty) return evaluations;

  final byId = {for (final e in evaluations) e.id: e};
  final merged = [...evaluations];

  for (final item in practiceMedia) {
    if (item.processingStatus != 'processing') continue;
    final mediaId = item.mediaId;
    if (mediaId == null) continue;
    final id = 'MED-$mediaId';
    if (byId.containsKey(id)) continue;
    merged.add(
      Evaluation(
        id: id,
        title: item.title,
        score: 0,
        composition: 'N/A',
        lighting: 'N/A',
        feedback: '',
        date: item.date,
        imageUrl: item.networkUrl,
        mediaType: item.isVideo ? 'video' : 'photo',
        isAnalysisInProgress: true,
      ),
    );
  }
  return merged;
}

String evaluationDailyLimitResetLabel(String? ianaTimezone) {
  final tz = (ianaTimezone ?? 'Asia/Manila').trim();
  const labels = {
    'Asia/Manila': 'Philippine Time',
    'UTC': 'UTC',
  };
  return labels[tz] ?? tz.replaceAll('_', ' ');
}
