import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/member_shell_navigation.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_announcements.dart';
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

Future<void> _openEvaluationFromNotification(BuildContext context, int? mediaId) async {
  Evaluation? match = mediaId != null ? evaluationForMediaId(mediaId) : null;
  if (match == null) {
    await memberDataController.ensureEvaluationsTab();
    if (!context.mounted) return;
    match = mediaId != null ? evaluationForMediaId(mediaId) : null;
  }
  if (!context.mounted) return;

  if (match != null) {
    openEvaluationReport(context, match, allEvaluations: appState.evaluations);
    return;
  }

  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const EvaluationScreen()),
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
    return n.actionType == 'view_admin_feedback' ? 'view_admin_feedback' : 'view_result';
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
        await _openEvaluationFromNotification(context, refId);
      }
      return;
    case 'view_feedback':
      if (isRequestor) {
        RequestorShellNavigation.openFeedback?.call(requestId: refId);
      }
      return;
    case 'view_admin_feedback':
      if (!isRequestor) {
        MemberShellNavigation.openHome?.call();
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
