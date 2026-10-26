import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/models/reschedule_models.dart';
import 'package:access_mobile/shared/themes/theme.dart';

// ── Models ────────────────────────────────────────────────────────────────────

// ── Pipeline result models ────────────────────────────────────────────────────

enum RiskLevel { low, medium, high }

class QualityMetrics {
  final double blur;        // 0–1 (1 = sharp)
  final double lighting;    // 0–1
  final double resolution;  // 0–1
  final double composition; // 0–1
  final double overall;     // weighted average
  const QualityMetrics({
    required this.blur, required this.lighting,
    required this.resolution, required this.composition,
    required this.overall,
  });
}

class AiDetectionResult {
  final bool isAiGenerated;
  final double confidence;   // 0–1
  final String method;       // e.g. "ResNet50 + metadata"
  const AiDetectionResult({
    required this.isAiGenerated,
    required this.confidence,
    required this.method,
  });
}

class PipelineResult {
  final QualityMetrics quality;
  final AiDetectionResult aiDetection;
  final double finalScore;       // 0–1 weighted
  final RiskLevel riskLevel;
  final String skillBadge;       // Novice / Beginner / Intermediate / Advanced / Expert / Master
  final String gemindiFeedback;  // Gemini-generated feedback text
  final bool pendingAdminReview; // true if high risk
  const PipelineResult({
    required this.quality,
    required this.aiDetection,
    required this.finalScore,
    required this.riskLevel,
    required this.skillBadge,
    required this.gemindiFeedback,
    required this.pendingAdminReview,
  });
}

class Evaluation {
  final String id, title, composition, lighting, sharpness, feedback, date;
  final double score;
  final List<Uint8List> images;
  final String? imageUrl;
  final PipelineResult? pipeline;
  final List<CriterionScore> criteria;
  final String? qualityLevel;
  final String? mediaType;
  final MediaEvaluationFeedback? geminiFeedback;
  final String? recommendation;
  final String? scoringModel;
  final PhotoEvaluationResult? parsedEvaluation;
  final String? reviewStatus;
  final String? adminRemarks;
  final DateTime? evaluatedAt;
  final bool isAnalysisInProgress;
  final bool storageRemoved;
  Evaluation({
    required this.id,
    required this.title,
    required this.score,
    required this.composition,
    required this.lighting,
    this.sharpness = '—',
    required this.feedback,
    required this.date,
    this.images = const [],
    this.imageUrl,
    this.pipeline,
    this.criteria = const [],
    this.qualityLevel,
    this.mediaType,
    this.geminiFeedback,
    this.recommendation,
    this.scoringModel,
    this.parsedEvaluation,
    this.reviewStatus,
    this.adminRemarks,
    this.evaluatedAt,
    this.isAnalysisInProgress = false,
    this.storageRemoved = false,
  });

  int? get practiceMediaId {
    const prefix = 'MED-';
    if (!id.startsWith(prefix)) return null;
    return int.tryParse(id.substring(prefix.length));
  }

  bool get canRemovePracticeStorage =>
      !storageRemoved &&
      !isAnalysisInProgress &&
      practiceMediaId != null &&
      !isPending;

  bool get isPending => score == 0 && !isAnalysisInProgress;

  bool get hasAdminReviewDecision {
    return MemberReviewStatus.isFinalAdminDecision(reviewStatus);
  }

  bool get isUnderAdminReview {
    final status = reviewStatus?.toLowerCase();
    return status == 'pending_review' || status == 'needs_further_review';
  }

  /// DB stores 0–1; older payloads may store 1–5 in criteria_json only.
  double get displayScore => score <= 1.0 ? score : (score / 5).clamp(0.0, 1.0);

  int get displayPercent => (displayScore * 100).round();

  bool get hasAiCriteria => criteria.isNotEmpty;

  bool get isEfficientNetEvaluation =>
      scoringModel?.contains('efficientnet') == true || hasAiCriteria;

  List<CriterionScore> get previewCriteria {
    if (criteria.isEmpty) return const [];
    const priority = [
      'Sharpness',
      'Blur',
      'Noise',
      'Brightness',
      'Contrast',
      'Blocking Artifacts',
      'Ringing Artifacts',
      'Flickering',
      'Motion Stability',
    ];
    final sorted = [...criteria];
    sorted.sort((a, b) {
      final ai = priority.indexOf(a.name);
      final bi = priority.indexOf(b.name);
      final ar = ai < 0 ? 999 : ai;
      final br = bi < 0 ? 999 : bi;
      if (ar != br) return ar.compareTo(br);
      return a.name.compareTo(b.name);
    });
    return sorted.take(3).toList();
  }

