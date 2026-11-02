/// Member-defined titles for practice photo/video evaluations (not event coverage).
const int kPracticeMediaTitleMaxLength = 80;

const _genericStoredTitles = {
  'practice upload',
  'upload',
  'media',
  'practice submission',
};

String practiceMediaTitleFieldLabel({required bool isVideo}) =>
    isVideo ? 'Video Title' : 'Photo Title';

String practiceMediaTitlePlaceholder({required bool isVideo}) =>
    isVideo ? 'School Event Highlights' : 'Sunset at the Beach';

String normalizePracticeMediaTitle(String raw) => raw.trim();

String? validatePracticeMediaTitle(String raw, {required bool isVideo}) {
  final title = normalizePracticeMediaTitle(raw);
  if (title.isEmpty) {
    return 'Enter a ${isVideo ? 'video' : 'photo'} title before you start evaluation.';
  }
  if (title.length > kPracticeMediaTitleMaxLength) {
    return 'Title must be $kPracticeMediaTitleMaxLength characters or fewer.';
  }
  return null;
}

bool _isGenericPracticeTitle(String title) =>
    _genericStoredTitles.contains(title.trim().toLowerCase());

/// Display label for saved practice evaluations (API `file_name` / member title).
String practiceMediaDisplayTitle(
  String? storedName, {
  String? mediaType,
  bool isVideo = false,
}) {
  final video = isVideo || (mediaType ?? '').toLowerCase() == 'video';
  final fallback = video ? 'Untitled Video' : 'Untitled Photo';
  final trimmed = storedName?.trim() ?? '';
  if (trimmed.isEmpty || _isGenericPracticeTitle(trimmed)) return fallback;
  return trimmed;
}
