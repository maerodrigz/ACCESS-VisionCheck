import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/models/reschedule_models.dart';
import 'package:access_mobile/shared/services/media_upload_service.dart';

class MemberApiService {
  String mediaUrl(String? path) => ApiConfig.mediaUrl(path);

  String _mediaUrl(String path) => mediaUrl(path);

  String? _mediaFileUrlFromJson(Map<String, dynamic> m) {
    if (m['storage_removed'] == true) return '';
    final raw = m['file_url'] as String?;
    if (raw == null || raw.isEmpty) return raw;
    return _mediaUrl(raw);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final data = await apiClient.get('/member/profile');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getMilestones({bool unacknowledgedOnly = false}) async {
    final data = await apiClient.get(
      '/member/milestones',
      queryParameters: {'unacknowledged_only': unacknowledgedOnly},
    );
    final map = Map<String, dynamic>.from(data as Map);
    final rows = map['milestones'];
    if (rows is! List) return [];
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> acknowledgeMilestone(int milestoneId) async {
    final data = await apiClient.patch('/member/milestones/$milestoneId/acknowledge', {});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getParticipation() async {
    final data = await apiClient.get('/member/participation');
    return Map<String, dynamic>.from(data as Map);
  }

  /// Requestor ratings and comments received by the logged-in member.
  Future<Map<String, dynamic>> getReceivedRequestorRatings({int limit = 20}) async {
    final data = await apiClient.get('/member/requester-ratings?limit=$limit');
    return Map<String, dynamic>.from(data as Map);
  }

  /// Updates the logged-in user's profile. Returns the updated profile JSON.
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? contactNumber,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email.trim().toLowerCase(),
      if (contactNumber != null) 'contact_number': contactNumber,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'current_password': currentPassword,
      if (newPassword != null && newPassword.isNotEmpty) 'new_password': newPassword,
    };
    final data = await apiClient.patch('/profile', body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadProfileAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    final userId = authController.user?.id;
    if (userId == null) {
      throw const ApiException('Not signed in.');
    }
    return MediaUploadService.uploadProfileAvatar(
      client: apiClient,
      bytes: bytes,
      fileName: fileName,
      userId: userId,
    );
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    final data = await apiClient.get('/tasks');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> updateTaskStatus(int assignmentId, String status) async {
    final data = await apiClient.patch('/tasks/$assignmentId', {'status': status});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> respondToAssignment(
    int assignmentId, {
    required String action,
    String? declineReasonCode,
    String? declineReason,
  }) async {
    final data = await apiClient.post('/tasks/$assignmentId/respond', {
      'action': action,
      if (declineReasonCode != null) 'decline_reason_code': declineReasonCode,
      if (declineReason != null) 'decline_reason': declineReason,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    final data = await apiClient.get('/events');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final data = await apiClient.get('/notifications');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final data = await apiClient.get('/notifications/preferences');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateNotificationPreferences({
    bool? evaluationFeedback,
    bool? eventCalendar,
    bool? systemAnnouncements,
  }) async {
    final body = <String, dynamic>{
      if (evaluationFeedback != null) 'evaluation_feedback': evaluationFeedback,
      if (eventCalendar != null) 'event_calendar': eventCalendar,
      if (systemAnnouncements != null) 'system_announcements': systemAnnouncements,
    };
    final data = await apiClient.patch('/notifications/preferences', body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final data = await apiClient.get('/announcements');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> markNotificationRead(int id) async {
    await apiClient.patch('/notifications/$id/read', {});
  }

  Future<void> markAllNotificationsRead() async {
    await apiClient.post('/notifications/read-all', {});
  }

  Future<void> clearReadNotifications() async {
    await apiClient.delete('/notifications/read');
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    await apiClient.post('/notifications/push-token', {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> unregisterPushToken(String token) async {
    final encoded = Uri.encodeQueryComponent(token);
    await apiClient.delete('/notifications/push-token?token=$encoded');
  }

  Future<List<Map<String, dynamic>>> getEventGallery({
    String? search,
    String? fileType,
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (fileType != null) 'file_type': fileType,
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
    };
    final path = params.isEmpty ? '/gallery' : '/gallery?${Uri(queryParameters: params).query}';
    final data = await apiClient.get(path);
    if (data is! List) {
      var msg = 'Gallery could not be loaded';
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String) {
          msg = detail;
        } else if (detail is Map) {
          msg = detail['message'] as String? ?? msg;
        } else {
          msg = data['message'] as String? ?? msg;
        }
      }
      throw ApiException(msg);
    }
    return data.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['file_url'] = _mediaUrl(m['file_url'] as String? ?? '');
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> getMediaById(int mediaId) async {
    if (mediaId <= 0) return null;
    final data = await apiClient.get('/media/$mediaId');
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    m['file_url'] = _mediaFileUrlFromJson(m);
    return m;
  }

  /// Frees cloud/disk bytes for a practice eval. Scores and XP are unchanged.
  Future<Map<String, dynamic>> removePracticeMediaStorage(int mediaId) async {
    final data = await apiClient.delete('/media/$mediaId/storage');
    final m = Map<String, dynamic>.from(data as Map);
    m['file_url'] = _mediaFileUrlFromJson(m);
    return m;
  }

  /// Full evaluation row (includes criteria_json) after deferred pipeline completes.
  Future<Map<String, dynamic>?> getEvaluationRowForMedia(int mediaId) async {
    if (mediaId <= 0) return null;
    final rows = await getEvaluations();
    for (final row in rows) {
      if ((row['media_id'] as num?)?.toInt() == mediaId) {
        return row;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getMedia({
    bool mine = true,
    String? search,
    String? mediaCategory,
  }) async {
    final query = <String, String>{
      if (mine) 'mine': 'true',
      if (search != null) 'search': search,
      if (mediaCategory != null && mediaCategory.isNotEmpty)
        'media_category': mediaCategory,
    };
    final path = query.isEmpty ? '/media' : '/media?${Uri(queryParameters: query).query}';
    final data = await apiClient.get(path);
    return (data as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['file_url'] = _mediaFileUrlFromJson(m);
      return m;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchRepository({String? search, String? fileType}) async {
    final params = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (fileType != null) 'file_type': fileType,
    };
    final path = params.isEmpty
        ? '/repository'
        : '/repository?${Uri(queryParameters: params).query}';
    final data = await apiClient.get(path);
    return (data as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['file_url'] = _mediaUrl(m['file_url'] as String? ?? '');
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>> evaluateMedia({
    required List<int> bytes,
    required String fileName,
  }) async {
    final data = await apiClient.postMultipart(
      '/media/evaluate',
      fileBytes: bytes,
      fileName: fileName,
      fields: const {},
      timeout: ApiClient.mediaUploadTimeout(byteLength: bytes.length, fileName: fileName),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Server-proxied Gemini mentor feedback for practice evaluation scores.
  Future<Map<String, dynamic>?> fetchGeminiMediaFeedback(
    Map<String, dynamic> evaluation,
  ) async {
    try {
      final data = await apiClient.post(
        '/ai/media-evaluation-feedback',
        {'evaluation': evaluation},
      );
      if (data is! Map) return null;
      final feedback = data['feedback'];
      if (feedback is Map) {
        return Map<String, dynamic>.from(feedback);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> fetchGeminiRubricFeedback({
    required Map<String, int> scores,
    required String title,
    required int totalScore,
    required int maxScore,
  }) async {
    try {
      final data = await apiClient.post('/ai/rubric-feedback', {
        'scores': scores,
        'title': title,
        'total_score': totalScore,
        'max_score': maxScore,
      });
      if (data is! Map) return null;
      final text = data['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> uploadMedia({
    required List<int> bytes,
    required String fileName,
    int? requestId,
    String? displayName,
    String? evaluationMetadata,
  }) async {
    return MediaUploadService.uploadMedia(
      client: apiClient,
      bytes: bytes,
      fileName: fileName,
      requestId: requestId,
      displayName: displayName,
      evaluationMetadata: evaluationMetadata,
      userId: authController.user?.id,
    );
  }

  Future<List<Map<String, dynamic>>> getEvaluations() async {
    final data = await apiClient.get('/evaluations?mine=true');
    return (data as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['file_url'] = _mediaFileUrlFromJson(m);
      return m;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRankings() async {
    final data = await apiClient.get('/rankings');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> submitFeedback({
    required int requestId,
    required int rating,
    String? comment,
  }) async {
    await apiClient.post('/feedback', {
      'request_id': requestId,
      'rating': rating,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> getFeedback() async {
    final data = await apiClient.get('/feedback');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Assigned photographers/videographers the requestor can rate for an event.
  Future<List<Map<String, dynamic>>> getAssignmentRatingTargets(int requestId) async {
    final data = await apiClient.get('/feedback/member-ratings/assignments?request_id=$requestId');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> submitMemberRatings({
    required int requestId,
    required List<Map<String, dynamic>> ratings,
  }) async {
    await apiClient.post('/feedback/member-ratings', {
      'request_id': requestId,
      'ratings': ratings,
    });
  }

  Future<List<Map<String, dynamic>>> getMemberRatings({int? requestId}) async {
    final path = requestId != null
        ? '/feedback/member-ratings?request_id=$requestId'
        : '/feedback/member-ratings';
    final data = await apiClient.get(path);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> logFacebookShareOpened({
    required int mediaId,
    String? message,
    String? shareUrl,
  }) async {
    await apiClient.post('/facebook/share/opened', {
      'media_id': mediaId,
      if (message != null && message.isNotEmpty) 'message': message,
      if (shareUrl != null && shareUrl.isNotEmpty) 'share_url': shareUrl,
    });
  }

  Future<Map<String, dynamic>> getServiceRequest(int id) async {
    final data = await apiClient.get('/service-requests/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> getServiceRequests() async {
    final data = await apiClient.get('/service-requests');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createServiceRequest(Map<String, dynamic> body) async {
    final data = await apiClient.post('/service-requests', body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<CoverageDay>> getCoverageAvailability({
    required int year,
    required int month,
    int? excludeRequestId,
  }) async {
    final data = await apiClient.get(
      '/service-requests/coverage-availability',
      queryParameters: {
        'year': year,
        'month': month,
        if (excludeRequestId != null) 'exclude_request_id': excludeRequestId,
      },
    );
    return (data as List)
        .map((e) => CoverageDay.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<CoverageTimeSlot>> getCoverageSlots({
    required DateTime date,
    int? excludeRequestId,
  }) async {
    final iso = date.toIso8601String().split('T').first;
    final data = await apiClient.get(
      '/service-requests/coverage-availability/slots',
      queryParameters: {
        'date': iso,
        if (excludeRequestId != null) 'exclude_request_id': excludeRequestId,
      },
    );
    return (data as List)
        .map((e) => CoverageTimeSlot.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> rescheduleServiceRequest(
    int requestId, {
    required DateTime eventDate,
    String? startTime,
    String? endTime,
  }) async {
    final data = await apiClient.post('/service-requests/$requestId/reschedule', {
      'event_date': eventDate.toIso8601String().split('T').first,
      if (startTime != null && startTime.isNotEmpty) 'start_time': startTime,
      if (endTime != null && endTime.isNotEmpty) 'end_time': endTime,
    });
    return Map<String, dynamic>.from(data as Map);
  }
}

final memberApiService = MemberApiService();