  String get feedbackStatus =>
      feedback.trim().isEmpty ? 'Pending' : (isPending ? 'Awaiting review' : 'Ready');
}

class CalendarEvent {
  final int? id;
  final String tag;
  final String title;
  final String date;
  final String description;
  String status;
  final Color statusColor;
  final int? requestId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? timeLabel;
  final String location;
  final String? requestStatus;
  final String? assignedMemberName;
  final List<String> documentationTeam;

  CalendarEvent({
    this.id,
    required this.tag,
    required this.title,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.description,
    required this.startDate,
    this.endDate,
    this.requestId,
    this.timeLabel,
    this.location = '',
    this.requestStatus,
    this.assignedMemberName,
    this.documentationTeam = const [],
  });

  bool get isPast {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final day = DateTime(startDate.year, startDate.month, startDate.day);
    return day.isBefore(today);
  }

  bool get isApproved {
    final req = (requestStatus ?? '').toLowerCase();
    if (req.isNotEmpty) return req == 'approved';
    final s = status.toLowerCase();
    return s != 'cancelled' && s != 'canceled';
  }

  bool get isUpcoming => !isPast && isApproved;
}

class Challenge {
  final int? assignmentId;
  final int? requestId;
  final String title, description;
  final int xp;
  bool completed;
  String status;
  final String? taskRole;
  final String? venue;
  final String? eventDate;
  final String? eventTime;
  final String? eventTimeRange;
  Challenge({
    this.assignmentId,
    this.requestId,
    required this.title,
    required this.description,
    required this.xp,
    this.completed = false,
    this.status = 'assigned',
    this.taskRole,
    this.venue,
    this.eventDate,
    this.eventTime,
    this.eventTimeRange,
  });
}

enum MediaType { photo, video }

class GalleryItem {
  final String title, category, date;
  final Color color;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? videoPath;
  final String? networkUrl;
  final MediaType? mediaType;
  final bool aiDetected; // flagged as AI-generated
  final int? mediaId;
  final int? requestId;
  final double? overallScore;
  final String? feedback;
  final String? processingStatus;
  GalleryItem({
    required this.title,
    required this.category,
    required this.date,
    required this.color,
    this.imagePath,
    this.imageBytes,
    this.videoPath,
    this.networkUrl,
    this.mediaType,
    this.aiDetected = false,
    this.mediaId,
    this.requestId,
    this.overallScore,
    this.feedback,
    this.processingStatus,
  });

  bool get isVideo => mediaType == MediaType.video;

  bool get isAnalysisProcessing => processingStatus == 'processing';

  String get evalStatus {
    if (aiDetected) return 'Needs review';
    if (overallScore != null && overallScore! > 0) return 'Evaluated';
    if (feedback != null && feedback!.trim().isNotEmpty) return 'Evaluated';
    return 'Pending';
  }

  String? get scoreLabel {
    final s = overallScore;
    if (s == null || s <= 0) return null;
    final pct = s <= 1 ? (s * 100).round() : s.round();
    return '$pct%';
  }
}

class AppNotification {
  final int id;
  final String title, body;
  final IconData icon;
  final Color color;
  final String category;
  final String? actionType;
  final int? actionRefId;
  bool read;
  final String? createdAt;
  final DateTime? createdAtDt;
  AppNotification({
    this.id = 0,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.category = 'system_alert',
    this.actionType,
    this.actionRefId,
    this.read = false,
    this.createdAt,
    this.createdAtDt,
  });
}

class Announcement {
  final int id;
  final String title;
  final String content;
  final String date;
  final String? postedByName;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.postedByName,
  });

  String get preview {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 140) return cleaned;
    return '${cleaned.substring(0, 137)}…';
  }
}

class Member {
  final int? userId;
  final String name, rank, initials;
  final int uploads;          // total uploads
  final int goodEvaluations;  // total XP / points from member_rankings
  final int monthlyPoints;    // XP earned this calendar month
  final int evaluationCount;  // scored practice evaluations
  final int? rankPosition;
  final double avgMediaScore;
  final Color avatarColor;
  final String? profileImageUrl;
  Member({
    this.userId,
    required this.name,
    required this.rank,
    required this.initials,
    required this.uploads,
    required this.goodEvaluations,
    this.monthlyPoints = 0,
    this.evaluationCount = 0,
    this.rankPosition,
    this.avgMediaScore = 0,
    required this.avatarColor,
    this.profileImageUrl,
  });

