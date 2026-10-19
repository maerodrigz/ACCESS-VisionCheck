import 'package:access_mobile/shared/constants/api_config.dart';

/// Approved event/documentation media item for the member gallery.
class EventGalleryMedia {
  const EventGalleryMedia({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.uploadedAt,
    this.requestId,
    this.eventTitle,
    this.eventDate,
    this.eventDescription,
    this.eventCategory,
    this.facebookPublishStatus = 'not_published',
    this.facebookPostId,
  });

  final int id;
  final String fileName;
  final String fileType;
  final String fileUrl;
  final DateTime? uploadedAt;
  final int? requestId;
  final String? eventTitle;
  final DateTime? eventDate;
  final String? eventDescription;
  final String? eventCategory;
  final String facebookPublishStatus;
  final String? facebookPostId;

  bool get isPublishedToFacebook =>
      facebookPublishStatus == 'published' && facebookPostId != null;

  bool get isVideo {
    if (fileType.toLowerCase() == 'video') return true;
    final lower = fileName.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.m4v');
  }
  bool get isPhoto => !isVideo;

  String get thumbnailUrl => ApiConfig.mediaUrl(fileUrl);

  String get albumName => (eventTitle?.trim().isNotEmpty ?? false)
      ? eventTitle!.trim()
      : 'ACCESS Event';

  static String albumKey(String name, int? requestId) =>
      requestId != null ? 'req_$requestId' : 'evt_${name.toLowerCase()}';

  String get albumId => albumKey(albumName, requestId);

  bool matchesSearch(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    if (_textContains(eventTitle, q) || _textContains(albumName, q)) return true;
    if (_textContains(eventCategory, q)) return true;
    if (eventGalleryDateMatches(eventDate ?? uploadedAt, q)) return true;
    return eventGalleryMediaTypeMatches(isPhoto: isPhoto, isVideo: isVideo, q: q);
  }
}

/// Shared gallery search helpers (event name, date, media type).
bool _textContains(String? value, String q) =>
    value != null && value.toLowerCase().contains(q);

bool eventGalleryMediaTypeMatches({
  required bool isPhoto,
  required bool isVideo,
  required String q,
}) {
  const photoTerms = ['photo', 'photos', 'image', 'images'];
  const videoTerms = ['video', 'videos'];
  if (photoTerms.contains(q)) return isPhoto;
  if (videoTerms.contains(q)) return isVideo;
  for (final term in photoTerms) {
    if (q == term || q.startsWith('$term ') || q.endsWith(' $term')) {
      return isPhoto;
    }
  }
  for (final term in videoTerms) {
    if (q == term || q.startsWith('$term ') || q.endsWith(' $term')) {
      return isVideo;
    }
  }
  return false;
}

bool eventGalleryMediaTypeAlbumMatch({
  required int photoCount,
  required int videoCount,
  required String q,
}) {
  if (photoCount > 0 &&
      eventGalleryMediaTypeMatches(isPhoto: true, isVideo: false, q: q)) {
    return true;
  }
  if (videoCount > 0 &&
      eventGalleryMediaTypeMatches(isPhoto: false, isVideo: true, q: q)) {
    return true;
  }
  return false;
}

bool eventGalleryDateMatches(DateTime? date, String q) {
  if (date == null || q.isEmpty) return false;

  const months = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];
  const shortMonths = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  final longLabel = EventGalleryAlbum.formatDate(date).toLowerCase();
  if (longLabel.contains(q)) return true;

  final d = date;
  final variants = <String>[
    '$shortMonths[d.month - 1] ${d.day}, ${d.year}',
    '$shortMonths[d.month - 1] ${d.day} ${d.year}',
    '$shortMonths[d.month - 1] ${d.day}',
    '${months[d.month - 1]} ${d.day}',
    '${months[d.month - 1]} ${d.year}',
    '${d.month}/${d.day}/${d.year}',
    '${d.day}/${d.month}/${d.year}',
    '${d.year}',
    '${d.month}/${d.year}',
    '${d.day}/${d.month}',
  ];
  for (final v in variants) {
    if (v.contains(q)) return true;
  }
  return false;
}

class EventGalleryAlbum {
  const EventGalleryAlbum({
    required this.id,
    required this.name,
    required this.date,
    required this.photoCount,
    required this.videoCount,
    required this.coverUrl,
    this.requestId,
    this.eventDescription,
    this.eventCategory,
    this.hasFacebookPublish = false,
  });

