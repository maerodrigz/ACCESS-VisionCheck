import 'dart:convert';

import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/web_admin/data/admin_notification_helpers.dart';
import 'package:access_mobile/web_admin/features/notification_center/notification_center_models.dart';
import 'package:access_mobile/web_admin/features/notifications/notification_models.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationCenterRepository {
  static const _dismissedKey = 'notification_center_dismissed_ids';

  Future<NotificationCenterData> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception('Backend offline. Run: cd access_backend && python manage.py runserver');
    }

    final raw = await adminApi.myNotifications();
    final dismissed = await _loadDismissedIds();
    final items = notificationsFromApi(raw)
        .where((n) => !dismissed.contains(n.id))
        .map(_enrich)
        .toList();

    items.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

    return NotificationCenterData(all: items, stats: _computeStats(items));
  }

  List<CenterNotificationItem> filter({
    required List<CenterNotificationItem> items,
    required NotificationModuleFilter chip,
    required String search,
  }) {
    return items.where((n) => n.matchesFilter(chip) && n.matchesSearch(search)).toList();
  }

  Future<void> markRead(int id) async {
    if (id > 0) await adminApi.markNotificationRead(id);
  }

  Future<void> markAllRead() async {
    await adminApi.markAllNotificationsRead();
  }

  Future<void> clearRead() async {
    await adminApi.clearReadNotifications();
  }

  Future<void> dismiss(int id) async {
    final set = await _loadDismissedIds();
    set.add(id);
    await _saveDismissedIds(set);
    if (id > 0) {
      try {
        await adminApi.markNotificationRead(id);
      } catch (_) {}
    }
  }

  CenterNotificationItem _enrich(AdminNotificationItem n) {
    final blob = '${n.title} ${n.message}'.toLowerCase();
    final module = _moduleFor(n, blob);
    final displayPriority = _displayPriority(n, blob);
    final requiresAction = _requiresAction(n, blob, module, displayPriority);
    return CenterNotificationItem(
      source: n,
      module: module,
      displayPriority: displayPriority,
      requiresAction: requiresAction,
      actionLabel: _actionLabel(n, module, blob),
      route: _routeFor(n, module, blob),
      timelineGroup: timelineGroupFor(n.createdAt),
    );
  }

  NotificationModule _moduleFor(AdminNotificationItem n, String blob) {
    if (blob.contains('competency') || blob.contains('skill') || blob.contains('promoted to advanced')) {
      return NotificationModule.competency;
    }
    if (blob.contains('facebook') || blob.contains('album') || blob.contains('media uploaded') || blob.contains('publishing')) {
      return NotificationModule.mediaLibrary;
    }
    return switch (n.category) {
      NotificationCategory.documentationRequest => NotificationModule.requests,
      NotificationCategory.taskAssignment => NotificationModule.members,
      NotificationCategory.mediaEvaluation =>
        blob.contains('ai') ? NotificationModule.mediaIntegrity : NotificationModule.mediaLibrary,
      NotificationCategory.aiDetection => NotificationModule.mediaIntegrity,
      NotificationCategory.feedback => NotificationModule.feedback,
      NotificationCategory.systemAlert => NotificationModule.system,
    };
  }

  NotificationDisplayPriority _displayPriority(AdminNotificationItem n, String blob) {
    if (blob.contains('failed') ||
        blob.contains('ai detection') ||
        blob.contains('ai-generated') ||
        blob.contains('low rating') ||
        (n.category == NotificationCategory.documentationRequest && blob.contains('new documentation'))) {
      return NotificationDisplayPriority.critical;
    }
    if (n.priority == NotificationPriority.high && n.unread) {
      return NotificationDisplayPriority.warning;
    }
    if (blob.contains('completed') ||
        blob.contains('published') ||
        blob.contains('approved') ||
        blob.contains('accepted') ||
        blob.contains('backup completed') ||
        blob.contains('5-star') ||
        blob.contains('5/5')) {
      return NotificationDisplayPriority.success;
    }
    if (blob.contains('warning') || blob.contains('exceeds') || blob.contains('declined')) {
      return NotificationDisplayPriority.warning;
    }
    return NotificationDisplayPriority.information;
  }

  bool _requiresAction(
    AdminNotificationItem n,
    String blob,
    NotificationModule module,
    NotificationDisplayPriority priority,
  ) {
    if (priority == NotificationDisplayPriority.critical && n.unread) return true;
    if (module == NotificationModule.mediaIntegrity && n.unread) return true;
    if (module == NotificationModule.requests &&
        n.unread &&
        (blob.contains('new documentation') || blob.contains('submitted') && blob.contains('review'))) {
      return true;
    }
    if (module == NotificationModule.feedback &&
        n.unread &&
        (blob.contains('low') || blob.contains('1/5') || blob.contains('2/5') || blob.contains('attention'))) {
      return true;
    }
    if (blob.contains('failed') && n.unread) return true;
    if (blob.contains('declined') || blob.contains('unavailable')) return n.unread;
    if (blob.contains('exceeds 90') || blob.contains('storage usage')) return n.unread;
    return false;
  }

  String _actionLabel(AdminNotificationItem n, NotificationModule module, String blob) {
    if (module == NotificationModule.mediaIntegrity) return 'Review Alert';
    if (module == NotificationModule.competency) return 'View Profile';
    if (module == NotificationModule.feedback) return 'View Feedback';
    if (module == NotificationModule.mediaLibrary) return 'Open Media';
    if (module == NotificationModule.members) return 'View Member';
    if (module == NotificationModule.requests) {
      return blob.contains('new documentation') ? 'View Request' : 'View Request';
    }
    if (module == NotificationModule.system) return 'View Details';
    return n.actionButtonLabel ?? 'Open';
  }

  AdminRoute _routeFor(AdminNotificationItem n, NotificationModule module, String blob) {
    if (n.route != null) {
      if (n.actionType == 'review_media') return AdminRoute.mediaEvaluation;
      if (n.actionType == 'view_result' && module == NotificationModule.mediaLibrary) {
        return AdminRoute.mediaRepository;
      }
      return n.route!;
    }
    return switch (module) {
      NotificationModule.requests => AdminRoute.docRequests,
      NotificationModule.members => AdminRoute.members,
      NotificationModule.mediaLibrary => AdminRoute.mediaRepository,
      NotificationModule.mediaIntegrity => AdminRoute.mediaEvaluation,
      NotificationModule.competency => AdminRoute.skillClassification,
      NotificationModule.feedback => AdminRoute.feedbackReports,
      NotificationModule.system => AdminRoute.systemMonitor,
    };
  }

  NotificationCenterStats _computeStats(List<CenterNotificationItem> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    var unread = 0, today = 0, high = 0, system = 0;
    for (final n in items) {
      if (n.unread) unread++;
      if (n.createdAt != null && !n.createdAt!.isBefore(todayStart)) today++;
      if (n.displayPriority == NotificationDisplayPriority.critical ||
          n.displayPriority == NotificationDisplayPriority.warning) {
        high++;
      }
      if (n.module == NotificationModule.system) system++;
    }
    return NotificationCenterStats(unread: unread, today: today, highPriority: high, system: system);
  }

  Future<Set<int>> _loadDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dismissedKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.map((e) => int.tryParse('$e')).whereType<int>().toSet();
  }

  Future<void> _saveDismissedIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, jsonEncode(ids.toList()));
  }
}