  /// XP used for leaderboard display (all-time or monthly).
  int xpForPeriod({required bool monthly}) =>
      monthly ? monthlyPoints : goodEvaluations;

  BadgeInfo get badge => memberBadge(goodEvaluations);

  /// Photographer title earned from evaluation quality (3+ evaluations required).
  String? get achievedTitle {
    if (evaluationCount < 3) return null;
    final avg = avgMediaScore <= 1.0
        ? avgMediaScore
        : (avgMediaScore / 5.0).clamp(0.0, 1.0);
    return computeTitle(avg, evaluationCount);
  }

  /// Subtitle under member name on rankings (title if earned, else competency level).
  String get rankingsRoleLabel => achievedTitle ?? rank;
}

class EventFeedback {
  final String eventTitle, type, message, date;
  final int rating; // 1–5
  final int? requestId;
  final String? adminResponse;
  final String reviewStatus;
  EventFeedback({
    required this.eventTitle,
    required this.type,
    required this.message,
    required this.rating,
    required this.date,
    this.requestId,
    this.adminResponse,
    this.reviewStatus = 'pending',
  });
}

class Achievement {
  final String title, description;
  final IconData icon;
  final Color color;
  final String date;
  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.date,
  });
}

// ── Badge system (based on number of good evaluations, score ≥ 0.70) ──────────
// 0        → Novice       ⚪
// 1–2      → Beginner     🟤
// 3–5      → Intermediate 🟡
// 6–9      → Advanced     🟢
// 10–14    → Expert       🔵
// 15+      → Master       🟣

class BadgeInfo {
  final String label;
  final String emoji;
  final Color color;
  const BadgeInfo(this.label, this.emoji, this.color);
}

/// Computes a photographer title based on average score and number of evaluations.
/// Requires at least 3 evaluations. Title reflects overall quality.
///
/// avg ≥ 0.90 → Master Photographer
/// avg ≥ 0.80 → Expert Photographer
/// avg ≥ 0.70 → Senior Documenter
/// avg ≥ 0.60 → Documenter
/// avg ≥ 0.50 → Junior Documenter
/// avg <  0.50 → Apprentice
///
/// With 5+ evaluations, "Senior" prefix is added to mid-tier titles.
String computeTitle(double avgScore, int evalCount) {
  final senior = evalCount >= 5;
  if (avgScore >= 0.90) return 'Master Photographer';
  if (avgScore >= 0.80) return 'Expert Photographer';
  if (avgScore >= 0.70) return senior ? 'Senior Documenter' : 'Documenter';
  if (avgScore >= 0.60) return senior ? 'Senior Photographer' : 'Photographer';
  if (avgScore >= 0.50) return 'Junior Documenter';
  return 'Apprentice';
}

BadgeInfo memberBadge(int goodEvals) {
  if (goodEvals >= 15) return const BadgeInfo('Master',       '🟣', Color(0xFF6B21E8));
  if (goodEvals >= 10) return const BadgeInfo('Expert',       '🔵', Color(0xFF3B82F6));
  if (goodEvals >= 6)  return const BadgeInfo('Advanced',     '🟢', Color(0xFF22C55E));
  if (goodEvals >= 3)  return const BadgeInfo('Intermediate', '🟡', Color(0xFFF59E0B));
  if (goodEvals >= 1)  return const BadgeInfo('Beginner',     '🟤', Color(0xFFCD7C2F));
  return                const BadgeInfo('Novice',        '⚪', Color(0xFF94A3B8));
}

class ServiceRequest {
  final String id;
  final int? requestId;
  final String eventName;
  final String? description;
  final DateTime eventDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? requirements;
  final DateTime? submissionDate;
  final DateTime? updatedAt;
  final String requesterName;
  final String requestType;
  String status;
  final String? rejectionReason;
  final DateTime? originalEventDate;
  final DateTime? lastRescheduledAt;
  final List<RescheduleHistoryEntry> rescheduleHistory;

  ServiceRequest({
    required this.id,
    required this.eventName,
    required this.eventDate,
    required this.requesterName,
    this.requestId,
    this.description,
    this.startTime,
    this.endTime,
    this.location,
    this.requirements,
    this.submissionDate,
    this.updatedAt,
    this.requestType = 'Documentation',
    this.status = 'Pending',
    this.rejectionReason,
    this.originalEventDate,
    this.lastRescheduledAt,
    this.rescheduleHistory = const [],
  });

