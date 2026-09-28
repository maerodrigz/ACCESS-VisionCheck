import 'package:access_mobile/shared/api/admin_api_service.dart';

class MediaLibraryStats {
  const MediaLibraryStats({
    required this.totalPhotos,
    required this.totalVideos,
    required this.totalAlbums,
    required this.storageUsedLabel,
  });

  final int totalPhotos;
  final int totalVideos;
  final int totalAlbums;
  final String storageUsedLabel;
}

class MediaAlbum {
  const MediaAlbum({
    required this.id,
    required this.name,
    required this.date,
    required this.photoCount,
    required this.videoCount,
    required this.coverUrl,
    this.requestId,
  });

  final String id;
  final String name;
  final DateTime? date;
  final int photoCount;
  final int videoCount;
  final String coverUrl;
  final int? requestId;

  int get totalCount => photoCount + videoCount;
}

class MediaAsset {
  MediaAsset({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.eventName,
    required this.albumName,
    required this.uploaderName,
    required this.uploadedAt,
    this.requestId,
    this.isPublished = false,
    this.isBestShot = false,
  });

  final int id;
  final String fileName;
  final String fileType;
  final String fileUrl;
  final String eventName;
  final String albumName;
  final String uploaderName;
  final DateTime? uploadedAt;
  final int? requestId;
  bool isPublished;
  bool isBestShot;

  bool get isVideo => fileType.toLowerCase() == 'video';
  bool get isPhoto => !isVideo;

  String get thumbnailUrl => AdminApiService.mediaUrl(fileUrl);

  String get mediaTypeLabel => isVideo ? 'Video' : 'Photo';

  String get uploaderRoleLabel => isVideo ? 'Videographer' : 'Photographer';

  String get publishedStatusLabel => isPublished ? 'Published' : 'Not published';

  String get formatLabel {
    final parts = fileName.split('.');
    if (parts.length > 1) return parts.last.toUpperCase();
    return isVideo ? 'MP4' : 'JPEG';
  }

  String get estimatedFileSize {
    final seed = id % 7;
    if (isVideo) return '${2 + seed}.$seed MB';
    return '${800 + seed * 120} KB';
  }

  String get resolutionLabel {
    final presets = isVideo
        ? ['1920×1080', '1280×720', '3840×2160']
        : ['4032×3024', '6000×4000', '3264×2448'];
    return presets[id % presets.length];
  }

  String? get uploadDateLabel =>
      uploadedAt != null ? formatMediaDate(uploadedAt!) : null;

  bool matchesSearch(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    bool hit(String? s) => s != null && s.toLowerCase().contains(q);
    return hit(fileName) ||
        hit(eventName) ||
        hit(albumName) ||
        hit(uploaderName) ||
        hit(mediaTypeLabel) ||
        (uploadedAt != null && formatMediaDate(uploadedAt!).toLowerCase().contains(q));
  }

  bool matchesAlbum(String? albumId) {
    if (albumId == null || albumId.isEmpty) return true;
    return albumId == albumKey(albumName, requestId);
  }

  static String albumKey(String name, int? requestId) =>
      requestId != null ? 'req_$requestId' : 'evt_${name.toLowerCase()}';

  static String formatMediaDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
