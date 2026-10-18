import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/services/media_upload_service.dart';

/// Legacy Flutter web admin API. Canonical admin UI is React (`admin-web/`).
/// Mobile only uses [AdminApiService.fetchGeminiDailySummary] indirectly; prefer
/// [member_api_service.dart] for member/requestor flows.
class AdminApiService {
  AdminApiService(this._api);
  final ApiClient _api;

  static String mediaUrl(String? path) => ApiConfig.mediaUrl(path);

  Future<Map<String, dynamic>> dashboardStats() async {
    final data = await _api.get('/admin/stats');
    return data as Map<String, dynamic>;
  }

  /// Analytics report snapshots from PostgreSQL `analytics_reports`.
  Future<List<Map<String, dynamic>>> allAnalyticsReports() async {
    final data = await _api.get('/admin/analytics/reports');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> allUsers() async {
    final data = await _api.get('/users');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  /// Roles from PostgreSQL `roles` table (Admin, Member, Organization).
  Future<List<Map<String, dynamic>>> allRoles() async {
    final data = await _api.get('/admin/roles');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> setUserStatus(int userId, String status, {String? rejectionReason}) async {
    await _api.patch('/users/$userId/status', {
      'status': status,
      if (rejectionReason != null && rejectionReason.isNotEmpty)
        'rejection_reason': rejectionReason,
    });
  }

  Future<void> setUserRole(int userId, String role) async {
    await _api.patch('/users/$userId/role', {'role': role});
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final data = await _api.post('/users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Soft-remove a member (blocks login, hides from active list).
  Future<void> removeMember(int userId, {String? removalReason}) async {
    await _api.patch('/admin/members/$userId/remove', {
      if (removalReason != null && removalReason.isNotEmpty) 'removal_reason': removalReason,
    });
  }

  /// Pending/approved/rejected member registrations for admin approval workflow.
  Future<List<Map<String, dynamic>>> memberRegistrations({String status = 'pending'}) async {
    final data = await _api.get('/admin/registrations/members?status=$status');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  /// Pending/approved/rejected organization registrations.
  Future<List<Map<String, dynamic>>> organizationRegistrations({String status = 'pending'}) async {
    final data = await _api.get('/admin/registrations/organizations?status=$status');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> approveMemberRegistration(int userId) async {
    await _api.post('/admin/registrations/members/$userId/approve', {});
  }

  Future<void> rejectMemberRegistration(int userId, String rejectionReason) async {
    await _api.post('/admin/registrations/members/$userId/reject', {
      'rejection_reason': rejectionReason,
    });
  }

  Future<void> approveOrganizationRegistration(int userId) async {
    await _api.post('/admin/registrations/organizations/$userId/approve', {});
  }

  Future<void> rejectOrganizationRegistration(int userId, String rejectionReason) async {
    await _api.post('/admin/registrations/organizations/$userId/reject', {
      'rejection_reason': rejectionReason,
    });
  }

  Future<List<Map<String, dynamic>>> allServiceRequests() async {
    final data = await _api.get('/admin/service-requests');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> setRequestStatus(
    int requestId,
    String status, {
    String? rejectionReason,
  }) async {
    await _api.patch('/service-requests/$requestId', {
      'status': status,
      if (rejectionReason != null && rejectionReason.isNotEmpty)
        'rejection_reason': rejectionReason,
    });
  }

  /// Assign an approved member to a documentation request (creates task + calendar event).
  Future<Map<String, dynamic>> assignMemberToRequest(
    int requestId, {
    required int memberId,
    required String taskRole,
    String? adminNotes,
  }) async {
    final data = await _api.post('/admin/service-requests/$requestId/assign', {
      'member_id': memberId,
      'task_role': taskRole,
      if (adminNotes != null && adminNotes.isNotEmpty) 'admin_notes': adminNotes,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> allMedia() async {
    final data = await _api.get('/admin/media');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> allEvaluations() async {
    final data = await _api.get('/admin/evaluations');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> evaluationSummary() async {
    final data = await _api.get('/admin/evaluations/summary');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateEvaluationRemarks(int evaluationId, String remarks) async {
    final data = await _api.patch('/admin/evaluations/$evaluationId', {'admin_remarks': remarks});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> archiveEvaluatedMedia(int evaluationId) async {
    await _api.post('/admin/evaluations/$evaluationId/archive', {});
  }

  Future<void> deleteMedia(int mediaId) async {
    await _api.delete('/admin/media/$mediaId');
  }

  Future<List<Map<String, dynamic>>> allAiDetection() async {
    final data = await _api.get('/admin/ai-detection');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> aiDetectionSummary() async {
    final data = await _api.get('/admin/ai-detection/summary');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateAiDetectionReview(
    int id, {
    String? reviewStatus,
    String? adminRemarks,
  }) async {
    final data = await _api.patch('/admin/ai-detection/$id', {
      if (reviewStatus != null) 'review_status': reviewStatus,
      if (adminRemarks != null) 'admin_remarks': adminRemarks,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> archiveAiDetectionMedia(int id) async {
    await _api.post('/admin/ai-detection/$id/archive', {});
  }

  Future<List<Map<String, dynamic>>> allTasks() async {
    final data = await _api.get('/admin/tasks');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> allEvents() async {
    final data = await _api.get('/admin/events');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    final data = await _api.post('/admin/events', body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateEvent(int id, Map<String, dynamic> body) async {
    final data = await _api.patch('/admin/events/$id', body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteEvent(int id) async {
    await _api.delete('/admin/events/$id');
  }

  Future<List<Map<String, dynamic>>> aiReviewHistory(int aiId) async {
    final data = await _api.get('/admin/ai-detection/$aiId/history');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<Map<String, dynamic>>> allFeedback() async {
    final data = await _api.get('/admin/feedback');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> updateFeedbackAdminReview(
    int feedbackId, {
    String? adminResponse,
    String? reviewStatus,
  }) async {
    final body = <String, dynamic>{};
    if (adminResponse != null) body['admin_response'] = adminResponse;
    if (reviewStatus != null) body['review_status'] = reviewStatus;
    final data = await _api.patch('/admin/feedback/$feedbackId', body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> rankings() async {
    final data = await _api.get('/rankings');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> rankingsSummary() async {
    final data = await _api.get('/rankings/summary');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> updateRankingRemarks(int userId, String remarks) async {
    await _api.patch('/rankings/$userId/remarks', {'admin_remarks': remarks});
  }

  Future<Map<String, dynamic>> updateCompetencyLevel(
    int userId, {
    String? competencyLevel,
  }) async {
    final data = await _api.patch('/rankings/$userId/competency-level', {
      'competency_level': competencyLevel,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> myNotifications() async {
    final data = await _api.get('/notifications');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> markNotificationRead(int id) async {
    await _api.patch('/notifications/$id/read', {});
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post('/notifications/read-all', {});
  }

  Future<void> clearReadNotifications() async {
    await _api.delete('/notifications/read');
  }

  Future<List<Map<String, dynamic>>> allNotifications() async {
    final data = await _api.get('/admin/notifications');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<int> sendMemberAnnouncement({
    required String title,
    required String message,
    String audience = 'both',
  }) async {
    final data = await _api.post('/admin/notifications/broadcast', {
      'title': title,
      'message': message,
      'audience': audience,
    });
    final msg = (data as Map)['message'] as String? ?? '';
    final match = RegExp(r'(\d+)').firstMatch(msg);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  /// Log browser share (opens Facebook — no Page token).
  Future<void> logFacebookShareOpened({
    required int mediaId,
    String? message,
    String? shareUrl,
  }) async {
    await _api.post('/facebook/share/opened', {
      'media_id': mediaId,
      if (message != null && message.isNotEmpty) 'message': message,
      if (shareUrl != null && shareUrl.isNotEmpty) 'share_url': shareUrl,
    });
  }

  Future<Map<String, dynamic>> systemMonitor() async {
    final data = await _api.get('/admin/system-monitor');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getBranding() async {
    final data = await _api.get('/admin/branding');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadLogo({
    required List<int> bytes,
    required String fileName,
  }) async {
    final data = await _api.postMultipart(
      '/admin/branding/logo',
      fileBytes: bytes,
      fileName: fileName,
      fields: const {},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> resetLogo() async {
    final data = await _api.delete('/admin/branding/logo');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateBrandingNames({
    required String appName,
    required String tagline,
    required String shortTagline,
    required String organization,
  }) async {
    final data = await _api.patch('/admin/branding/names', {
      'app_name': appName,
      'tagline': tagline,
      'short_tagline': shortTagline,
      'organization': organization,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> resetBrandingNames() async {
    final data = await _api.delete('/admin/branding/names');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadMedia({
    required List<int> bytes,
    required String fileName,
    required int requestId,
    String? displayName,
  }) async {
    final row = await MediaUploadService.uploadMedia(
      client: _api,
      bytes: bytes,
      fileName: fileName,
      requestId: requestId,
      displayName: displayName,
      userId: authController.user?.id,
    );
    row['file_url'] = mediaUrl(row['file_url'] as String?);
    return row;
  }

  Future<String?> fetchGeminiDailySummary({
    required int pendingRequests,
    required int todayEvents,
    required int mediaPending,
    required int unreadNotifications,
    required int pendingMembers,
  }) async {
    try {
      final data = await _api.post('/ai/admin-daily-summary', {
        'pending_requests': pendingRequests,
        'today_events': todayEvents,
        'media_pending': mediaPending,
        'unread_notifications': unreadNotifications,
        'pending_members': pendingMembers,
      });
      if (data is! Map) return null;
      final summary = data['summary'];
      if (summary is String && summary.trim().isNotEmpty) return summary.trim();
      return null;
    } catch (_) {
      return null;
    }
  }
}

final adminApi = AdminApiService(apiClient);
