import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/models/app_notification_mapper.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_milestone_celebration.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/models/member_milestone.dart';
import 'package:access_mobile/shared/models/media_upload_response.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/practice_evaluation_save_outcome.dart';
import 'package:access_mobile/shared/services/deferred_media_evaluation_poll.dart';
import 'package:access_mobile/shared/services/pending_practice_evaluation_store.dart';
import 'package:access_mobile/shared/services/push_notification_service.dart';
import 'package:access_mobile/mobile_app/requestor/requestor_feedback_status.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/models/reschedule_models.dart';
import 'package:access_mobile/shared/themes/theme.dart';

String _nonEmptyProfileName(Object? apiName, String sessionName) {
  final fromApi = apiName is String ? apiName.trim() : '';
  if (fromApi.isNotEmpty) return fromApi;
  final fromSession = sessionName.trim();
  return fromSession.isNotEmpty ? fromSession : 'Member';
}

class MemberDataController extends ChangeNotifier {
  bool isLoading = false;
  bool profileLoaded = false;
  bool profileLoadAttempted = false;
  String? profileLoadError;
  String? error;
  int? defaultRequestId;

  /// Event gallery (approved documentation media) sync state.
  bool eventGalleryLoading = false;
  String? eventGalleryError;
  bool eventGalleryLoaded = false;

  /// Rankings leaderboard sync state.
  bool rankingsLoading = false;
  String? rankingsError;

  /// Completed documentation requests with event feedback submitted (requestor org user).
  Set<int> requestorEventFeedbackRequestIds = {};

  /// Completed requests that have rateable team assignments.
  Set<int> requestorTeamRequiredRequestIds = {};

  /// Subset of [requestorTeamRequiredRequestIds] with all members rated.
  Set<int> requestorTeamCompleteRequestIds = {};

  RequestorFeedbackCompletion get requestorFeedbackCompletion =>
      RequestorFeedbackCompletion(
        eventFeedbackRequestIds: requestorEventFeedbackRequestIds,
        teamRequiredRequestIds: requestorTeamRequiredRequestIds,
        teamCompleteRequestIds: requestorTeamCompleteRequestIds,
      );

  /// Requestor ratings left for this member (documentation team only).
  List<Map<String, dynamic>> requestorRatings = [];
  int requestorRatingCount = 0;
  double? requestorRatingAverage;
  bool requestorRatingsLoaded = false;
  String? requestorRatingsLoadError;

  List<MemberMilestone> memberMilestones = [];
  List<MemberMilestone> unacknowledgedMilestones = [];

  /// Per-tab lazy load flags (avoid blocking home on every endpoint).
  bool evaluationsTabLoading = false;
  bool calendarTabLoading = false;
  bool galleryTabLoading = false;
  bool evaluationsTabSynced = false;
  String? calendarTabError;
  String? evaluationsTabError;
  bool calendarTabSynced = false;

  Future<void>? _evaluationsTabFuture;
  Future<void>? _calendarTabFuture;
  Future<void>? _galleryTabFuture;
  Future<void>? _rankingsTabFuture;
  Future<void>? _requestorExtrasFuture;

  Future<bool> _clearSessionIfUnauthorized(Object e) async {
    if (e is! ApiException || !e.shouldEndSession) return false;
    if (e.code == 'rejected' || e.code == 'removed') {
      authController.setSessionEndMessage(e.message);
    }
    await authController.logout();
    return true;
  }

  /// Clears in-flight sync flags when the member signs out.
  void resetForLogout() {
    isLoading = false;
    profileLoaded = false;
    profileLoadAttempted = false;
    profileLoadError = null;
    requestorRatings = [];
    requestorRatingCount = 0;
    requestorRatingAverage = null;
    requestorRatingsLoaded = false;
    requestorRatingsLoadError = null;
    requestorEventFeedbackRequestIds = {};
    requestorTeamRequiredRequestIds = {};
    requestorTeamCompleteRequestIds = {};
    memberMilestones = [];
    unacknowledgedMilestones = [];
    _bootstrapFuture = null;
    _pendingPracticeResumeFuture = null;
    pendingPracticeAnalysisCount = 0;
    appState.isSyncingMemberData = false;
    appState.memberSyncError = null;
  }

  static const int _eventGalleryPageSize = 100;
  static const int _eventGalleryPreviewSize = 30;
  static const int _eventGalleryMaxPages = 50;

  Future<void>? _eventGalleryRefreshFuture;
  Future<void>? _deferredSyncFuture;
  Future<void>? _pendingPracticeResumeFuture;

  /// Uploads waiting on server-side AI / integrity pipeline.
  int pendingPracticeAnalysisCount = 0;

  /// True when boot loaded only the first event-gallery page; Gallery tab fetches the rest.
  bool eventGalleryPreviewOnly = false;

  /// Reloads only `/member/profile` — used by the Profile tab error Retry action.
  Future<void> refreshProfile() async {
    if (!authController.isLoggedIn) return;
    profileLoadAttempted = true;
    profileLoadError = null;
    isLoading = true;
    notifyListeners();

    try {
      final profile = await memberApiService.getProfile();
      final imagePath = profile['profile_image'] as String?;
      final imageUrl = imagePath != null && imagePath.trim().isNotEmpty
          ? memberApiService.mediaUrl(imagePath.trim())
          : null;
      appState.applyProfile(
        name: profile['name'] as String? ?? authController.user!.name,
        email: profile['email'] as String? ?? authController.user!.email,
        uploads: profile['uploads_count'] as int? ?? 0,
        skillLevel: profile['skill_level'] as String?,
        points: profile['total_points'] as int? ?? 0,
        rankPosition: profile['rank_position'] as int?,
        contactNumber: profile['contact_number'] as String?,
        studentId: profile['student_id'] as String?,
        profileImage: imageUrl,
        role: profile['role'] as String?,
        status: profile['status'] as String?,
      );
      profileLoaded = true;
      profileLoadError = null;
      if (!_isOrganizationUser) {
        await _syncRequestorRatings();
      }
      appState.notifyListeners();
    } catch (e) {
      if (await _clearSessionIfUnauthorized(e)) {
        profileLoadError = 'Session expired. Please sign in again';
      } else {
        profileLoadError =
            e.toString().replaceFirst('ApiException: ', '').trim();
        if (profileLoadError!.isEmpty) {
          profileLoadError = 'Unable to load profile';
        }
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Seed greeting from login session so home can paint before `/member/profile` returns.
  void seedHomeFromSession() {
    final user = authController.user;
    if (user == null) return;
    appState.applyProfile(name: user.name, email: user.email);
    profileLoadAttempted = true;
    notifyListeners();
  }

  Future<void>? _bootstrapFuture;

  /// Fast path after login: home-critical data first, heavier sections in background.
  Future<void> bootstrapMemberApp() {
    if (!authController.isLoggedIn) return Future.value();
    final inFlight = _bootstrapFuture;
    if (inFlight != null) return inFlight;

    final task = _bootstrapMemberAppImpl();
    _bootstrapFuture = task;
    return task.whenComplete(() {
      if (identical(_bootstrapFuture, task)) {
        _bootstrapFuture = null;
      }
    });
  }

  Future<void> _bootstrapMemberAppImpl() async {
    await PendingPracticeEvaluationStore.ensureLoaded();
    pendingPracticeAnalysisCount = PendingPracticeEvaluationStore.count;
    notifyListeners();
    await PushNotificationService.ensureRegistered();
    await PushNotificationService.syncInboxIfOpenedFromPush();
    await refreshHomeBootstrap();
    unawaited(resumePendingPracticeAnalysis());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PushNotificationService.flushPendingNotificationOpen());
    });
    unawaited(refreshDeferredSections());
  }

  bool get _isOrganizationUser =>
      authController.user?.role.isOrganization ?? false;