  /// Legacy alias used by older requestor UI code.
  String get type => requestType;

  /// Legacy alias — event description text.
  String get details => description ?? '';

  /// Legacy alias — formatted event date.
  String get date => _legacyFormatDate(eventDate);

  RequestStatus get requestStatus => RequestStatus.fromLegacyLabel(status);

  static String _legacyFormatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Pending registration ──────────────────────────────────────────────────────
enum RegistrationStatus { pending, approved, rejected }

class PendingUser {
  final String name, email, password, role;
  RegistrationStatus status;
  PendingUser({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.status = RegistrationStatus.pending,
  });
}

// ── App State ─────────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  AppState() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    if (raw == null) return;
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  // Populated from PostgreSQL after login via MemberDataController.refreshAll().
  final List<Evaluation> evaluations = [];
  /// Campus / All Events scope (public fields from API).
  final List<CalendarEvent> events = [];
  /// My Assignments or My Requests scope (private fields from API).
  final List<CalendarEvent> myCalendarEvents = [];
  final List<Challenge> challenges = [];
  /// Member AI evaluation uploads (EfficientNet-B0). Not event gallery media.
  final List<GalleryItem> gallery = [];
  /// Approved ACCESS event/documentation media from GET /api/gallery.
  final List<EventGalleryMedia> eventGallery = [];
  final List<AppNotification> notifications = [];
  final List<Announcement> announcements = [];

  int get unreadCount => notifications.where((n) => !n.read).length;

  void markAllRead() {
    for (final n in notifications) n.read = true;
    notifyListeners();
  }

  void toggleChallenge(int i) {
    challenges[i].completed = !challenges[i].completed;
    notifyListeners();
  }

  void updateEventStatus(int i, String status) {
    events[i].status = status;
    notifyListeners();
  }

  void submitRequest(String type, String details) {
    notifications.insert(0, AppNotification(
      title: 'Request Submitted',
      body: '$type: $details',
      icon: Icons.send,
      color: kBlue,
    ));
    notifyListeners();
  }

  void addGalleryItem(GalleryItem item) {
    // Run AI detection on the image bytes
    final detected = item.imageBytes != null ? _detectAiGallery(item.imageBytes!) : false;
    gallery.insert(0, GalleryItem(
      title: item.title, category: item.category, date: item.date,
      color: item.color, imagePath: item.imagePath, imageBytes: item.imageBytes,
      videoPath: item.videoPath, mediaType: item.mediaType,
      aiDetected: detected,
    ));
    notifyListeners();
  }

  /// High-sensitivity multi-signal AI detection for gallery uploads.
  static bool _detectAiGallery(Uint8List bytes) {
    if (bytes.length < 100) return false;
    final sampleSize = bytes.length.clamp(0, 8000);
    final sample = bytes.sublist(0, sampleSize);
    int aiSignals = 0;

    // Signal 1: Low variance
    double mean = 0;
    for (final b in sample) mean += b;
    mean /= sample.length;
    double variance = 0;
    for (final b in sample) variance += (b - mean) * (b - mean);
    variance /= sample.length;
    if (variance < 2500) aiSignals++;

    // Signal 2: No sensor noise
    int smallDiffs = 0;
    for (int i = 1; i < min(sample.length, 2000); i++) {
      if ((sample[i] - sample[i - 1]).abs() < 4) smallDiffs++;
    }
    if (smallDiffs / min(sample.length - 1, 1999) > 0.60) aiSignals++;

    // Signal 3: Mid-range pixel clustering
    int midRange = 0;
    for (final b in sample) {
      if (b >= 90 && b <= 190) midRange++;
    }
    if (midRange / sample.length > 0.45) aiSignals++;

    // Signal 4: File size heuristic
    if (bytes.length < 200000) aiSignals++;

    // 1 signal is enough — super sensitive
    return aiSignals >= 1;
  }

  void addEvaluation(Evaluation ev) {
    evaluations.insert(0, ev);
    notifications.insert(0, AppNotification(
      title: 'Photos Submitted',
      body: '${ev.title} — ${ev.images.length} photo(s) uploaded. Pending officer review.',
      icon: Icons.photo_camera,
      color: kCyan,
    ));
    notifyListeners();
  }

  /// Practice evaluations used today (from GET /member/participation).
  int evaluationsTodayCount = 0;

  /// Daily cap for practice evaluations (from system settings via API).
  int dailyEvaluationLimit = 5;

