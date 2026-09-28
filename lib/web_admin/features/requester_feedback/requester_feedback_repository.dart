import 'dart:convert';

import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequesterFeedbackRepository {
  static const _reviewStatusKey = 'requester_feedback_review_status';
  static const _adminResponseKey = 'requester_feedback_admin_response';
  static const _publishedKey = 'media_library_published_ids';

  Future<RequesterFeedbackDashboardData> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception('Backend offline. Run: cd access_backend && python manage.py runserver');
    }

    final results = await Future.wait([
      adminApi.allFeedback(),
      adminApi.allServiceRequests(),
      adminApi.allTasks(),
      adminApi.allMedia(),
      adminApi.allUsers(),
    ]);

    final feedbackRows = (results[0] as List).cast<Map<String, dynamic>>();
    final requests = (results[1] as List).cast<Map<String, dynamic>>();
    final tasks = (results[2] as List).cast<Map<String, dynamic>>();
    final media = (results[3] as List).cast<Map<String, dynamic>>();
    final users = (results[4] as List).cast<Map<String, dynamic>>();

    final statusMap = await _loadReviewStatuses();
    final responseMap = await _loadAdminResponses();
    final publishedIds = await _loadPublishedIds();

    final tasksByRequest = <int, List<Map<String, dynamic>>>{};
    for (final t in tasks) {
      final rid = t['request_id'] as int?;
      if (rid == null) continue;
      tasksByRequest.putIfAbsent(rid, () => []).add(t);
    }

    final requestItems = requests
        .map((r) {
          final id = r['request_id'] as int? ?? 0;
          return DocumentationRequestItem.fromMaps(r, tasksByRequest[id] ?? []);
        })
        .toList();

    final requestById = {for (final r in requestItems) r.id: r};
    final orgByUserId = _organizationNames(users);

    final mediaByRequest = <int, List<Map<String, dynamic>>>{};
    for (final m in media) {
      final rid = m['request_id'] as int?;
      if (rid == null) continue;
      mediaByRequest.putIfAbsent(rid, () => []).add(m);
    }

    final feedback = <RequesterFeedbackItem>[];
    for (final row in feedbackRows) {
      final id = row['id'] as int? ?? 0;
      final requestId = row['request_id'] as int? ?? 0;
      final req = requestById[requestId];
      final rating = (row['rating'] as num?)?.round().clamp(1, 5) ?? 1;
      final comment = (row['comment'] ?? row['feedback'] ?? row['message'] ?? '').toString();
      final reviewStatus = _parseReviewStatus(statusMap['$id']);
      final adminResponse = responseMap['$id'];
      final submittedAt = _parseDate(row['created_at']);

      final summary = _buildEventSummary(
        request: req,
        requestId: requestId,
        eventName: row['event_title'] as String? ?? row['event_name'] as String? ?? req?.eventTitle ?? 'Event',
        tasks: tasksByRequest[requestId] ?? [],
        mediaFiles: mediaByRequest[requestId] ?? [],
        publishedIds: publishedIds,
      );

      final attention = _lowRatingAttention(rating, comment);

      feedback.add(
        RequesterFeedbackItem(
          id: id,
          requestId: requestId,
          eventName: summary.eventName,
          organization: req != null ? (orgByUserId[req.requesterId] ?? req.requestor) : (row['member_name'] as String? ?? 'Organization'),
          requesterName: row['user_name'] as String? ?? row['member_name'] as String? ?? req?.requestor ?? 'Requester',
          eventDate: req?.eventDate,
          submittedAt: submittedAt,
          completionDate: summary.completionDate,
          rating: rating,
          comment: comment,
          reviewStatus: reviewStatus,
          eventSummary: summary,
          adminResponse: adminResponse,
          needsAttention: attention != null,
          attentionReason: attention,
        ),
      );
    }

    feedback.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));

    final active = feedback.where((f) => !f.isArchived).toList();
    return RequesterFeedbackDashboardData(
      feedback: feedback,
      stats: _computeStats(active),
      featured: _pickFeatured(active),
    );
  }

  List<RequesterFeedbackItem> filter({
    required List<RequesterFeedbackItem> items,
    required FeedbackFilterChip chip,
    required String search,
  }) {
    return items.where((item) {
      if (!item.matchesChip(chip)) return false;
      if (search.trim().isEmpty) return true;
      final q = search.toLowerCase();
      return item.eventName.toLowerCase().contains(q) ||
          item.organization.toLowerCase().contains(q) ||
          item.requesterName.toLowerCase().contains(q) ||
          '${item.rating}'.contains(q) ||
          (item.eventDate != null && formatFeedbackDate(item.eventDate).toLowerCase().contains(q));
    }).toList();
  }

  Future<void> setReviewStatus(int feedbackId, FeedbackReviewStatus status) async {
    final map = await _loadReviewStatuses();
    map['$feedbackId'] = status.name;
    await _saveMap(_reviewStatusKey, map);
  }

  Future<void> setAdminResponse(int feedbackId, String response) async {
    final map = await _loadAdminResponses();
    if (response.trim().isEmpty) {
      map.remove('$feedbackId');
    } else {
      map['$feedbackId'] = response;
    }
    await _saveMap(_adminResponseKey, map);
  }

  String buildExportReport(RequesterFeedbackDashboardData data) {
    final buf = StringBuffer('ACCESS VisionCheck — Requester Feedback Report\n');
    buf.writeln('Generated: ${DateTime.now().toLocal()}\n');
    final s = data.stats;
    buf.writeln('Overview');
    buf.writeln('  Average satisfaction: ${s.averageRating > 0 ? s.averageRating.toStringAsFixed(1) : '—'} / 5');
    buf.writeln('  Total feedback received: ${s.totalReceived}');
    buf.writeln('  Positive reviews (4–5★): ${s.positiveReviews}');
    buf.writeln('  Needs attention (<3★): ${s.needsAttention}\n');
    for (final f in data.feedback.where((i) => !i.isArchived)) {
      buf.writeln('${f.eventName} — ${f.organization}');
      buf.writeln('  Rating: ${f.rating}/5 · Submitted ${formatFeedbackDate(f.submittedAt)}');
      buf.writeln('  Requester: ${f.requesterName}');
      if (f.comment.isNotEmpty) buf.writeln('  Comment: ${f.comment}');
      if (f.adminResponse?.isNotEmpty == true) buf.writeln('  Admin response: ${f.adminResponse}');
      buf.writeln('');
    }
    return buf.toString();
  }

  FeaturedTestimonial? _pickFeatured(List<RequesterFeedbackItem> items) {
    final candidates = items.where((i) => i.rating == 5 && i.comment.trim().length >= 40).toList();
    if (candidates.isEmpty) {
      final fallback = items.where((i) => i.rating >= 4 && i.comment.trim().isNotEmpty).toList();
      if (fallback.isEmpty) return null;
      fallback.sort((a, b) => b.comment.length.compareTo(a.comment.length));
      final best = fallback.first;
      return FeaturedTestimonial(quote: best.comment.trim(), organization: best.organization, rating: best.rating, eventName: best.eventName);
    }
    candidates.sort((a, b) => b.comment.length.compareTo(a.comment.length));
    final best = candidates.first;
    return FeaturedTestimonial(quote: best.comment.trim(), organization: best.organization, rating: best.rating, eventName: best.eventName);
  }

  EventServiceSummary _buildEventSummary({
    required DocumentationRequestItem? request,
    required int requestId,
    required String eventName,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> mediaFiles,
    required Set<int> publishedIds,
  }) {
    final photographers = <String>[];
    final videographers = <String>[];
    for (final t in tasks) {
      final name = t['member_name'] as String? ?? 'Member';
      final role = (t['task_role'] as String? ?? '').toLowerCase();
      if (role.contains('video')) {
        videographers.add(name);
      } else if (role.contains('photo')) {
        photographers.add(name);
      }
    }

    var photos = 0, videos = 0, published = 0;
    DateTime? latestUpload;
    for (final m in mediaFiles) {
      final type = (m['file_type'] as String? ?? '').toLowerCase();
      if (type.contains('video')) {
        videos++;
      } else {
        photos++;
      }
      final mid = m['id'] as int?;
      if (mid != null && publishedIds.contains(mid)) published++;
      final d = _parseDate(m['uploaded_at']);
      if (d != null && (latestUpload == null || d.isAfter(latestUpload))) latestUpload = d;
    }

    return EventServiceSummary(
      eventName: request?.eventTitle ?? eventName,
      photographers: photographers,
      videographers: videographers,
      photoCount: photos,
      videoCount: videos,
      facebookPublished: published > 0,
      completionDate: latestUpload ?? request?.eventDate,
    );
  }

  String? _lowRatingAttention(int rating, String comment) {
    if (rating >= 3) return null;
    final c = comment.toLowerCase();
    if (c.contains('late') || c.contains('delay') || c.contains('slow')) {
      return 'Documentation delivered late.';
    }
    if (c.contains('missed') || c.contains('not captured') || c.contains('not documented') || c.contains('important')) {
      return 'Some important moments were not captured.';
    }
    if (c.contains('communication') || c.contains('respond') || c.contains('contact')) {
      return 'Communication could be improved.';
    }
    final text = comment.trim();
    if (text.isEmpty) return 'Low overall satisfaction rating requires follow-up.';
    final first = text.split(RegExp(r'[.!?]')).first.trim();
    if (first.length <= 80) return first.endsWith('.') ? first : '$first.';
    return '${first.substring(0, 77)}…';
  }

  FeedbackOverviewStats _computeStats(List<RequesterFeedbackItem> items) {
    if (items.isEmpty) {
      return const FeedbackOverviewStats(averageRating: 0, totalReceived: 0, positiveReviews: 0, needsAttention: 0);
    }
    final sum = items.fold<int>(0, (a, i) => a + i.rating);
    return FeedbackOverviewStats(
      averageRating: sum / items.length,
      totalReceived: items.length,
      positiveReviews: items.where((i) => i.rating >= 4).length,
      needsAttention: items.where((i) => i.rating < 3).length,
    );
  }

  Map<int, String> _organizationNames(List<Map<String, dynamic>> users) {
    final out = <int, String>{};
    for (final u in users) {
      final id = u['user_id'] as int? ?? u['id'] as int?;
      if (id == null) continue;
      final role = (u['role'] as String? ?? '').toLowerCase();
      final name = u['name'] as String? ?? u['fullname'] as String? ?? '';
      if (role.contains('organization') || role.contains('org')) {
        out[id] = name.isNotEmpty ? name : 'Organization';
      } else {
        out[id] = name;
      }
    }
    return out;
  }

  FeedbackReviewStatus _parseReviewStatus(String? raw) {
    if (raw == null) return FeedbackReviewStatus.pending;
    return FeedbackReviewStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => FeedbackReviewStatus.pending,
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<Map<String, String>> _loadReviewStatuses() => _loadMap(_reviewStatusKey);
  Future<Map<String, String>> _loadAdminResponses() => _loadMap(_adminResponseKey);

  Future<Map<String, String>> _loadMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry('$k', '$v'));
  }

  Future<void> _saveMap(String key, Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(map));
  }

  Future<Set<int>> _loadPublishedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_publishedKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.map((e) => int.tryParse('$e')).whereType<int>().toSet();
  }
}
