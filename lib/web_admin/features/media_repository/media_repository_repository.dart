import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads media library data — storage, albums, and admin-curated flags only.
class MediaRepositoryRepository {
  static const _publishedKey = 'media_library_published_ids';
  static const _bestShotsKey = 'media_library_best_shot_ids';
  static const _archivedKey = 'media_library_archived_ids';
  static const _albumOverridesKey = 'media_library_album_overrides';

  Future<List<MediaAsset>> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception(
        'Backend offline. Run: cd access_backend && python manage.py runserver',
      );
    }

    final mediaRows = await adminApi.allMedia();
    final published = await loadPublishedIds();
    final bestShots = await loadBestShotIds();
    final archived = await loadArchivedIds();
    final albumOverrides = await loadAlbumOverrides();

    return mediaRows
        .map((row) => _mapRow(row, published, bestShots, albumOverrides))
        .where((a) => !archived.contains(a.id))
        .toList()
      ..sort((a, b) => (b.uploadedAt ?? DateTime(2000)).compareTo(a.uploadedAt ?? DateTime(2000)));
  }

  MediaAsset _mapRow(
    Map<String, dynamic> row,
    Set<int> published,
    Set<int> bestShots,
    Map<int, String> albumOverrides,
  ) {
    final id = row['id'] as int? ?? 0;
    final eventTitle = row['event_title'] as String? ??
        row['source_label'] as String? ??
        'Uncategorized';
    final requestId = row['request_id'] as int?;
    final albumName = albumOverrides[id] ?? eventTitle;

    return MediaAsset(
      id: id,
      fileName: row['file_name'] as String? ?? 'Media #$id',
      fileType: row['file_type'] as String? ?? 'image',
      fileUrl: row['file_url'] as String? ?? '',
      eventName: eventTitle,
      albumName: albumName,
      uploaderName: row['uploader_name'] as String? ?? 'Unknown',
      uploadedAt: _parseDate(row['uploaded_at'] as String?),
      requestId: requestId,
      isPublished: published.contains(id),
      isBestShot: bestShots.contains(id),
    );
  }

  List<MediaAlbum> buildAlbums(List<MediaAsset> assets) {
    final map = <String, List<MediaAsset>>{};
    for (final a in assets) {
      final key = MediaAsset.albumKey(a.albumName, a.requestId);
      map.putIfAbsent(key, () => []).add(a);
    }

    return map.entries.map((e) {
      final items = e.value;
      final photos = items.where((i) => i.isPhoto).length;
      final videos = items.where((i) => i.isVideo).length;
      final cover = items.firstWhere(
        (i) => i.isPhoto && i.thumbnailUrl.isNotEmpty,
        orElse: () => items.first,
      );
      final dates = items.map((i) => i.uploadedAt).whereType<DateTime>().toList()..sort();
      return MediaAlbum(
        id: e.key,
        name: items.first.albumName,
        date: dates.isNotEmpty ? dates.last : null,
        photoCount: photos,
        videoCount: videos,
        coverUrl: cover.thumbnailUrl,
        requestId: items.first.requestId,
      );
    }).toList()
      ..sort((a, b) => b.totalCount.compareTo(a.totalCount));
  }

  MediaLibraryStats computeStats(List<MediaAsset> assets, List<MediaAlbum> albums) {
    final photos = assets.where((a) => a.isPhoto).length;
    final videos = assets.where((a) => a.isVideo).length;
    final mb = assets.fold<double>(0, (sum, a) => a.isVideo ? sum + 2.5 : sum + 1.1);
    final storage = mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.toStringAsFixed(1)} MB';
    return MediaLibraryStats(
      totalPhotos: photos,
      totalVideos: videos,
      totalAlbums: albums.length,
      storageUsedLabel: storage,
    );
  }

  List<MediaAsset> filter({
    required List<MediaAsset> items,
    required String search,
    String? albumId,
  }) {
    return items.where((a) => a.matchesSearch(search)).where((a) => a.matchesAlbum(albumId)).toList();
  }

  List<MediaAsset> recentUploads(List<MediaAsset> items, {int limit = 24}) =>
      items.take(limit).toList();

  List<MediaAsset> bestShots(List<MediaAsset> items) =>
      items.where((a) => a.isBestShot).toList();

  Future<Set<int>> loadPublishedIds() async => _loadIdSet(_publishedKey);

  Future<Set<int>> loadBestShotIds() async => _loadIdSet(_bestShotsKey);

  Future<Set<int>> loadArchivedIds() async => _loadIdSet(_archivedKey);

  Future<Map<int, String>> loadAlbumOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_albumOverridesKey) ?? [];
    final map = <int, String>{};
    for (final entry in raw) {
      final sep = entry.indexOf(':');
      if (sep <= 0) continue;
      final id = int.tryParse(entry.substring(0, sep));
      if (id != null) map[id] = entry.substring(sep + 1);
    }
    return map;
  }

  Future<void> markPublished(int mediaId) async {
    final ids = await loadPublishedIds()..add(mediaId);
    await _saveIdSet(_publishedKey, ids);
  }

  Future<void> markPublishedMany(Iterable<int> mediaIds) async {
    final ids = await loadPublishedIds()..addAll(mediaIds);
    await _saveIdSet(_publishedKey, ids);
  }

  Future<void> toggleBestShot(int mediaId) async {
    final ids = await loadBestShotIds();
    if (ids.contains(mediaId)) {
      ids.remove(mediaId);
    } else {
      ids.add(mediaId);
    }
    await _saveIdSet(_bestShotsKey, ids);
  }

  Future<void> archiveMedia(int mediaId) async {
    final ids = await loadArchivedIds()..add(mediaId);
    await _saveIdSet(_archivedKey, ids);
  }

  Future<void> archiveMany(Iterable<int> mediaIds) async {
    final ids = await loadArchivedIds()..addAll(mediaIds);
    await _saveIdSet(_archivedKey, ids);
  }

  Future<void> moveToAlbum(int mediaId, String albumName) async {
    final overrides = await loadAlbumOverrides();
    overrides[mediaId] = albumName;
    await _saveAlbumOverrides(overrides);
  }

  Future<void> moveManyToAlbum(Iterable<int> mediaIds, String albumName) async {
    final overrides = await loadAlbumOverrides();
    for (final id in mediaIds) {
      overrides[id] = albumName;
    }
    await _saveAlbumOverrides(overrides);
  }

  Future<Set<int>> _loadIdSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key)?.map(int.tryParse).whereType<int>().toSet() ?? {};
  }

  Future<void> _saveIdSet(String key, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.map((e) => '$e').toList());
  }

  Future<void> _saveAlbumOverrides(Map<int, String> overrides) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _albumOverridesKey,
      overrides.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
