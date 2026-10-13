import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/member_shell_navigation.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_announcements.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_latest_feedback.dart';
import 'package:access_mobile/mobile_app/widgets/member_milestone_celebration.dart';
import 'package:access_mobile/mobile_app/widgets/member_notification_detail_dialog.dart';
import 'package:access_mobile/shared/models/app_notification_mapper.dart';
import 'package:access_mobile/shared/models/member_milestone.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';

ServiceRequest? serviceRequestById(int requestId) {
  for (final r in appState.serviceRequests) {
    if (r.requestId == requestId) return r;
    final parsed = int.tryParse(r.id);
    if (parsed == requestId) return r;
  }
  return null;
}

Announcement? announcementForNotification(AppNotification notification) {
  final refId = notification.actionRefId;
  if (refId != null) {
    for (final item in appState.announcements) {
      if (item.id == refId) return item;
    }
  }

  final title = notification.title.trim().toLowerCase();
  if (title.isEmpty) return null;
  for (final item in appState.announcements) {
    if (item.title.trim().toLowerCase() == title) return item;
  }
  return null;
}

Future<void> _openRequestDetail(BuildContext context, int requestId) async {
  var request = serviceRequestById(requestId);
  if (request == null) {
    await memberDataController.ensureServiceRequestsForNavigation(
      requestId: requestId,
    );
    request = serviceRequestById(requestId);
  }
  if (!context.mounted) return;
  if (request == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request details are not available yet. Pull to refresh.')),
    );
    return;
  }

  final isRequestor = authController.user?.role == AccessRole.organization;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => RequestDetailScreen(
        request: request!,
        onViewGallery: isRequestor ? RequestorShellNavigation.openGallery : null,
        onViewFeedback: isRequestor ? RequestorShellNavigation.openFeedback : null,
      ),
    ),
  );
}

Evaluation? evaluationForMediaId(int mediaId) {
  final targetId = 'MED-$mediaId';
  for (final e in appState.evaluations) {
    if (e.id == targetId) return e;
  }
  return null;
}

Evaluation? _newestEvaluationWithAdminRemarks() {
  for (final e in appState.evaluations) {
    if ((e.adminRemarks ?? '').trim().isNotEmpty) return e;
  }
  return null;
}

Future<void> _openAdminReviewNotification(
  BuildContext context,
  AppNotification n, {
  int? mediaId,
}) async {
  await memberDataController.refreshEvaluationsTab();
  if (!context.mounted) return;

  Evaluation? match = mediaId != null ? evaluationForMediaId(mediaId) : null;
  if (match == null && mediaId != null) {
    match = await memberDataController.findEvaluationForMedia(mediaId);
  }
  match ??= _newestEvaluationWithAdminRemarks();

  if (!context.mounted) return;

  if (match != null) {
    openEvaluationReport(
      context,
      match,
      allEvaluations: appState.evaluations,
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Evaluation details are loading. Open the Evaluations tab and pull to refresh.'),
    ),
  );
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const EvaluationScreen()),
  );
}

Future<void> _openRankingAdminFeedbackNotification(
  BuildContext context,
  AppNotification n,
) async {
  await memberDataController.refreshRankings();
  if (!context.mounted) return;

  final fromState = LatestAdminFeedback.fromAppState();
  final item = (fromState != null && fromState.isRankingRemarks)
      ? fromState
      : LatestAdminFeedback.rankingRemarks(
          n.body,
          date: (n.createdAt?.trim().isNotEmpty == true) ? n.createdAt!.trim() : 'Recently',
        );

  if (item.fullMessage.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Administrator feedback is not available yet. Pull to refresh on Home.'),
      ),
    );
    MemberShellNavigation.openHome?.call();
    return;
  }

  showAdminFeedbackSheet(
    context,
    item,
    onViewOnHome: () => MemberShellNavigation.openHome?.call(),
  );
}

Future<void> _openGalleryFromNotification(
  BuildContext context, {
  int? requestId,
  required bool isRequestor,
}) async {
  if (isRequestor) {
    RequestorShellNavigation.openGallery?.call();
    return;
  }

  MemberShellNavigation.openGallery?.call(requestId: requestId);
}

Future<void> _openAnnouncementFromNotification(
  BuildContext context,
  AppNotification notification,
) async {
  final isRequestor = authController.user?.role == AccessRole.organization;
  await memberDataController.ensureAnnouncementsForNavigation();
  if (!context.mounted) return;

  final item = announcementForNotification(notification);
  if (item != null) {
    await showMemberNotificationFloatingCard(
      context,
      title: item.title,
      message: item.content,
      categoryLabel: 'Announcement',
      icon: Icons.campaign_outlined,
      timeLabel: item.date,
    );
    return;
  }

  if (isRequestor) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Announcement details are not available yet. Pull to refresh on Home.',
        ),
      ),
    );
    return;
  }

  MemberShellNavigation.openHome?.call();
  if (!context.mounted) return;

  if (appState.announcements.isNotEmpty) {
    showAllAnnouncementsSheet(context);
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Announcement details are not available yet. Pull to refresh on Home.')),
  );
}