  /// Max file size for practice evaluation videos (from GET /member/participation).
  int evaluationMaxUploadMb = 350;

  /// Max length for practice evaluation videos (seconds).
  int evaluationMaxVideoSeconds = 30;

  /// IANA timezone for daily practice cap (from GET /member/participation).
  String evaluationDailyTimezone = 'Asia/Manila';

  int get evaluationsRemainingToday =>
      (dailyEvaluationLimit - evaluationsTodayCount).clamp(0, dailyEvaluationLimit);

  final List<EventFeedback> feedbacks = [];

  void submitEventFeedback(EventFeedback fb) {
    feedbacks.insert(0, fb);
    notifications.insert(0, AppNotification(
      title: 'Feedback Submitted',
      body: '${fb.type} on "${fb.eventTitle}" — thank you!',
      icon: Icons.chat_bubble_outline,
      color: kAccent,
    ));
    notifyListeners();
  }

  final List<ServiceRequest> serviceRequests = [];

  /// Replaces the in-memory list from API data (called after fetching
  /// `/api/service-requests` from PostgreSQL).
  void setServiceRequests(List<ServiceRequest> rows) {
    serviceRequests
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  int _reqCounter = 3;

  // ── Registration queue ──────────────────────────────────────────────────────
  final List<PendingUser> pendingUsers = [];

  /// Register a new user — they must wait for admin approval.
  void registerUser(PendingUser user) {
    pendingUsers.add(user);
    notifications.insert(0, AppNotification(
      title: 'New Registration',
      body: '${user.name} (${user.role}) has requested an account.',
      icon: Icons.person_add_outlined,
      color: kAccent,
    ));
    notifyListeners();
  }

  /// Check registration status for an email.
  RegistrationStatus? registrationStatus(String email) {
    final match = pendingUsers.where(
      (u) => u.email.toLowerCase() == email.toLowerCase()).firstOrNull;
    return match?.status;
  }

  void addServiceRequest(String type, String details, String requesterName) {
    final now = DateTime.now();
    serviceRequests.insert(0, ServiceRequest(
      id: 'REQ-${_reqCounter.toString().padLeft(3, '0')}',
      eventName: type,
      description: details,
      eventDate: now,
      submissionDate: now,
      requesterName: requesterName,
    ));
    _reqCounter++;
    notifications.insert(0, AppNotification(
      title: 'Request Submitted',
      body: '$type request is now pending review.',
      icon: Icons.send, color: kAccent,
    ));
    notifyListeners();
  }

  bool isSyncingMemberData = false;
  String? memberSyncError;

  // Current logged-in user profile (updated from API after login)
  String profileName = '';
  String profileInitials = '';
  String profileEmail = '';
  String? profileContactNumber;
  String? profileStudentId;
  String? profileImageUrl;
  String profileAccountRole = 'Member';
  String profileStatus = 'approved';
  String profileYear = 'ACCESS Member';
  int profileUploads = 0;
  Color profileColor = const Color(0xFF3B82F6);
  String? profileSkillLevel;
  /// Composite skill score 0–100 from rankings API (quality + integrity).
  double? profileSkillScore;
  int profilePoints = 0;
  int? profileRankPosition;
  int profileAssignmentsCompleted = 0;
  double profileAverageScore = 0;
  int profileEvaluationsCount = 0;
  String? profileAdminRemarks;

  /// Clears cached member profile (e.g. on logout) so the next user never sees stale data.
  void clearMemberProfile() {
    notifications.clear();
    profileName = '';
    profileInitials = '';
    profileEmail = '';
    profileContactNumber = null;
    profileStudentId = null;
    profileImageUrl = null;
    profileAccountRole = 'Member';
    profileStatus = 'approved';
    profileYear = 'ACCESS Member';
    profileUploads = 0;
    profileSkillLevel = null;
    profileSkillScore = null;
    profilePoints = 0;
    profileRankPosition = null;
    profileAssignmentsCompleted = 0;
    profileAverageScore = 0;
    profileEvaluationsCount = 0;
    profileAdminRemarks = null;
    evaluationsTodayCount = 0;
    dailyEvaluationLimit = 5;
    evaluationMaxUploadMb = 350;
    evaluationMaxVideoSeconds = 30;
    evaluationDailyTimezone = 'Asia/Manila';
    notifyListeners();
  }

  static const Object _profileImageUnset = Object();

  void applyProfile({
    required String name,
    required String email,
    int? uploads,
    String? skillLevel,
    int? points,
    int? rankPosition,
    String? contactNumber,
    String? studentId,
    Object? profileImage = _profileImageUnset,
    String? role,
    String? status,
  }) {
    profileName = name;
    profileEmail = email;
    profileContactNumber = contactNumber;
    profileStudentId = studentId;
    if (profileImage != _profileImageUnset) {
      final url = profileImage is String ? profileImage.trim() : '';
      profileImageUrl = url.isNotEmpty ? url : null;
    }
    profileAccountRole = role?.trim() ?? '';
    profileStatus = status?.trim() ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    profileInitials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts.first[0].toUpperCase() : '?');
    if (uploads != null) profileUploads = uploads;
    profileSkillLevel = skillLevel;
    if (points != null) profilePoints = points;
    profileRankPosition = rankPosition;
    profileYear = skillLevel != null ? 'Skill: $skillLevel' : 'ACCESS Member';
    notifyListeners();
  }