  /// Profile + home-critical data only. Other tabs load on first visit.
  Future<void> refreshHomeBootstrap() async {
    if (!authController.isLoggedIn) return;
    seedHomeFromSession();
    isLoading = true;
    profileLoadError = null;
    error = null;
    appState.memberSyncError = null;
    notifyListeners();

    final ctx = _MemberSyncContext();
    final homeSections = <(String, Future<void> Function())>[
      ('Profile', () => _syncProfileSection(ctx)),
      ('Participation', _syncParticipationSection),
      if (_isOrganizationUser)
        ('Service requests', _syncServiceRequestsSection)
      else
        ('Tasks', _syncTasksSection),
    ];

    await Future.wait(
      homeSections.map(
        (section) => _runSection(ctx, section.$1, section.$2).then((_) {
          notifyListeners();
          appState.notifyListeners();
        }),
      ),
    );

    _finalizeSync(ctx);
    isLoading = false;
    notifyListeners();
    appState.notifyListeners();

    unawaited(_syncHomeSecondarySections(ctx));
  }

  /// Loads data for a bottom-nav tab the first time it is opened.
  Future<void> ensureMemberTabData(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return ensureEvaluationsTab();
      case 2:
        return ensureCalendarTab();
      case 3:
        return ensureGalleryTab();
      case 5:
        return ensureRankingsTab();
      default:
        return Future.value();
    }
  }

  /// Requestor shell: calendar + gallery + feedback after home bootstrap.
  Future<void> ensureRequestorTabData(int tabIndex) {
    switch (tabIndex) {
      case 1: // calendar — campus schedule for planning only
        return ensureCalendarTab();
      case 2: // requests (center)
        if (appState.serviceRequests.isEmpty) {
          return refreshAll();
        }
        return Future.value();
      case 3: // gallery
        return ensureGalleryTab();
      case 4: // feedback
        return _ensureRequestorFeedbackTab();
      default:
        return Future.value();
    }
  }

  Future<void> ensureEvaluationsTab() {
    if (!authController.isLoggedIn) return Future.value();
    if (evaluationsTabSynced && evaluationsTabError == null) {
      unawaited(_syncEvaluationsTabLight());
      return Future.value();
    }
    final inFlight = _evaluationsTabFuture;
    if (inFlight != null) return inFlight;
    evaluationsTabLoading = true;
    evaluationsTabError = null;
    notifyListeners();
    Future<void>? owned;
    owned = _ensureEvaluationsTabImpl().whenComplete(() {
      evaluationsTabLoading = false;
      if (identical(_evaluationsTabFuture, owned)) {
        _evaluationsTabFuture = null;
      }
      notifyListeners();
    });
    _evaluationsTabFuture = owned;
    return owned;
  }

  /// Participation + evaluation list only (no full-tab loading state).
  Future<void> _syncEvaluationsTabLight() async {
    if (!authController.isLoggedIn) return;
    try {
      await Future.wait<void>([
        _syncParticipationSection(),
        _syncEvaluationsSection(),
        _syncEvaluationMediaSection(),
      ]);
      appState.notifyListeners();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _ensureEvaluationsTabImpl() async {
    final ctx = _MemberSyncContext();
    await _runSectionsParallel(ctx, [
      ('Participation', _syncParticipationSection),
      ('EvaluationMedia', _syncEvaluationMediaSection),
      ('Evaluations', _syncEvaluationsSection),
    ]);
    evaluationsTabError = _syncErrorFromContext(ctx);
    if (evaluationsTabError == null) {
      evaluationsTabSynced = true;
    }
    appState.notifyListeners();
  }

  Future<void> ensureCalendarTab() {
    if (!authController.isLoggedIn) return Future.value();
    if (appState.events.isNotEmpty && calendarTabError == null) {
      return Future.value();
    }
    if (calendarTabSynced && calendarTabError == null) {
      return Future.value();
    }
    final inFlight = _calendarTabFuture;
    if (inFlight != null) return inFlight;
    calendarTabLoading = true;
    calendarTabError = null;
    notifyListeners();
    Future<void>? owned;
    owned = _ensureCalendarTabImpl().whenComplete(() {
      calendarTabLoading = false;
      if (identical(_calendarTabFuture, owned)) {
        _calendarTabFuture = null;
      }
      notifyListeners();
    });
    _calendarTabFuture = owned;
    return owned;
  }

  Future<void> _ensureCalendarTabImpl() async {
    final ctx = _MemberSyncContext();
    await _runSectionsParallel(ctx, [
      ('Events', _syncEventsSection),
      if (appState.challenges.isEmpty) ('Tasks', _syncTasksSection),
    ]);
    calendarTabError = _syncErrorFromContext(ctx, sectionPrefix: 'Events');
    if (calendarTabError == null) {
      calendarTabSynced = true;
    }
    appState.notifyListeners();
  }

  Future<void> ensureGalleryTab() {
    if (!authController.isLoggedIn) return Future.value();
    if (eventGalleryLoaded && !eventGalleryPreviewOnly) {
      return refreshEventGallery(fullCatalog: true);
    }
    final inFlight = _galleryTabFuture;
    if (inFlight != null) return inFlight;
    galleryTabLoading = true;
    notifyListeners();
    Future<void>? owned;
    owned = refreshEventGallery(fullCatalog: true).whenComplete(() {
      galleryTabLoading = false;
      if (identical(_galleryTabFuture, owned)) {
        _galleryTabFuture = null;
      }
      notifyListeners();
    });
    _galleryTabFuture = owned;
    return owned;
  }

  Future<void> ensureRankingsTab() {
    if (!authController.isLoggedIn) return Future.value();
    if (appState.members.isNotEmpty) return Future.value();
    final inFlight = _rankingsTabFuture;
    if (inFlight != null) return inFlight;
    Future<void>? owned;
    owned = refreshRankings().whenComplete(() {
      if (identical(_rankingsTabFuture, owned)) {
        _rankingsTabFuture = null;
      }
    });
    _rankingsTabFuture = owned;
    return owned;
  }

  Future<void> _ensureRequestorFeedbackTab() {
    if (!authController.isLoggedIn) return Future.value();
    if (appState.feedbacks.isNotEmpty &&
        appState.serviceRequests.isNotEmpty) {
      return Future.value();
    }
    final inFlight = _requestorExtrasFuture;
    if (inFlight != null) return inFlight;
    Future<void>? owned;
    owned = _ensureRequestorFeedbackTabImpl().whenComplete(() {
      if (identical(_requestorExtrasFuture, owned)) {
        _requestorExtrasFuture = null;
      }
    });
    _requestorExtrasFuture = owned;
    return owned;
  }

  Future<void> _ensureRequestorFeedbackTabImpl() async {
    final ctx = _MemberSyncContext();
    await _runSectionsParallel(ctx, [
      if (appState.serviceRequests.isEmpty)
        ('Service requests', _syncServiceRequestsSection),
      ('Feedback', _syncFeedbackSection),
    ]);
    appState.notifyListeners();
    notifyListeners();
  }

  Future<void> _syncHomeSecondarySections(_MemberSyncContext ctx) async {
    await _runSectionsParallel(ctx, [
      ('Announcements', _syncAnnouncementsSection),
      ('Notifications', refreshNotifications),
      if (!_isOrganizationUser)
        ('Requestor ratings', refreshRequestorRatings),
    ]);
    notifyListeners();
    appState.notifyListeners();
  }

  /// Calendar, gallery preview, evaluations, rankings, requests, feedback (parallel).
  Future<void> refreshDeferredSections() {
    if (!authController.isLoggedIn) return Future.value();
    final inFlight = _deferredSyncFuture;
    if (inFlight != null) return inFlight;

    final task = _refreshDeferredSectionsImpl();
    _deferredSyncFuture = task;
    return task.whenComplete(() {
      if (identical(_deferredSyncFuture, task)) {
        _deferredSyncFuture = null;
      }
    });
  }

  Future<void> _refreshDeferredSectionsImpl() async {
    appState.isSyncingMemberData = true;
    notifyListeners();
    appState.notifyListeners();

    final ctx = _MemberSyncContext();
    await _runSectionsParallel(ctx, [
      ('Events', _syncEventsSection),
      ('EventGallery', () => refreshEventGallery(previewOnly: true)),
      ('EvaluationMedia', _syncEvaluationMediaSection),
      ('Evaluations', _syncEvaluationsSection),
      ('Rankings', _syncRankingsSection),
      ('Service requests', _syncServiceRequestsSection),
      if (_isOrganizationUser) ('Feedback', _syncFeedbackSection),
      if (!_isOrganizationUser) ('Requestor ratings', refreshRequestorRatings),
    ]);

    if (ctx.sessionExpired) {
      error = 'Session expired. Please sign in again';
      appState.memberSyncError = null;
    }

    appState.isSyncingMemberData = false;
    notifyListeners();
    appState.notifyListeners();
  }

  /// Home tab pull-to-refresh: re-sync home data; heavier sections run in background.
  Future<void> refreshHomeTab() async {
    await refreshHomeBootstrap();
    if (!_isOrganizationUser) {
      unawaited(refreshRequestorRatings());
    }
  }

  /// Evaluations tab pull-to-refresh.
  Future<void> refreshEvaluationsTab() async {
    if (!authController.isLoggedIn) return;
    evaluationsTabLoading = true;
    evaluationsTabError = null;
    notifyListeners();
    try {
      final ctx = _MemberSyncContext();
      await _runSectionsParallel(ctx, [
        ('Participation', _syncParticipationSection),
        ('EvaluationMedia', _syncEvaluationMediaSection),
        ('Evaluations', _syncEvaluationsSection),
      ]);
      evaluationsTabError = _syncErrorFromContext(ctx);
      if (evaluationsTabError == null) {
        evaluationsTabSynced = true;
      }
      appState.notifyListeners();
    } finally {
      evaluationsTabLoading = false;
      notifyListeners();
    }
    unawaited(resumePendingPracticeAnalysis());
  }

  /// Calendar tab pull-to-refresh.
  Future<void> refreshCalendarTab() async {
    if (!authController.isLoggedIn) return;
    calendarTabLoading = true;
    calendarTabError = null;
    notifyListeners();
    try {
      final ctx = _MemberSyncContext();
      await _runSection(ctx, 'Events', _syncEventsSection);
      calendarTabError = _syncErrorFromContext(ctx, sectionPrefix: 'Events');
      if (calendarTabError == null) {
        calendarTabSynced = true;
      }
      appState.notifyListeners();
    } finally {
      calendarTabLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    if (!authController.isLoggedIn) return;
    isLoading = true;
    profileLoadAttempted = true;
    profileLoadError = null;
    error = null;
    appState.isSyncingMemberData = true;
    appState.memberSyncError = null;
    appState.profileImageUrl = null;
    await Future<void>.delayed(Duration.zero);
    notifyListeners();
    appState.notifyListeners();

    final ctx = _MemberSyncContext();
    await _runSectionsParallel(ctx, [
      ('Profile', () => _syncProfileSection(ctx)),
      ('Participation', _syncParticipationSection),
      ('Tasks', _syncTasksSection),
      ('Events', _syncEventsSection),
      ('EventGallery', () => refreshEventGallery(fullCatalog: true)),
      ('Notifications', refreshNotifications),
      ('Announcements', _syncAnnouncementsSection),
      ('EvaluationMedia', _syncEvaluationMediaSection),
      ('Evaluations', _syncEvaluationsSection),
      ('Rankings', _syncRankingsSection),
      ('Service requests', _syncServiceRequestsSection),
      if (_isOrganizationUser) ('Feedback', _syncFeedbackSection),
    ]);

    _finalizeSync(ctx);
    isLoading = false;
    appState.isSyncingMemberData = false;
    notifyListeners();
    appState.notifyListeners();
  }

  Future<void> _runSection(
    _MemberSyncContext ctx,
    String label,
    Future<void> Function() fn,
  ) async {
    if (ctx.sessionExpired) return;
    try {
      await fn();
    } catch (e) {
      if (await _clearSessionIfUnauthorized(e)) {
        ctx.sessionExpired = true;
        error = 'Session expired. Please sign in again';
        appState.memberSyncError = null;
        return;
      }
      ctx.warnings.add('$label: $e');
    }
  }

  String? _syncErrorFromContext(
    _MemberSyncContext ctx, {
    String? sectionPrefix,
  }) {
    if (ctx.sessionExpired) {
      return 'Session expired. Please sign in again';
    }
    for (final warning in ctx.warnings) {
      if (sectionPrefix != null && !warning.startsWith('$sectionPrefix:')) {
        continue;
      }
      var message = warning;
      if (sectionPrefix != null && warning.contains(': ')) {
        message = warning.substring(warning.indexOf(': ') + 2);
      }
      message = message.replaceFirst('ApiException: ', '').trim();
      if (message.isEmpty) {
        return sectionPrefix != null
            ? 'Unable to load ${sectionPrefix.toLowerCase()}'
            : 'Unable to load data';
      }
      return message;
    }
    return null;
  }

  Future<void> _runSectionsParallel(
    _MemberSyncContext ctx,
    List<(String, Future<void> Function())> sections,
  ) async {
    await Future.wait(
      sections.map((s) => _runSection(ctx, s.$1, s.$2)),
    );
  }

  void _finalizeSync(_MemberSyncContext ctx) {
    if (ctx.sessionExpired) {
      error = 'Session expired. Please sign in again';
      appState.memberSyncError = null;
      return;
    }
    if (!ctx.profileOk) {
      String? profileWarning;
      for (final w in ctx.warnings) {
        if (w.startsWith('Profile:')) {
          profileWarning = w.replaceFirst('Profile: ', '');
          break;
        }
      }
      profileLoadError = profileWarning ?? 'Unable to load profile';
      if (appState.evaluations.isEmpty &&
          appState.gallery.isEmpty &&
          appState.challenges.isEmpty) {
        error = ctx.warnings.isNotEmpty
            ? ctx.warnings.first
            : 'Unable to load data from server';
        appState.memberSyncError = error;
      } else {
        error = null;
        appState.memberSyncError = null;
      }
    } else {
      error = null;
      appState.memberSyncError = null;
    }
  }

  Future<void> _syncProfileSection(_MemberSyncContext ctx) async {
    final profile = await memberApiService.getProfile();
    final imagePath = profile['profile_image'] as String?;
    final imageUrl = imagePath != null && imagePath.trim().isNotEmpty
        ? memberApiService.mediaUrl(imagePath.trim())
        : null;
    appState.applyProfile(
      name: _nonEmptyProfileName(profile['name'], authController.user!.name),
      email: profile['email'] as String? ?? authController.user!.email,
      uploads: profile['uploads_count'] as int? ?? 0,
      skillLevel: profile['skill_level'] as String?,
      points: profile['total_points'] as int? ?? 0,
      rankPosition: profile['rank_position'] as int?,
      contactNumber: profile['contact_number'] as String?,
      studentId: profile['student_id'] as String?,
      profileImage: imageUrl,
      role: profile['role'] as String?,
      status: profile['status'] as String?,
    );
    ctx.profileOk = true;
    profileLoaded = true;
    if (!_isOrganizationUser) {
      await _syncRequestorRatings();
    }
  }

  /// Reloads requestor ratings for the logged-in documentation member.
  Future<void> refreshRequestorRatings() async {
    if (_isOrganizationUser) return;
    try {
      await _syncRequestorRatings();
      requestorRatingsLoadError = null;
      notifyListeners();
    } catch (_) {
      requestorRatingsLoadError = 'Unable to load requestor feedback';
      notifyListeners();
    }
  }

  Future<void> _syncRequestorRatings() async {
    final data = await memberApiService.getReceivedRequestorRatings();
    requestorRatingCount = data['count'] as int? ?? 0;
    requestorRatingAverage = (data['average_rating'] as num?)?.toDouble();
    final rows = data['ratings'];
    requestorRatings = rows is List
        ? rows.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];
    requestorRatingsLoaded = true;
    requestorRatingsLoadError = null;
  }

  Future<void> _syncParticipationSection() async {
    final participation = await memberApiService.getParticipation();
    appState.applyParticipation(
      uploadsCount: participation['uploads_count'] as int? ?? 0,
      assignmentsCompleted: participation['assignments_completed'] as int? ?? 0,
      averageScore: (participation['average_score'] as num?)?.toDouble() ?? 0,
      totalPoints: participation['total_points'] as int? ?? 0,
      evaluationsCount: participation['evaluations_count'] as int? ?? 0,
      evaluationsToday: participation['evaluations_today'] as int? ?? 0,
      dailyEvaluationLimit: participation['daily_evaluation_limit'] as int? ?? 5,
      evaluationMaxUploadMb: participation['evaluation_max_upload_mb'] as int? ?? 350,
      evaluationMaxVideoSeconds: participation['evaluation_max_video_seconds'] as int? ?? 30,
      evaluationDailyTimezone: participation['evaluation_daily_timezone'] as String? ?? 'Asia/Manila',
    );
  }

  Future<void> _syncTasksSection() async {
    final tasks = await memberApiService.getTasks();
    if (tasks.isNotEmpty) {
      defaultRequestId = tasks.first['request_id'] as int?;
    }
    appState.challenges
      ..clear()
      ..addAll(tasks.map((t) {
        final status = (t['status'] as String? ?? 'assigned').toLowerCase();
        final eventDateRaw = t['event_date'] as String?;
        final eventDt = eventDateRaw != null ? DateTime.tryParse(eventDateRaw) : null;
        final taskRole = t['task_role'] as String?;
        final startTime = t['start_time'] as String?;
        final endTime = t['end_time'] as String?;
        String? timeRange;
        if (startTime != null && startTime.isNotEmpty) {
          timeRange =
              endTime != null && endTime.isNotEmpty ? '$startTime – $endTime' : startTime;
        }
        return Challenge(
          assignmentId: t['id'] as int?,
          requestId: t['request_id'] as int?,
          title: t['request_title'] as String? ?? 'Task',
          description: '${taskRole ?? 'member'} · ${t['venue'] ?? 'TBA'}',
          xp: 150,
          completed: status == 'completed' || status == 'done',
          status: status,
          taskRole: taskRole,
          venue: t['venue'] as String?,
          eventDate: eventDt != null ? _formatEventDate(eventDt) : null,
          eventTime: timeRange ?? (eventDt != null ? _formatEventTime(eventDt) : null),
          eventTimeRange: timeRange,
        );
      }));
  }

  Future<void> _syncEventsSection() async {
    final events = await memberApiService.getEvents();
    appState.events
      ..clear()
      ..addAll(events.map(_calendarEventFromApi));
  }

  Future<void> _syncAnnouncementsSection() async {
    final rows = await memberApiService.getAnnouncements();
    appState.announcements
      ..clear()
      ..addAll(rows.map((a) => Announcement(
            id: a['id'] as int? ?? 0,
            title: a['title'] as String? ?? 'Announcement',
            content: a['content'] as String? ?? '',
            date: _formatIso(a['created_at'] as String?),
            postedByName: a['posted_by_name'] as String?,
          )));
  }

  Future<void> _syncEvaluationMediaSection() async {
    final media = await memberApiService.getMedia(
      mine: true,
      mediaCategory: 'member_evaluation',
    );
    appState.gallery
      ..clear()
      ..addAll(
        media
            .where((m) => m['storage_removed'] != true)
            .map(_galleryFromApi),
      );
  }

  Future<void> _syncEvaluationsSection() async {
    final evaluations = await memberApiService.getEvaluations();
    appState.evaluations
      ..clear()
      ..addAll(evaluations.map(_evaluationFromApi));
  }

  Future<void> _syncRankingsSection() async {
    rankingsLoading = true;
    rankingsError = null;
    notifyListeners();
    try {
      final rankings = await memberApiService.getRankings();
      _applyRankingsRows(rankings);
      appState.notifyListeners();
    } catch (e) {
      rankingsError = e.toString();
      rethrow;
    } finally {
      rankingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncServiceRequestsSection() async {
    final rows = await memberApiService.getServiceRequests();
    appState.setServiceRequests(rows.map(_serviceRequestFromApi).toList());
  }

  Future<void> _syncFeedbackSection() async {
    if (!_isOrganizationUser) return;
    final feedbacks = await memberApiService.getFeedback();
    requestorEventFeedbackRequestIds = {
      for (final f in feedbacks)
        if (_jsonInt(f['request_id']) != null) _jsonInt(f['request_id'])!,
    };
    appState.feedbacks
      ..clear()
      ..addAll(feedbacks.map(_feedbackFromApi));
    await _syncRequestorTeamRatingCompletion();
    notifyListeners();
  }

  /// Refreshes team-rating completion for recent completed requests (requestor only).
  Future<void> syncRequestorTeamRatingCompletion() async {
    if (!_isOrganizationUser) return;
    await _syncRequestorTeamRatingCompletion();
    notifyListeners();
  }

  Future<void> syncRequestorFeedbackCompletion() async {
    await _syncFeedbackSection();
    appState.notifyListeners();
  }

  Future<void> _syncRequestorTeamRatingCompletion() async {
    if (!_isOrganizationUser) return;
    final teamRequired = <int>{};
    final teamComplete = <int>{};
    final completed = appState.serviceRequests
        .where(
          (r) =>
              r.requestId != null && r.requestStatus == RequestStatus.completed,
        )
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    for (final r in completed.take(15)) {
      final rid = r.requestId!;
      try {
        final rows = await memberApiService.getAssignmentRatingTargets(rid);
        if (rows.isEmpty) continue;
        teamRequired.add(rid);
        final allRated = rows.every((row) {
          if (row['rated'] == true) return true;
          final rating = (row['rating'] as num?)?.toInt() ?? 0;
          return rating > 0;
        });
        if (allRated) teamComplete.add(rid);
      } catch (_) {
        // Non-blocking; picker falls back to per-request targets on open.
      }
    }
    requestorTeamRequiredRequestIds = teamRequired;
    requestorTeamCompleteRequestIds = teamComplete;
  }

  /// Reload in-app notifications only (`GET /notifications`).
  Future<void> refreshNotifications() async {
    if (!authController.isLoggedIn) return;
    final rows = await memberApiService.getNotifications();
    appState.notifications
      ..clear()
      ..addAll(rows.map(appNotificationFromApi));
    appState.notifyListeners();
  }

  /// Loads rankings when Profile needs skill score (no-op if already synced).
  Future<void> syncRankingsForProfileIfNeeded() async {
    if (!authController.isLoggedIn || _isOrganizationUser) return;
    if (appState.profileSkillScore != null) return;
    if (rankingsLoading) return;
    await refreshRankings(notify: true);
  }

  Future<void> refreshMilestones({bool unacknowledgedOnly = false}) async {
    if (!authController.isLoggedIn || _isOrganizationUser) return;
    try {
      final rows = await memberApiService.getMilestones(unacknowledgedOnly: unacknowledgedOnly);
      final parsed = rows.map(MemberMilestone.fromApi).where((m) => m.id > 0).toList();
      if (unacknowledgedOnly) {
        unacknowledgedMilestones = parsed;
      } else {
        memberMilestones = parsed;
        unacknowledgedMilestones =
            parsed.where((m) => !m.isAcknowledged).toList();
      }
      notifyListeners();
    } catch (_) {
      // Non-blocking; profile still works without milestones API.
    }
  }

  Future<void> acknowledgeMilestone(int milestoneId) async {
    if (milestoneId <= 0) return;
    await memberApiService.acknowledgeMilestone(milestoneId);
    unacknowledgedMilestones =
        unacknowledgedMilestones.where((m) => m.id != milestoneId).toList();
    memberMilestones = memberMilestones.map((m) {
      if (m.id != milestoneId) return m;
      return MemberMilestone(
        id: m.id,
        kind: m.kind,
        key: m.key,
        title: m.title,
        message: m.message,
        earnedAt: m.earnedAt,
        acknowledgedAt: DateTime.now(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> celebratePendingMilestones(BuildContext context) async {
    if (unacknowledgedMilestones.isEmpty) {
      await refreshMilestones(unacknowledgedOnly: true);
    }
    if (!context.mounted || unacknowledgedMilestones.isEmpty) return;
    final pending = [...unacknowledgedMilestones];
    await celebrateUnacknowledgedMilestones(
      context,
      milestones: pending,
      onAcknowledge: (m) => acknowledgeMilestone(m.id),
    );
  }

  /// Reloads the member leaderboard from `/api/rankings`.
  Future<void> refreshRankings({bool notify = true}) async {
    if (!authController.isLoggedIn) return;
    rankingsLoading = true;
    rankingsError = null;
    if (notify) {
      notifyListeners();
      appState.notifyListeners();
    }

    try {
      final rankings = await memberApiService.getRankings();
      _applyRankingsRows(rankings);
      rankingsError = null;
      appState.notifyListeners();
    } catch (e) {
      if (await _clearSessionIfUnauthorized(e)) {
        rankingsError = 'Session expired. Please sign in again';
      } else {
        rankingsError = e.toString().replaceFirst('ApiException: ', '');
      }
    } finally {
      rankingsLoading = false;
      notifyListeners();
      appState.notifyListeners();
    }
  }

  /// Loads approved event/documentation media for the member gallery (paginated).
  ///
  /// [previewOnly]: first page only (startup). [fullCatalog]: all pages (Gallery tab).
  Future<void> refreshEventGallery({
    bool previewOnly = false,
    bool fullCatalog = false,
  }) {
    if (!authController.isLoggedIn) {
      eventGalleryLoading = false;
      return Future.value();
    }
    final inFlight = _eventGalleryRefreshFuture;
    if (inFlight != null) return inFlight;

    final task = _refreshEventGalleryImpl(
      previewOnly: previewOnly,
      fullCatalog: fullCatalog,
    );
    _eventGalleryRefreshFuture = task;
    return task.whenComplete(() {
      if (identical(_eventGalleryRefreshFuture, task)) {
        _eventGalleryRefreshFuture = null;
      }
    });
  }

  Future<void> _refreshEventGalleryImpl({
    bool previewOnly = false,
    bool fullCatalog = false,
  }) async {
    eventGalleryLoading = true;
    eventGalleryError = null;
    if (fullCatalog) {
      eventGalleryPreviewOnly = false;
    } else if (previewOnly) {
      eventGalleryPreviewOnly = true;
    }
    notifyListeners();
    appState.notifyListeners();

    try {
      final rows = <Map<String, dynamic>>[];
      var offset = 0;
      var pages = 0;
      final maxPages = previewOnly ? 1 : _eventGalleryMaxPages;
      final pageSize =
          previewOnly ? _eventGalleryPreviewSize : _eventGalleryPageSize;
      while (pages < maxPages) {
        final page = await memberApiService.getEventGallery(
          limit: pageSize,
          offset: offset,
        );
        rows.addAll(page);
        pages++;
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      appState.eventGallery
        ..clear()
        ..addAll(rows.map(_eventGalleryFromApi).where((m) => m.requestId != null));
      eventGalleryError = null;
      if (fullCatalog || !previewOnly) {
        eventGalleryPreviewOnly = false;
      }
    } catch (e) {
      if (await _clearSessionIfUnauthorized(e)) {
        eventGalleryError = 'Session expired. Please sign in again';
      } else {
        eventGalleryError = e.toString().replaceFirst('ApiException: ', '');
      }
    } finally {
      eventGalleryLoading = false;
      eventGalleryLoaded = true;
      notifyListeners();
      appState.notifyListeners();
    }
  }

  Future<void> createServiceRequest({
    required String title,
    required String description,
    required DateTime eventDate,
    String? venue,
    String? startTime,
    String? endTime,
    String? requirements,
  }) async {
    await memberApiService.createServiceRequest({
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String().split('T').first,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
      if (startTime != null && startTime.isNotEmpty) 'start_time': startTime,
      if (endTime != null && endTime.isNotEmpty) 'end_time': endTime,
      if (requirements != null && requirements.isNotEmpty) 'requirements': requirements,
    });
    await refreshAll();
  }

  ServiceRequest serviceRequestFromApi(Map<String, dynamic> r) => _serviceRequestFromApi(r);

  ServiceRequest _serviceRequestFromApi(Map<String, dynamic> r) {
    final rawStatus = (r['status'] as String? ?? 'pending').trim().toLowerCase();
    final eventDate = DateTime.tryParse(r['event_date'] as String? ?? '') ?? DateTime.now();
    final status = _deriveRequestStatusLabel(rawStatus);
    DateTime? submissionDate;
    final createdRaw = r['created_at'] as String?;
    if (createdRaw != null) {
      submissionDate = DateTime.tryParse(createdRaw);
    }
    DateTime? updatedAt;
    final updatedRaw = r['updated_at'] as String?;
    if (updatedRaw != null) {
      updatedAt = DateTime.tryParse(updatedRaw);
    }
    return ServiceRequest(
      id: 'REQ-${r['id']}',
      requestId: r['id'] as int?,
      eventName: r['title'] as String? ?? 'Documentation Request',
      description: r['description'] as String?,
      eventDate: eventDate,
      startTime: r['start_time'] as String?,
      endTime: r['end_time'] as String?,
      location: r['venue'] as String?,
      requirements: r['requirements'] as String?,
      submissionDate: submissionDate,
      updatedAt: updatedAt,
      requesterName: r['requestor_name'] as String? ?? authController.user?.name ?? 'You',
      requestType: 'Documentation',
      status: status,
      rejectionReason: r['rejection_reason'] as String?,
      originalEventDate: _parseDateOnly(r['original_event_date'] as String?),
      lastRescheduledAt: _parseDateTime(r['last_rescheduled_at'] as String?),
      rescheduleHistory: (r['reschedule_history'] as List? ?? [])
          .map((e) => RescheduleHistoryEntry.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  DateTime? _parseDateOnly(String? raw) {
    if (raw == null || raw.length < 10) return null;
    return DateTime.tryParse(raw.substring(0, 10));
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  String _deriveRequestStatusLabel(String rawStatus) {
    return RequestStatus.fromApi(rawStatus).label;
  }

  Future<List<CoverageDay>> fetchCoverageAvailability({
    required int year,
    required int month,
    int? excludeRequestId,
  }) {
    return memberApiService.getCoverageAvailability(
      year: year,
      month: month,
      excludeRequestId: excludeRequestId,
    );
  }

  Future<List<CoverageTimeSlot>> fetchCoverageSlots({
    required DateTime date,
    int? excludeRequestId,
  }) {
    return memberApiService.getCoverageSlots(
      date: date,
      excludeRequestId: excludeRequestId,
    );
  }

  Future<ServiceRequest> rescheduleServiceRequest({
    required int requestId,
    required DateTime eventDate,
    String? startTime,
    String? endTime,
  }) async {
    final data = await memberApiService.rescheduleServiceRequest(
      requestId,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
    );
    await refreshAll();
    return _serviceRequestFromApi(data);
  }

  Future<void> respondToAssignment(
    int assignmentId, {
    required String action,
    String? declineReasonCode,
    String? declineReason,
  }) async {
    await memberApiService.respondToAssignment(
      assignmentId,
      action: action,
      declineReasonCode: declineReasonCode,
      declineReason: declineReason,
    );
    await refreshAll();
  }

  /// After saving a practice evaluation: refresh counts, history, rankings only.
  /// Skips events, tasks, notifications, and other heavy sections from [refreshAll].
  Future<void> refreshAfterEvaluationSave() async {
    if (!authController.isLoggedIn) return;
    try {
      final results = await Future.wait<dynamic>([
        memberApiService.getParticipation(),
        memberApiService.getEvaluations(),
        memberApiService.getRankings(),
        memberApiService.getMedia(mine: true, mediaCategory: 'member_evaluation'),
      ]);

      final participation = Map<String, dynamic>.from(results[0] as Map);
      appState.applyParticipation(
        uploadsCount: participation['uploads_count'] as int? ?? 0,
        assignmentsCompleted: participation['assignments_completed'] as int? ?? 0,
        averageScore: (participation['average_score'] as num?)?.toDouble() ?? 0,
        totalPoints: participation['total_points'] as int? ?? 0,
        evaluationsCount: participation['evaluations_count'] as int? ?? 0,
        evaluationsToday: participation['evaluations_today'] as int? ?? 0,
        dailyEvaluationLimit: participation['daily_evaluation_limit'] as int? ?? 5,
      evaluationMaxUploadMb: participation['evaluation_max_upload_mb'] as int? ?? 350,
      evaluationMaxVideoSeconds: participation['evaluation_max_video_seconds'] as int? ?? 30,
      evaluationDailyTimezone: participation['evaluation_daily_timezone'] as String? ?? 'Asia/Manila',
      );

      final evaluations = (results[1] as List).cast<Map<String, dynamic>>();
      appState.evaluations
        ..clear()
        ..addAll(evaluations.map(_evaluationFromApi));

      final rankings = (results[2] as List).cast<Map<String, dynamic>>();
      _applyRankingsRows(rankings);

      unawaited(refreshMilestones(unacknowledgedOnly: true));

      final media = (results[3] as List).cast<Map<String, dynamic>>();
      appState.gallery
        ..clear()
        ..addAll(
          media
              .where((m) => m['storage_removed'] != true)
              .map(_galleryFromApi),
        );

      notifyListeners();
      appState.notifyListeners();
    } catch (_) {
      // Best effort; user can pull to refresh for a full sync.
    }
  }

  String? _inferEvaluationMediaType(String? fileName, String? fileUrl) {
    final name = (fileName ?? '').toLowerCase();
    final url = (fileUrl ?? '').split('?').first.toLowerCase();
    for (final ext in ['.mp4', '.mov', '.webm', '.mkv', '.avi']) {
      if (name.endsWith(ext) || url.endsWith(ext)) return 'video';
    }
    return null;
  }

  /// Practice eval row for a media id (cache first, then member API).
  Future<Evaluation?> findEvaluationForMedia(int mediaId) async {
    final targetId = 'MED-$mediaId';
    for (final e in appState.evaluations) {
      if (e.id == targetId) return e;
    }
    final row = await memberApiService.getEvaluationRowForMedia(mediaId);
    if (row == null) return null;
    return _evaluationFromApi(row);
  }

  /// Removes practice upload bytes only. Returns an error message on failure.
  Future<String?> removePracticeEvaluationStorage(int mediaId) async {
    try {
      await memberApiService.removePracticeMediaStorage(mediaId);
      await refreshEvaluationsTab();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString().replaceFirst('ApiException: ', '').trim();
    }
  }

  Evaluation _evaluationFromApi(Map<String, dynamic> e) {
    PhotoEvaluationResult? parsed;
    final criteriaRaw = e['criteria_json'] as String?;
    if (criteriaRaw != null && criteriaRaw.trim().isNotEmpty) {
      try {
        parsed = PhotoEvaluationResult.fromJson(
          Map<String, dynamic>.from(jsonDecode(criteriaRaw) as Map),
        );
      } catch (_) {}
    }
    final evaluatedRaw = e['evaluated_at'] as String?;
    final evaluatedAt = evaluatedRaw != null ? DateTime.tryParse(evaluatedRaw) : null;
    final storageRemoved = e['storage_removed'] == true;
    final fileUrlRaw = e['file_url'] as String?;
    return Evaluation(
      id: 'MED-${e['media_id']}',
      title: e['file_name'] as String? ?? 'Upload',
      score: (e['overall_score'] as num?)?.toDouble() ?? 0,
      composition: _scoreLabel(e['contrast_score']),
      lighting: _scoreLabel(e['brightness_score']),
      feedback: parsed?.feedback ?? e['feedback'] as String? ?? '',
      date: _formatIso(evaluatedRaw),
      evaluatedAt: evaluatedAt,
      imageUrl: storageRemoved ? null : fileUrlRaw,
      storageRemoved: storageRemoved,
      criteria: parsed?.criteria ?? const [],
      qualityLevel: parsed?.qualityLevel ?? e['quality_level'] as String?,
      mediaType: parsed?.mediaType ??
          _inferEvaluationMediaType(
            e['file_name'] as String?,
            e['file_url'] as String?,
          ),
      geminiFeedback: parsed?.geminiFeedback,
      recommendation: parsed?.recommendation,
      scoringModel: parsed?.scoringModel,
      parsedEvaluation: parsed,
      reviewStatus: e['review_status'] as String?,
      adminRemarks: e['admin_remarks'] as String?,
    );
  }

  void _applyRankingsRows(List<Map<String, dynamic>> rankings) {
    final userId = authController.user?.id;
    final userName = authController.user?.name ?? appState.profileName;
    String? adminRemarks;
    appState.members
      ..clear()
      ..addAll(rankings.map((r) {
        final name = r['name'] as String? ?? r['member_name'] as String? ?? '';
        final id = r['user_id'] as int? ?? r['id'] as int?;
        final isSelf = (userId != null && id == userId) ||
            (userName.isNotEmpty && name.trim() == userName.trim());
        if (isSelf) {
          _applySelfRankingMetrics(r);
          if (adminRemarks == null) {
            final remarks = r['admin_remarks'] as String?;
            if (remarks != null && remarks.trim().isNotEmpty) {
              adminRemarks = remarks.trim();
            }
          }
        }
        return _memberFromRankingRow(r);
      }));
    appState.profileAdminRemarks = adminRemarks;
  }

  void _applySelfRankingMetrics(Map<String, dynamic> r) {
    final score = r['skill_score'];
    if (score is num) {
      appState.profileSkillScore = score.toDouble();
    }
    final evalCount = r['evaluation_count'];
    if (evalCount is int) {
      appState.profileEvaluationsCount = evalCount;
    }
    final level = r['skill_level'] as String?;
    if (level != null && level.trim().isNotEmpty) {
      appState.profileSkillLevel = level.trim();
    }
    final points = r['points'] ?? r['good_evaluations'];
    if (points is int) {
      appState.profilePoints = points;
    }
    final rankPos = r['rank_position'] ?? r['rank'];
    if (rankPos is int) {
      appState.profileRankPosition = rankPos;
    }
  }

  Future<void> uploadMedia({
    required List<int> bytes,
    required String fileName,
    int? requestId,
    String? title,
    String? evaluationMetadata,
  }) async {
    await memberApiService.uploadMedia(
      bytes: bytes,
      fileName: fileName,
      requestId: requestId,
      displayName: title,
      evaluationMetadata: evaluationMetadata,
    );
    await refreshAll();
  }

  /// Event documentation upload tied to an assignment (no AI evaluation pipeline).
  Future<void> uploadEventCoverage({
    required List<int> bytes,
    required String fileName,
    required int requestId,
    String? title,
  }) async {
    await memberApiService.uploadMedia(
      bytes: bytes,
      fileName: fileName,
      requestId: requestId,
      displayName: title,
    );
    try {
      await _syncTasksSection();
    } catch (_) {}
    await refreshEventGallery();
    appState.notifyListeners();
    notifyListeners();
  }

  /// Standalone practice photo/video evaluation — no documentation request required.
  Future<PracticeEvaluationSaveOutcome> submitPracticeEvaluation({
    required List<int> bytes,
    required String fileName,
    String? title,
    String? evaluationMetadata,
    bool isVideo = false,
    bool Function()? shouldContinuePolling,
    DeferredMediaEvaluationPoll? pollService,
    void Function(MediaUploadResponse upload)? onDeferredProcessingStarted,
  }) async {
    Map<String, dynamic> uploadRaw;
    try {
      uploadRaw = await memberApiService.uploadMedia(
        bytes: bytes,
        fileName: fileName,
        displayName: title,
        evaluationMetadata: evaluationMetadata,
      );
    } on ApiException catch (e) {
      return PracticeEvaluationSaveOutcome(
        phase: PracticeEvaluationSavePhase.uploadFailed,
        errorMessage: _practiceUploadErrorMessage(e),
      );
    } catch (_) {
      return PracticeEvaluationSaveOutcome(
        phase: PracticeEvaluationSavePhase.uploadFailed,
        errorMessage: 'Upload failed. Check your connection and try again.',
      );
    }

    final upload = MediaUploadResponse.fromJson(uploadRaw);

    if (!upload.needsDeferredProcessingPoll) {
      await PendingPracticeEvaluationStore.remove(upload.id);
      _syncPendingPracticeCount();
      await refreshAfterEvaluationSave();
      return PracticeEvaluationSaveOutcome(
        phase: PracticeEvaluationSavePhase.completedImmediately,
        upload: upload,
      );
    }

    await registerPendingPracticeAnalysis(upload.id, isVideo: isVideo);
    await refreshAfterEvaluationSave();

    onDeferredProcessingStarted?.call(upload);

    final poll = pollService ??
        DeferredMediaEvaluationPoll(
          fetchMediaById: (id) => memberApiService.getMediaById(id),
        );

    final pollOutcome = await poll.waitForCompletion(
      mediaId: upload.id,
      isVideo: isVideo,
      shouldContinue: shouldContinuePolling,
    );

    if (pollOutcome == DeferredPollOutcome.completed) {
      await PendingPracticeEvaluationStore.remove(upload.id);
      _syncPendingPracticeCount();
      await refreshAfterEvaluationSave();
      return PracticeEvaluationSaveOutcome(
        phase: PracticeEvaluationSavePhase.completedAfterPoll,
        upload: upload,
        pollOutcome: pollOutcome,
      );
    }

    if (pollOutcome == DeferredPollOutcome.cancelled) {
      return PracticeEvaluationSaveOutcome(
        phase: PracticeEvaluationSavePhase.stillProcessingOnServer,
        upload: upload,
        pollOutcome: pollOutcome,
      );
    }

    return PracticeEvaluationSaveOutcome(
      phase: PracticeEvaluationSavePhase.stillProcessingOnServer,
      upload: upload,
      pollOutcome: pollOutcome,
    );
  }

  Future<void> registerPendingPracticeAnalysis(int mediaId, {required bool isVideo}) async {
    await PendingPracticeEvaluationStore.add(mediaId, isVideo: isVideo);
    _syncPendingPracticeCount();
    notifyListeners();
  }

  void _syncPendingPracticeCount() {
    pendingPracticeAnalysisCount = PendingPracticeEvaluationStore.count;
  }

  /// Background poll for uploads registered while the member was away from the eval screen.
  Future<void> resumePendingPracticeAnalysis() {
    if (!authController.isLoggedIn) return Future.value();
    final inFlight = _pendingPracticeResumeFuture;
    if (inFlight != null) return inFlight;

    final task = _resumePendingPracticeAnalysisImpl();
    _pendingPracticeResumeFuture = task;
    return task.whenComplete(() {
      if (identical(_pendingPracticeResumeFuture, task)) {
        _pendingPracticeResumeFuture = null;
      }
    });
  }

  Future<void> _resumePendingPracticeAnalysisImpl() async {
    await PendingPracticeEvaluationStore.ensureLoaded();
    _syncPendingPracticeCount();
    final entries = PendingPracticeEvaluationStore.entries;
    if (entries.isEmpty) return;

    final poll = DeferredMediaEvaluationPoll(
      fetchMediaById: (id) => memberApiService.getMediaById(id),
    );

    var anyCompleted = false;
    for (final entry in entries) {
      final outcome = await poll.waitForCompletion(
        mediaId: entry.mediaId,
        isVideo: entry.isVideo,
      );
      if (outcome == DeferredPollOutcome.completed) {
        await PendingPracticeEvaluationStore.remove(entry.mediaId);
        anyCompleted = true;
      }
    }

    _syncPendingPracticeCount();
    if (anyCompleted) {
      await refreshAfterEvaluationSave();
    }
    notifyListeners();
  }

  Future<void> submitFeedback({
    required int requestId,
    required int rating,
    String? comment,
  }) async {
    await memberApiService.submitFeedback(
      requestId: requestId,
      rating: rating,
      comment: comment,
    );
    await _syncFeedbackSection();
    appState.notifyListeners();
    notifyListeners();
  }

  Future<void> markNotificationRead(int id) async {
    if (id <= 0) return;
    await memberApiService.markNotificationRead(id);
    for (final n in appState.notifications) {
      if (n.id == id) n.read = true;
    }
    appState.notifyListeners();
    notifyListeners();
  }

  void markNotificationReadInMemory(AppNotification notification) {
    if (notification.read) return;
    notification.read = true;
    appState.notifyListeners();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await memberApiService.markAllNotificationsRead();
    for (final n in appState.notifications) {
      n.read = true;
    }
    appState.notifyListeners();
    notifyListeners();
  }

  Future<void> clearReadNotifications() async {
    await memberApiService.clearReadNotifications();
    appState.notifications.removeWhere((n) => n.read);
    appState.notifyListeners();
    notifyListeners();
  }

  /// Lightweight fetch when a notification deep-link needs announcement data.
  Future<void> ensureAnnouncementsForNavigation() async {
    if (!authController.isLoggedIn || appState.announcements.isNotEmpty) return;
    final ctx = _MemberSyncContext();
    await _runSection(ctx, 'Announcements', _syncAnnouncementsSection);
    notifyListeners();
    appState.notifyListeners();
  }

  static String _practiceUploadErrorMessage(ApiException e) {
    final msg = e.message.trim();
    if (e.statusCode == 413) {
      return 'This file is too large for the server. Try a shorter video or smaller photo.';
    }
    if (e.statusCode == null ||
        msg.toLowerCase().contains('connection') ||
        msg.toLowerCase().contains('timeout') ||
        msg.toLowerCase().contains('failed host lookup') ||
        msg.toLowerCase().contains('network')) {
      return 'Could not reach the server. Check Wi-Fi and your backend URL (orange banner).';
    }
    if (msg.isNotEmpty) return msg;
    return 'Upload failed. Please try again.';
  }

  /// Lightweight fetch when a notification deep-link needs assignment data.
  Future<void> ensureAssignmentsForNavigation({int? assignmentId}) async {
    if (!authController.isLoggedIn) return;
    final missingTarget = assignmentId != null &&
        !appState.challenges.any((c) => c.assignmentId == assignmentId);
    if (appState.challenges.isNotEmpty && !missingTarget) return;
    final ctx = _MemberSyncContext();
    await _runSection(ctx, 'Tasks', _syncTasksSection);
    notifyListeners();
    appState.notifyListeners();
  }

  bool _serviceRequestInCache(int requestId) {
    for (final r in appState.serviceRequests) {
      if (r.requestId == requestId) return true;
      final parsed = int.tryParse(r.id);
      if (parsed == requestId) return true;
    }
    return false;
  }

  /// Lightweight fetch when a notification deep-link needs request data.
  Future<void> ensureServiceRequestsForNavigation({int? requestId}) async {
    if (!authController.isLoggedIn) return;
    final missingTarget = requestId != null && !_serviceRequestInCache(requestId);
    if (appState.serviceRequests.isNotEmpty && !missingTarget) return;
    final ctx = _MemberSyncContext();
    await _runSection(ctx, 'Service requests', _syncServiceRequestsSection);
    notifyListeners();
    appState.notifyListeners();
  }

  int? _jsonInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  EventGalleryMedia _eventGalleryFromApi(Map<String, dynamic> m) {
    DateTime? uploadedAt;
    final uploadedRaw = m['uploaded_at'] as String?;
    if (uploadedRaw != null) uploadedAt = DateTime.tryParse(uploadedRaw);

    DateTime? eventDate;
    final eventDateRaw = m['event_date'] as String?;
    if (eventDateRaw != null) eventDate = DateTime.tryParse(eventDateRaw);

    return EventGalleryMedia(
      id: _jsonInt(m['id']) ?? 0,
      fileName: m['file_name'] as String? ?? 'Media',
      fileType: m['file_type'] as String? ?? 'photo',
      fileUrl: m['file_url'] as String? ?? '',
      uploadedAt: uploadedAt,
      requestId: _jsonInt(m['request_id']),
      eventTitle: m['event_title'] as String?,
      eventDate: eventDate,
      eventDescription: m['event_description'] as String?,
      facebookPublishStatus:
          m['facebook_publish_status'] as String? ?? 'not_published',
      facebookPostId: m['facebook_post_id'] as String?,
    );
  }

  GalleryItem _galleryFromApi(Map<String, dynamic> m) {
    final type = m['file_type'] as String? ?? 'photo';
    final isVideo = type == 'video';
    return GalleryItem(
      title: m['file_name'] as String? ?? 'Media',
      category: m['request_id'] == null ? 'Practice' : 'Coverage',
      date: _formatIso(m['uploaded_at'] as String?),
      color: isVideo ? kAccent : kCyan,
      networkUrl: m['file_url'] as String?,
      mediaType: isVideo ? MediaType.video : MediaType.photo,
      aiDetected: m['ai_detected'] as bool? ?? false,
      mediaId: m['id'] as int?,
      requestId: m['request_id'] as int?,
      overallScore: (m['overall_score'] as num?)?.toDouble(),
      feedback: m['feedback'] as String?,
      processingStatus: m['processing_status'] as String?,
    );
  }

  CalendarEvent _calendarEventFromApi(Map<String, dynamic> e) {
    final startDate = _parseEventStartDate(e);
    final endDate = _parseEventEndDate(e, startDate);
    final status = _eventStatus(e, startDate);
    final location = (e['location'] as String? ?? e['venue'] as String? ?? '').trim();
    final teamRaw = e['documentation_team'];
    final team = teamRaw is List
        ? teamRaw.map((v) => v.toString()).where((n) => n.trim().isNotEmpty).toList()
        : <String>[];
    return CalendarEvent(
      id: e['id'] as int?,
      tag: _documentationTypeLabel(e),
      title: e['title'] as String? ?? 'Event',
      date: _formatEventDate(startDate),
      timeLabel: _formatEventTimeFromApi(e, startDate),
      location: location,
      status: status.label,
      statusColor: status.color,
      description: (e['description'] as String? ?? location).trim(),
      requestId: e['request_id'] as int?,
      startDate: startDate,
      endDate: endDate,
      requestStatus: e['request_status'] as String?,
      assignedMemberName: e['assigned_member_name'] as String?,
      documentationTeam: team,
    );
  }

  DateTime _parseEventStartDate(Map<String, dynamic> e) {
    final dateStr = e['start_date'] as String? ?? e['event_date'] as String?;
    final timeStr = e['start_time'] as String?;
    if (dateStr != null && timeStr != null) {
      final combined = '${dateStr}T${timeStr.length <= 5 ? '$timeStr:00' : timeStr}';
      final parsed = DateTime.tryParse(combined);
      if (parsed != null) return parsed;
    }
    if (dateStr != null) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  DateTime? _parseEventEndDate(Map<String, dynamic> e, DateTime startDate) {
    final dateStr = e['start_date'] as String? ?? e['event_date'] as String?;
    final timeStr = e['end_time'] as String?;
    if (dateStr == null || timeStr == null || timeStr.isEmpty) return null;
    final combined = '${dateStr}T${timeStr.length <= 5 ? '$timeStr:00' : timeStr}';
    return DateTime.tryParse(combined) ??
        DateTime(startDate.year, startDate.month, startDate.day).add(const Duration(hours: 1));
  }

  String _documentationTypeLabel(Map<String, dynamic> e) {
    if (e['request_id'] != null) return 'Event Documentation';
    return 'ACCESS Event';
  }

  String? _formatEventTimeFromApi(Map<String, dynamic> e, DateTime startDate) {
    final raw = e['start_time'] as String?;
    if (raw == null || raw.isEmpty) {
      if (startDate.hour == 0 && startDate.minute == 0) return 'Time TBA';
      return _formatEventTime(startDate);
    }
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final dt = DateTime(startDate.year, startDate.month, startDate.day, hour, minute);
      return _formatEventTime(dt);
    }
    return raw;
  }

  ({String label, Color color}) _eventStatus(Map<String, dynamic> e, DateTime startDate) {
    final status = (e['status'] as String? ?? 'upcoming').toLowerCase();
    final reqStatus = (e['request_status'] as String? ?? '').toLowerCase();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final eventDay = DateTime(startDate.year, startDate.month, startDate.day);
    final isPast = eventDay.isBefore(today) || status == 'completed';

    if (status == 'cancelled' || status == 'canceled') {
      return (label: 'Cancelled', color: kTextSecondary);
    }
    if (isPast) {
      return (label: 'Past', color: kTextSecondary);
    }
    if (reqStatus == 'approved' || reqStatus.isEmpty) {
      return (label: 'Approved', color: kGreen);
    }
    if (status == 'upcoming' || status == 'assigned' || status == 'ongoing') {
      return (label: 'Scheduled', color: kAccent);
    }
    return (label: 'Scheduled', color: kAccent);
  }

  String _scoreLabel(dynamic v) {
    final s = (v as num?)?.toDouble() ?? 0;
    if (s >= 0.8) return 'Excellent';
    if (s >= 0.6) return 'Good';
    return 'Average';
  }

  EventFeedback _feedbackFromApi(Map<String, dynamic> f) {
    final requestId = _jsonInt(f['request_id']);
    final comment = f['comment'] as String? ?? '';
    final adminResponse = (f['admin_response'] as String?)?.trim();
    final reviewStatus = (f['review_status'] as String?)?.trim() ?? 'pending';
    return EventFeedback(
      eventTitle: _feedbackEventTitle(requestId),
      type: 'Service rating',
      message: comment,
      rating: f['rating'] as int? ?? 5,
      date: _formatIso(f['created_at'] as String?),
      requestId: requestId,
      adminResponse: adminResponse != null && adminResponse.isNotEmpty ? adminResponse : null,
      reviewStatus: reviewStatus,
    );
  }

  String _feedbackEventTitle(int? requestId) {
    if (requestId == null) return 'Event';
    for (final r in appState.serviceRequests) {
      if (r.requestId == requestId) return r.eventName;
    }
    for (final c in appState.challenges) {
      if (c.requestId == requestId) return c.title;
    }
    return 'Request #$requestId';
  }

  String _formatIso(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return _formatDateTime(dt);
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, $h:$min';
  }

  String _formatEventDate(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatEventTime(DateTime dt) {
    if (dt.hour == 0 && dt.minute == 0) return 'Time TBA';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  Color _colorForName(String name) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF6366F1),
      Color(0xFF06B6D4),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Member _memberFromRankingRow(Map<String, dynamic> r) {
    final name = r['name'] as String? ?? r['member_name'] as String? ?? '';
    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    final profileRaw = r['profile_image'] as String?;
    final profileUrl = profileRaw != null && profileRaw.trim().isNotEmpty
        ? memberApiService.mediaUrl(profileRaw.trim())
        : null;

    return Member(
      userId: r['user_id'] as int? ?? r['id'] as int?,
      name: name,
      rank: r['skill_level'] as String? ?? 'Member',
      initials: initials,
      uploads: r['uploads'] as int? ?? 0,
      goodEvaluations: r['good_evaluations'] as int? ?? r['points'] as int? ?? 0,
      monthlyPoints: r['monthly_points'] as int? ?? 0,
      evaluationCount: r['evaluation_count'] as int? ?? 0,
      rankPosition: r['rank_position'] as int? ?? r['rank'] as int?,
      avgMediaScore: (r['avg_score'] as num?)?.toDouble() ??
          (r['average_quality_score'] as num?)?.toDouble() ??
          0,
      avatarColor: _colorForName(name),
      profileImageUrl: profileUrl,
    );
  }
}

class _MemberSyncContext {
  bool sessionExpired = false;
  bool profileOk = false;
  final warnings = <String>[];
}

final memberDataController = MemberDataController();
