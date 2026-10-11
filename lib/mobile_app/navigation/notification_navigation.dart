import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/member_shell_navigation.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/sheets/admin_review_notice_sheet.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_announcements.dart';
import 'package:access_mobile/mobile_app/widgets/member_milestone_celebration.dart';
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
    await memberDataController.ensureServiceRequestsForNavigation();
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
  match ??= _newestEvaluationWithAdminRemarks();

  void openReport() {
    if (!context.mounted || match == null) return;
    openEvaluationReport(
      context,
      match,
      allEvaluations: appState.evaluations,
      notificationMessage: n.body,
    );
  }

  final storedRemarks = match?.adminRemarks?.trim() ?? '';
  final message = storedRemarks.isNotEmpty ? storedRemarks : n.body.trim();

  if (message.isEmpty) {
    if (match != null) {
      openReport();
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const EvaluationScreen()),
      );
    }
    return;
  }

  showAdminReviewNoticeSheet(
    context,
    title: n.title,
    message: message,
    onViewEvaluation: match != null ? openReport : null,
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
  await memberDataController.ensureAnnouncementsForNavigation();
  if (!context.mounted) return;

  final item = announcementForNotification(notification);
  if (item != null) {
    showAnnouncementDetailSheet(context, item);
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
  if (isRequestor && n.category == 'documentation_request') return 'view_request';
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

/// Marks read (API when id > 0) then navigates to the relevant screen.
Future<void> handleNotificationTap(BuildContext context, AppNotification n) async {
  if (!n.read && n.id > 0) {
    await memberDataController.markNotificationRead(n.id);
  } else if (!n.read) {
    n.read = true;
  }

  if (!context.mounted) return;
  Navigator.pop(context);

  final isRequestor = authController.user?.role == AccessRole.organization;
  final action = n.actionType ?? _fallbackAction(n);
  final refId = n.actionRefId;

  switch (action) {
    case 'view_task':
      if (!isRequestor) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
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
        await _openAdminReviewNotification(context, n);
      }
      return;
    case 'milestone':
      if (!isRequestor && refId != null) {
        await memberDataController.refreshMilestones(unacknowledgedOnly: false);
        if (!context.mounted) return;
        MemberMilestone? match;
        for (final m in memberDataController.memberMilestones) {
          if (m.id == refId) {
            match = m;
            break;
          }
        }
        if (match != null && !match.isAcknowledged) {
          await showMemberMilestoneCelebration(context, match);
          await memberDataController.acknowledgeMilestone(match.id);
        } else if (match != null) {
          await showMemberMilestoneCelebration(context, match);
        } else {
          await memberDataController.celebratePendingMilestones(context);
        }
      }
      return;
    default:
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read')),
        );
      }
      return;
  }
}