  void applyParticipation({
    int? assignmentsCompleted,
    double? averageScore,
    int? uploadsCount,
    int? totalPoints,
    int? evaluationsCount,
    int? evaluationsToday,
    int? dailyEvaluationLimit,
    int? evaluationMaxUploadMb,
    int? evaluationMaxVideoSeconds,
    String? evaluationDailyTimezone,
  }) {
    if (assignmentsCompleted != null) {
      profileAssignmentsCompleted = assignmentsCompleted;
    }
    if (averageScore != null) profileAverageScore = averageScore;
    if (uploadsCount != null) profileUploads = uploadsCount;
    if (totalPoints != null) profilePoints = totalPoints;
    if (evaluationsCount != null) profileEvaluationsCount = evaluationsCount;
    if (evaluationsToday != null) evaluationsTodayCount = evaluationsToday;
    if (dailyEvaluationLimit != null) this.dailyEvaluationLimit = dailyEvaluationLimit;
    if (evaluationMaxUploadMb != null) this.evaluationMaxUploadMb = evaluationMaxUploadMb;
    if (evaluationMaxVideoSeconds != null) {
      this.evaluationMaxVideoSeconds = evaluationMaxVideoSeconds;
    }
    if (evaluationDailyTimezone != null && evaluationDailyTimezone.trim().isNotEmpty) {
      this.evaluationDailyTimezone = evaluationDailyTimezone.trim();
    }
    notifyListeners();
  }

  /// Points from member_rankings (synced from API) or local good evaluations.
  int get profileGoodEvaluations =>
    profilePoints > 0
        ? profilePoints
        : evaluations.where((e) => e.score >= 0.70).length;

  /// Title is earned after 3–5 evaluations; based on average score quality.
  /// Returns null if fewer than 3 evaluations have been completed.
  String? get profileTitle {
    final scored = evaluations.where((e) => e.score > 0).toList();
    if (scored.length < 3) return null; // not yet earned
    final avg = scored.fold(0.0, (s, e) => s + e.score) / scored.length;
    return computeTitle(avg, scored.length);
  }

  /// Role shown on profile — earned title if available, otherwise 'Unranked'
  String get profileRole {
    return profileTitle ?? 'Unranked';
  }

  BadgeInfo get profileBadge => memberBadge(profileGoodEvaluations);

  int get profileRank {
    if (profileRankPosition != null && profileRankPosition! > 0) {
      return profileRankPosition!;
    }
    final sorted = [...members]..sort((a, b) => b.goodEvaluations.compareTo(a.goodEvaluations));
    final i = sorted.indexWhere((m) => m.name == profileName);
    return i < 0 ? sorted.length + 1 : i + 1;
  }

  /// Profile stat label: skill-based rank after `/rankings` sync, else DB XP rank.
  String get profileRankStatLabel =>
      profileSkillScore != null ? 'Skill rank' : 'XP rank';

  /// Earned photographer title for display (not the backend skill tier).
  String get profileTitleLabel {
    final title = profileTitle;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    return 'Not earned yet';
  }

  /// Rank within the current monthly XP leaderboard.
  int profileMonthlyRank(List<Member> monthlySorted, {int? userId}) {
    if (userId != null) {
      final i = monthlySorted.indexWhere((m) => m.userId == userId);
      if (i >= 0) return i + 1;
    }
    final i = monthlySorted.indexWhere((m) => m.name == profileName);
    return i < 0 ? monthlySorted.length + 1 : i + 1;
  }

  final List<Achievement> achievements = [];
  final List<Member> members = [];
}

final appState = AppState();
