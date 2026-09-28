import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/navigation/notification_navigation.dart';
import 'package:access_mobile/mobile_app/screens/notification_settings_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/requestor_notification_settings_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

const _sheetTopRadius = 28.0;
const _sheetOverlap = 20.0;

const _notificationsHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kCyan,
    kAccent,
  ],
);

enum _MemberNotificationFilter { all, unread, assignments, evaluations, alerts }

const _requestorNotificationFilters = [
  _MemberNotificationFilter.all,
  _MemberNotificationFilter.unread,
  _MemberNotificationFilter.assignments,
  _MemberNotificationFilter.alerts,
];

List<_MemberNotificationFilter> _notificationFiltersFor({required bool requestor}) {
  if (!requestor) return _MemberNotificationFilter.values;
  return _requestorNotificationFilters;
}

bool _isRequestorAccount() {
  if (authController.user?.role == AccessRole.organization) return true;
  return appState.profileAccountRole.toLowerCase() == 'organization';
}

bool _matchesFilter(AppNotification n, _MemberNotificationFilter filter, {required bool requestor}) {
  return switch (filter) {
    _MemberNotificationFilter.all => true,
    _MemberNotificationFilter.unread => !n.read,
    _MemberNotificationFilter.assignments => requestor
        ? n.category == 'documentation_request'
        : n.category == 'task_assignment' || n.category == 'documentation_request',
    _MemberNotificationFilter.evaluations =>
      n.category == 'media_evaluation' || n.category == 'ai_detection',
    _MemberNotificationFilter.alerts =>
      n.category == 'system_alert' ||
      n.category == 'feedback' ||
      n.category == 'announcement',
  };
}

String _filterLabel(_MemberNotificationFilter filter, {required bool requestor}) {
  return switch (filter) {
    _MemberNotificationFilter.all => 'All',
    _MemberNotificationFilter.unread => 'Unread',
    _MemberNotificationFilter.assignments =>
      requestor ? 'Requests' : 'Assignments',
    _MemberNotificationFilter.evaluations => 'Evaluations',
    _MemberNotificationFilter.alerts => 'Alerts',
  };
}

String _categoryLabel(AppNotification n, {required bool requestor}) {
  return switch (n.category) {
    'task_assignment' => 'Assignment',
    'documentation_request' => requestor ? 'Request update' : 'Documentation',
    'media_evaluation' => 'Evaluation',
    'ai_detection' => 'Integrity review',
    'feedback' => 'Feedback',
    'announcement' => 'Announcement',
    'system_alert' => 'Announcement',
    _ => 'Alert',
  };
}

String? _actionHint(AppNotification n, {required bool requestor}) {
  final action = n.actionType;
  if (action != null) {
    return switch (action) {
      'view_task' => 'Open assignment',
      'view_request' => 'View request details',
      'view_result' => 'View evaluation result',
      'review_media' => 'Review evaluation',
      'view_gallery' => 'Open gallery',
      'view_feedback' => 'Leave feedback',
      'view_announcement' => 'Read announcement',
      _ => 'Open',
    };
  }
  if (requestor && n.category == 'documentation_request') return 'View request details';
  if (!requestor && n.category == 'task_assignment') return 'Open assignment';
  if (!requestor &&
      (n.category == 'media_evaluation' || n.category == 'ai_detection')) {
    return 'View evaluation';
  }
  if (n.category == 'system_alert' || n.category == 'announcement') {
    return 'Read announcement';
  }
  return null;
}

List<(String, List<AppNotification>)> _groupByTime(List<AppNotification> items) {
  if (items.isEmpty) return const [];

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final weekStart = todayStart.subtract(const Duration(days: 7));

  final today = <AppNotification>[];
  final yesterday = <AppNotification>[];
  final thisWeek = <AppNotification>[];
  final earlier = <AppNotification>[];

  for (final n in items) {
    final dt = n.createdAtDt;
    if (dt == null) {
      earlier.add(n);
      continue;
    }
    if (!dt.isBefore(todayStart)) {
      today.add(n);
    } else if (!dt.isBefore(yesterdayStart)) {
      yesterday.add(n);
    } else if (!dt.isBefore(weekStart)) {
      thisWeek.add(n);
    } else {
      earlier.add(n);
    }
  }

  int compare(AppNotification a, AppNotification b) {
    final ad = a.createdAtDt;
    final bd = b.createdAtDt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  }

  for (final bucket in [today, yesterday, thisWeek, earlier]) {
    bucket.sort(compare);
  }

  final out = <(String, List<AppNotification>)>[];
  if (today.isNotEmpty) out.add(('Today', today));
  if (yesterday.isNotEmpty) out.add(('Yesterday', yesterday));
  if (thisWeek.isNotEmpty) out.add(('This week', thisWeek));
  if (earlier.isNotEmpty) out.add(('Earlier', earlier));
  return out;
}

