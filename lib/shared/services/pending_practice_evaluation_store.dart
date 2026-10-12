import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingPracticeEvaluationEntry {
  const PendingPracticeEvaluationEntry({
    required this.mediaId,
    required this.isVideo,
  });

  final int mediaId;
  final bool isVideo;

  Map<String, dynamic> toJson() => {'media_id': mediaId, 'is_video': isVideo};

  static PendingPracticeEvaluationEntry? fromJsonMap(Map<String, dynamic> map) {
    final id = map['media_id'];
    final mediaId = id is int ? id : int.tryParse('$id');
    if (mediaId == null || mediaId <= 0) return null;
    return PendingPracticeEvaluationEntry(
      mediaId: mediaId,
      isVideo: map['is_video'] as bool? ?? false,
    );
  }
}

/// Practice uploads still on the server pipeline (member left screen or poll timed out).
abstract final class PendingPracticeEvaluationStore {
  static const _prefsKey = 'access_pending_practice_eval_v1';

  static List<PendingPracticeEvaluationEntry> _entries = [];
  static bool _loaded = false;

  static List<PendingPracticeEvaluationEntry> get entries =>
      List.unmodifiable(_entries);

  static int get count => _entries.length;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        _entries = [];
        _loaded = true;
        return;
      }
      final list = jsonDecode(raw);
      if (list is! List) {
        _entries = [];
        _loaded = true;
        return;
      }
      _entries = [
        for (final item in list)
          if (item is Map<String, dynamic>)
            PendingPracticeEvaluationEntry.fromJsonMap(item)
          else if (item is Map)
            PendingPracticeEvaluationEntry.fromJsonMap(
              Map<String, dynamic>.from(item),
            )
      ].whereType<PendingPracticeEvaluationEntry>().toList();
    } catch (_) {
      _entries = [];
    }
    _loaded = true;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }

  static Future<void> add(int mediaId, {required bool isVideo}) async {
    await ensureLoaded();
    if (mediaId <= 0) return;
    _entries.removeWhere((e) => e.mediaId == mediaId);
    _entries.add(PendingPracticeEvaluationEntry(mediaId: mediaId, isVideo: isVideo));
    await _persist();
  }

  static Future<void> remove(int mediaId) async {
    await ensureLoaded();
    final before = _entries.length;
    _entries.removeWhere((e) => e.mediaId == mediaId);
    if (_entries.length != before) await _persist();
  }
}