String? _fallbackAction(AppNotification n) {
  final isRequestor = authController.user?.role == AccessRole.organization;
  if (isRequestor && n.category == 'documentation_request') {
    if (n.actionType == 'view_gallery') return 'view_gallery';
    return 'view_request';
  }
  if (!isRequestor && n.category == 'task_assignment') return 'view_task';
  if (!isRequestor && n.category == 'ai_detection') return 'review_media';
  if (!isRequestor && n.category == 'media_evaluation') {
    if (n.actionType == 'milestone') return 'milestone';
    if (n.actionType == 'view_admin_feedback') return 'view_admin_feedback';
    return 'view_result';
  }
  if (n.category == 'system_alert' || n.category == 'announcement') {
    return 'view_announcement';
  }
  return null;
}

String? _primaryActionLabel(String? action, {required bool isRequestor}) {
  switch (action) {
    case 'view_task':
      return isRequestor ? null : 'View assignments';
    case 'view_request':
      return 'View request';
    case 'view_gallery':
      return 'Open gallery';
    case 'view_announcement':
      return 'View full announcement';
    case 'view_result':
    case 'review_media':
      return isRequestor ? null : 'View evaluation';
    case 'view_admin_feedback':
      return isRequestor ? null : 'View feedback';
    case 'view_feedback':
      return isRequestor ? 'View feedback' : null;
    default:
      return null;
  }
}

Future<void> _executeNotificationAction(
  BuildContext context,
  AppNotification n,
  String? action,
  int? refId, {
  required bool isRequestor,
}) async {
  switch (action) {
    case 'view_task':
      if (!isRequestor) {
        await memberDataController.ensureAssignmentsForNavigation(
          assignmentId: refId,
        );
        if (!context.mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => MyAssignmentsScreen(highlightAssignmentId: refId),
          ),
        );
      }
      return;
    case 'view_request':
      if (refId != null) await _openRequestDetail(context, refId);
      return;
    case 'view_gallery':
      await _openGalleryFromNotification(
        context,
        requestId: refId,
        isRequestor: isRequestor,
      );
      return;
    case 'view_announcement':
      await _openAnnouncementFromNotification(context, n);
      return;
    case 'view_result':
    case 'review_media':
      if (!isRequestor) {
        await _openAdminReviewNotification(context, n, mediaId: refId);
      }
      return;
    case 'view_feedback':
      if (isRequestor) {
        RequestorShellNavigation.openFeedback?.call(requestId: refId);
      }
      return;
    case 'view_admin_feedback':
      if (!isRequestor) {
        await _openRankingAdminFeedbackNotification(context, n);
      }
      return;
    default:
      return;
  }
}

/// Marks read (API when id > 0), shows centered detail card, then optional deep link.
Future<void> handleNotificationTap(
  BuildContext context,
  AppNotification n, {
  bool openedFromPush = false,
}) async {
  if (!n.read && n.id > 0) {
    await memberDataController.markNotificationRead(n.id);
  } else if (!n.read) {
    n.read = true;
  }

  if (!context.mounted) return;

  final isRequestor = authController.user?.role == AccessRole.organization;
  final action = n.actionType ?? _fallbackAction(n);
  final refId = n.actionRefId;

  // Inbox sheet: pop first. Push/tray: use root navigator only (do not pop a screen).
  final rootNav = Navigator.of(context, rootNavigator: true);
  if (!openedFromPush) {
    Navigator.pop(context);
  }
  final navContext = rootNav.context;

  if (action == 'milestone' && !isRequestor) {
    if (refId != null) {
      await memberDataController.refreshMilestones(unacknowledgedOnly: false);
      if (!navContext.mounted) return;
      MemberMilestone? match;
      for (final m in memberDataController.memberMilestones) {
        if (m.id == refId) {
          match = m;
          break;
        }
      }
      if (match != null && !match.isAcknowledged) {
        await showMemberMilestoneCelebration(navContext, match);
        await memberDataController.acknowledgeMilestone(match.id);
      } else if (match != null) {
        await showMemberMilestoneCelebration(navContext, match);
      } else {
        await memberDataController.celebratePendingMilestones(navContext);
      }
    }
    return;
  }

  if (!navContext.mounted) return;

  final presentation = notificationDetailPresentation(n, requestor: isRequestor);
  final primaryLabel = _primaryActionLabel(action, isRequestor: isRequestor);

  final continueNav = await showMemberNotificationFloatingCard(
    navContext,
    title: n.title,
    message: n.body,
    categoryLabel: presentation.$1,
    icon: presentation.$2,
    accent: presentation.$3,
    timeLabel: n.createdAt,
    primaryActionLabel: primaryLabel,
  );

  if (!navContext.mounted) return;
  if (primaryLabel != null && !continueNav) return;

  await _executeNotificationAction(
    navContext,
    n,
    action,
    refId,
    isRequestor: isRequestor,
  );
}