  final String id;
  final String name;
  final DateTime? date;
  final int photoCount;
  final int videoCount;
  final String coverUrl;
  final int? requestId;
  final String? eventDescription;
  final String? eventCategory;
  final bool hasFacebookPublish;

  int get totalCount => photoCount + videoCount;

  static String formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String get dateLabel => date != null ? formatDate(date!) : 'Date TBA';

  String get countsLabel =>
      '$photoCount Photo${photoCount == 1 ? '' : 's'} · $videoCount Video${videoCount == 1 ? '' : 's'}';

  /// Matches album search by event name, event date, or media type (photo/video).
  bool matchesSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (_textContains(name, q)) return true;
    if (_textContains(eventCategory, q)) return true;
    if (eventGalleryDateMatches(date, q)) return true;
    if (eventGalleryMediaTypeAlbumMatch(
      photoCount: photoCount,
      videoCount: videoCount,
      q: q,
    )) {
      return true;
    }
    return false;
  }
}

List<EventGalleryAlbum> buildEventGalleryAlbums(
  List<EventGalleryMedia> media, {
  Map<int, String> eventCategoriesByRequestId = const {},
}) {
  final map = <String, List<EventGalleryMedia>>{};
  for (final item in media) {
    map.putIfAbsent(item.albumId, () => []).add(item);
  }

  final albums = <EventGalleryAlbum>[];
  for (final entry in map.entries) {
    final items = entry.value;
    final photos = items.where((i) => i.isPhoto).length;
    final videos = items.where((i) => i.isVideo).length;
    final cover = items.firstWhere(
      (i) => i.isPhoto && i.thumbnailUrl.isNotEmpty,
      orElse: () => items.first,
    );
    final eventDates = items
        .map((i) => i.eventDate ?? i.uploadedAt)
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final requestId = items.first.requestId;
    final category = requestId != null
        ? eventCategoriesByRequestId[requestId]
        : items.first.eventCategory;
    albums.add(
      EventGalleryAlbum(
        id: entry.key,
        name: items.first.albumName,
        date: eventDates.isNotEmpty ? eventDates.first : null,
        photoCount: photos,
        videoCount: videos,
        coverUrl: cover.thumbnailUrl,
        requestId: requestId,
        eventDescription: _firstNonEmptyDescription(items),
        eventCategory: category?.trim().isNotEmpty == true ? category!.trim() : null,
        hasFacebookPublish: items.any((i) => i.isPublishedToFacebook),
      ),
    );
  }

  albums.sort((a, b) {
    final ad = a.date;
    final bd = b.date;
    if (ad != null && bd != null) return bd.compareTo(ad);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return b.totalCount.compareTo(a.totalCount);
  });
  return albums;
}

/// Recent event albums for the horizontal Gallery row (newest first).
const kGalleryRecentWindowDays = 30;
const kGalleryRecentMaxAlbums = 5;

List<EventGalleryAlbum> pickGalleryRecentAlbums(List<EventGalleryAlbum> albums) {
  if (albums.isEmpty) return const [];

  final today = DateTime.now();
  final cutoff = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: kGalleryRecentWindowDays));

  final recent = <EventGalleryAlbum>[];
  for (final album in albums) {
    if (recent.length >= kGalleryRecentMaxAlbums) break;
    final date = album.date;
    if (date == null) continue;
    final eventDay = DateTime(date.year, date.month, date.day);
    if (!eventDay.isBefore(cutoff)) {
      recent.add(album);
    }
  }
  return recent;
}

List<EventGalleryAlbum> galleryAlbumsExcluding(
  List<EventGalleryAlbum> all,
  Iterable<EventGalleryAlbum> exclude,
) {
  final ids = exclude.map((a) => a.id).toSet();
  if (ids.isEmpty) return all;
  return all.where((a) => !ids.contains(a.id)).toList();
}

String? _firstNonEmptyDescription(List<EventGalleryMedia> items) {
  for (final item in items) {
    final d = item.eventDescription?.trim();
    if (d != null && d.isNotEmpty) return d;
  }
  return null;
}

EventGalleryAlbum? galleryAlbumForRequestId(
  Iterable<EventGalleryAlbum> albums,
  int requestId,
) {
  for (final album in albums) {
    if (album.requestId == requestId) return album;
  }
  return null;
}