void showNotifications(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _NotificationCenterSheet(),
  );
}

class _NotificationCenterSheet extends StatefulWidget {
  const _NotificationCenterSheet();

  @override
  State<_NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<_NotificationCenterSheet> {
  _MemberNotificationFilter _filter = _MemberNotificationFilter.all;
  bool _loading = false;
  String? _loadError;
  int? _openingNotificationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  List<AppNotification> _filtered(List<AppNotification> all) {
    final requestor = _isRequestorAccount();
    final filter = requestor && _filter == _MemberNotificationFilter.evaluations
        ? _MemberNotificationFilter.all
        : _filter;
    return all.where((n) => _matchesFilter(n, filter, requestor: requestor)).toList();
  }

  int _filterCount(List<AppNotification> all, _MemberNotificationFilter filter) {
    final requestor = _isRequestorAccount();
    return all.where((n) => _matchesFilter(n, filter, requestor: requestor)).length;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await memberDataController.refreshNotifications();
    } catch (e) {
      if (mounted) _loadError = e.toString().replaceFirst('ApiException: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.read) return;
    if (n.id > 0) {
      await memberDataController.markNotificationRead(n.id);
    } else {
      memberDataController.markNotificationReadInMemory(n);
    }
  }

  Future<void> _markAllRead() async {
    await memberDataController.markAllNotificationsRead();
    if (!mounted) return;
    showMobileToast(context, 'All notifications marked as read');
  }

  Future<void> _clearRead() async {
    final hasRead = appState.notifications.any((n) => n.read);
    if (!hasRead) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Clear read notifications?'),
        content: const Text(
          'Read items will be removed from this list. You can still see new alerts when they arrive.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await memberDataController.clearReadNotifications();
    if (!mounted) return;
    showMobileToast(context, 'Read notifications cleared');
  }

  Future<void> _openSettings() async {
    final requestor = _isRequestorAccount();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => requestor
            ? const RequestorNotificationSettingsScreen()
            : const NotificationSettingsScreen(),
      ),
    );
  }

  Future<void> _onNotificationTap(AppNotification n) async {
    setState(() => _openingNotificationId = n.id);
    try {
      await handleNotificationTap(context, n);
    } finally {
      if (mounted) setState(() => _openingNotificationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final isRequestor = _isRequestorAccount();
            final all = appState.notifications;
            final unread = all.where((n) => !n.read).length;
            final filtered = _filtered(all);
            final groups = _groupByTime(filtered);
            final pagePad = mobilePagePaddingOf(context);

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_sheetTopRadius)),
              child: Material(
                color: kBg,
                child: Column(
                  children: [
                    _NotificationsGradientHeader(
                      title: isRequestor ? 'Request alerts' : 'Notifications',
                      unreadCount: unread,
                      loading: _loading,
                      onRefresh: _loading ? null : _refresh,
                      onClose: () => Navigator.pop(context),
                      onSettings: _openSettings,
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -_sheetOverlap),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: kSurface,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(_sheetTopRadius),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 24,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RefreshIndicator(
                            color: kAccent,
                            onRefresh: _refresh,
                            child: CustomScrollView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                if (unread > 0)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(pagePad, 16, pagePad, 0),
                                      child: _UnreadSummaryBar(
                                        unreadCount: unread,
                                        onMarkAllRead: _markAllRead,
                                      ),
                                    ),
                                  ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(pagePad, 14, pagePad, 4),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _notificationFiltersFor(requestor: isRequestor).map((f) {
                                          final count = _filterCount(all, f);
                                          final selected = _filter == f;
                                          final label = _filterLabel(f, requestor: isRequestor);
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: _FilterPill(
                                              label: count > 0 && f != _MemberNotificationFilter.all
                                                  ? '$label $count'
                                                  : label,
                                              selected: selected,
                                              onTap: () => setState(() => _filter = f),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_loadError != null)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(pagePad, 8, pagePad, 0),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: kRed.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: kRed.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline, color: kRed, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _loadError!,
                                                style: memberDashboardMetaStyle.copyWith(
                                                  color: kRed,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _refresh,
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_loading && filtered.isEmpty)
                                  const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: kAccent,
                                      ),
                                    ),
                                  )
                                else if (filtered.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _NotificationsEmptyState(
                                      filter: _filter,
                                      requestor: isRequestor,
                                    ),
                                  )
                                else
                                  for (final group in groups) ...[
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(pagePad, 16, pagePad, 8),
                                        child: Text(
                                          group.$1,
                                          style: dashText(const TextStyle(
                                            color: kTextSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          )),
                                        ),
                                      ),
                                    ),
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 4),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, i) {
                                            final n = group.$2[i];
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 10),
                                              child: _NotificationCard(
                                                notification: n,
                                                requestor: isRequestor,
                                                opening: _openingNotificationId == n.id,
                                                onTap: () => _onNotificationTap(n),
                                                onMarkRead: () => _markRead(n),
                                              ),
                                            );
                                          },
                                          childCount: group.$2.length,
                                        ),
                                      ),
                                    ),
                                  ],
                                SliverToBoxAdapter(
                                  child: SafeArea(
                                    top: false,
                                    minimum: EdgeInsets.fromLTRB(pagePad, 8, pagePad, 12),
                                    child: Column(
                                      children: [
                                        TextButton.icon(
                                          onPressed: appState.notifications.any((n) => n.read)
                                              ? _clearRead
                                              : null,
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          label: const Text('Clear read notifications'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: kTextSecondary,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _openSettings,
                                          icon: const Icon(Icons.tune_rounded, size: 18),
                                          label: const Text('Notification preferences'),
                                          style: TextButton.styleFrom(foregroundColor: kAccent),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationsGradientHeader extends StatelessWidget {
  const _NotificationsGradientHeader({
    required this.title,
    required this.unreadCount,
    required this.loading,
    required this.onClose,
    required this.onSettings,
    this.onRefresh,
  });

  final String title;
  final int unreadCount;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _notificationsHeaderGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, _sheetOverlap + 10),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: dashText(const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.15,
                          )),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unreadCount == 0
                              ? 'You are all caught up'
                              : '$unreadCount unread ${unreadCount == 1 ? 'alert' : 'alerts'}',
                          style: dashText(TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          )),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    ),
                  IconButton(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadSummaryBar extends StatelessWidget {
  const _UnreadSummaryBar({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, color: kAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$unreadCount unread',
              style: dashText(const TextStyle(
                color: kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
            ),
          ),
          TextButton(
            onPressed: onMarkAllRead,
            style: TextButton.styleFrom(
              foregroundColor: kAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Mark all read',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? kAccent : kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? kAccent : kAccent.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: dashText(TextStyle(
              color: selected ? Colors.white : kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            )),
          ),
        ),
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
    required this.filter,
    required this.requestor,
  });

  final _MemberNotificationFilter filter;
  final bool requestor;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (filter) {
      _MemberNotificationFilter.unread => (
          Icons.done_all_rounded,
          'No unread notifications',
          'New assignments, evaluations, and alerts will show up here.',
        ),
      _MemberNotificationFilter.assignments => (
          Icons.assignment_outlined,
          requestor ? 'No request updates' : 'No assignment alerts',
          requestor
              ? 'Status changes on your documentation requests appear here.'
              : 'New task assignments and coverage updates appear here.',
        ),
      _MemberNotificationFilter.evaluations => (
          Icons.analytics_outlined,
          'No evaluation alerts',
          'AI review outcomes and evaluation results appear here.',
        ),
      _MemberNotificationFilter.alerts => (
          Icons.campaign_outlined,
          'No announcements',
          'System announcements and feedback reminders appear here.',
        ),
      _ => (
          Icons.notifications_off_outlined,
          'No notifications yet',
          requestor
              ? 'When an admin updates your documentation request, it will appear here.'
              : 'Assignments, evaluations, and system alerts will appear here.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: kTextSecondary.withValues(alpha: 0.45)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: dashText(TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.45,
            )),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.requestor,
    required this.onTap,
    required this.onMarkRead,
    this.opening = false,
  });

  final AppNotification notification;
  final bool requestor;
  final VoidCallback onTap;
  final Future<void> Function() onMarkRead;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final timeLabel = n.createdAt ?? 'Recently';
    final categoryLabel = _categoryLabel(n, requestor: requestor);
    final actionHint = _actionHint(n, requestor: requestor);

    Widget card = Material(
      color: n.read ? kSurface : kAccent.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: opening ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.read ? kBorder.withValues(alpha: 0.9) : kAccent.withValues(alpha: 0.22),
            ),
            boxShadow: [
              if (!n.read)
                BoxShadow(
                  color: kAccent.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: n.read ? Colors.transparent : kAccent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: n.color.withValues(alpha: n.read ? 0.08 : 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(n.icon, color: n.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: n.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      categoryLabel,
                                      style: dashText(TextStyle(
                                        color: n.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      )),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    timeLabel,
                                    style: dashText(TextStyle(
                                      color: kTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    )),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 14,
                                  fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                                  height: 1.25,
                                )),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                )),
                              ),
                              if (actionHint != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      actionHint,
                                      style: dashText(const TextStyle(
                                        color: kAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      )),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: kAccent,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (opening)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kAccent,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 10),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: kTextSecondary.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (n.read) return card;

    return Dismissible(
      key: ValueKey('notif-${n.id}-${n.title}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.done_rounded, color: kGreen),
            SizedBox(width: 6),
            Text(
              'Mark read',
              style: TextStyle(
                color: kGreen,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await onMarkRead();
        return false;
      },
      child: card,
    );
  }
}
