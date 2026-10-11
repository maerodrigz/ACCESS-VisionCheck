import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/navigation/notification_navigation.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/app_notification_mapper.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

const _sheetTopRadius = 20.0;

// ── Filter helpers ───────────────────────────────────────────────────────────

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

bool _matchesFilter(
  AppNotification n,
  _MemberNotificationFilter filter, {
  required bool requestor,
}) {
  return switch (filter) {
    _MemberNotificationFilter.all => true,
    _MemberNotificationFilter.unread => !n.read,
    _MemberNotificationFilter.assignments => requestor
        ? n.category == 'documentation_request'
        : n.category == 'task_assignment' || n.category == 'documentation_request',
    _MemberNotificationFilter.evaluations =>
      n.category == 'media_evaluation' ||
      n.category == 'ai_detection' ||
      n.actionType == 'milestone' ||
      n.actionType == 'view_admin_feedback',
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

/// Sanitised display title — avoids claiming AI-generation before confirmation.
String _displayTitle(AppNotification n) {
  final t = n.title.trim();
  if (n.category == 'ai_detection') {
    final lower = t.toLowerCase();
    // Only keep "confirmed" wording if admin has confirmed
    if (lower.contains('confirmed') || lower.contains('policy violation')) return t;
    // Rephrase overly aggressive titles
    if (lower.contains('ai-generated') ||
        lower.contains('ai generated') ||
        lower.contains('generated media')) {
      return 'Media under review';
    }
    if (lower.contains('flagged') || lower.contains('suspicious')) {
      return 'Media flagged for review';
    }
    if (lower.contains('complete') || lower.contains('result')) {
      return 'Media review completed';
    }
  }
  return t;
}

// ── Time grouping ─────────────────────────────────────────────────────────────

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
  if (thisWeek.isNotEmpty) out.add(('This Week', thisWeek));
  if (earlier.isNotEmpty) out.add(('Earlier', earlier));
  return out;
}

// ── Entry point ───────────────────────────────────────────────────────────────

void showNotifications(BuildContext context) {
  unawaited(memberDataController.refreshNotifications());
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _NotificationCenterSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

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
          listenable: Listenable.merge([appState, memberDataController]),
          builder: (context, _) {
            final isRequestor = _isRequestorAccount();
            final all = appState.notifications;
            final unread = all.where((n) => !n.read).length;
            final filtered = _filtered(all);
            final groups = _groupByTime(filtered);
            final pagePad = mobilePagePaddingOf(context);

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_sheetTopRadius),
              ),
              child: Material(
                color: kBg,
                child: Column(
                  children: [
                    // ── Light header ─────────────────────────────────────
                    _NotificationsLightHeader(
                      title: isRequestor ? 'Request alerts' : 'Notifications',
                      unreadCount: unread,
                      loading: _loading,
                      onRefresh: _loading ? null : _refresh,
                      onClose: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: kAccent,
                        onRefresh: _refresh,
                        child: CustomScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            // ── Unread summary bar ────────────────────
                            if (unread > 0)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(pagePad, 10, pagePad, 0),
                                  child: _UnreadSummaryBar(
                                    unreadCount: unread,
                                    onMarkAllRead: _markAllRead,
                                  ),
                                ),
                              ),
                            // ── Filter chips ──────────────────────────
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(pagePad, 10, pagePad, 2),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.none,
                                  child: Row(
                                    children: _notificationFiltersFor(requestor: isRequestor)
                                        .map((f) {
                                      final count = _filterCount(all, f);
                                      final selected = _filter == f;
                                      final label = _filterLabel(f, requestor: isRequestor);
                                      final badgeCount =
                                          f != _MemberNotificationFilter.all && count > 0
                                              ? count
                                              : 0;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 7),
                                        child: _FilterChip(
                                          label: label,
                                          badge: badgeCount > 0 ? '$badgeCount' : null,
                                          selected: selected,
                                          onTap: () => setState(() => _filter = f),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            // ── Load error ────────────────────────────
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
                                        const Icon(Icons.error_outline, color: kRed, size: 16),
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
                            // ── List / empty ──────────────────────────
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
                                    padding: EdgeInsets.fromLTRB(pagePad, 14, pagePad, 6),
                                    child: Text(
                                      group.$1,
                                      style: dashText(const TextStyle(
                                        color: kTextSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      )),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 2),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        final n = group.$2[i];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
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
                            // ── Footer actions ────────────────────────
                            SliverToBoxAdapter(
                              child: SafeArea(
                                top: false,
                                minimum: EdgeInsets.fromLTRB(pagePad, 6, pagePad, 10),
                                child: Column(
                                  children: [
                                    TextButton.icon(
                                      onPressed: appState.notifications.any((n) => n.read)
                                          ? _clearRead
                                          : null,
                                      icon: const Icon(Icons.delete_outline, size: 16),
                                      label: const Text('Clear read notifications'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: kTextSecondary,
                                        textStyle: const TextStyle(fontSize: 12),
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

// ─────────────────────────────────────────────────────────────────────────────
// Light header — replaces the cyan/blue gradient header
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsLightHeader extends StatelessWidget {
  const _NotificationsLightHeader({
    required this.title,
    required this.unreadCount,
    required this.loading,
    required this.onClose,
    this.onRefresh,
  });

  final String title;
  final int unreadCount;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(
          bottom: BorderSide(color: kBorder.withValues(alpha: 0.7)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Close
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: kTextSecondary,
                    iconSize: 22,
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                  // Title + unread count
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          title,
                          style: dashText(const TextStyle(
                            color: kTextPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.2,
                          )),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '$unreadCount unread',
                              style: dashText(const TextStyle(
                                color: kAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              )),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Refresh
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kAccent,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      color: kTextSecondary,
                      iconSize: 20,
                      tooltip: 'Refresh',
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact unread summary bar
// ─────────────────────────────────────────────────────────────────────────────

class _UnreadSummaryBar extends StatelessWidget {
  const _UnreadSummaryBar({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$unreadCount unread',
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )),
        ),
        const Spacer(),
        TextButton(
          onPressed: onMarkAllRead,
          style: TextButton.styleFrom(
            foregroundColor: kAccent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          child: const Text('Mark all read'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontally scrollable filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? kAccent : kSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? kAccent : kBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: dashText(TextStyle(
                  color: selected ? Colors.white : kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: selected ? Colors.white : kAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact notification card
// ─────────────────────────────────────────────────────────────────────────────

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
    final presentation = notificationPresentation(n, requestor: requestor);
    final categoryLabel = presentation.$1;
    final icon = presentation.$2;
    final accent = presentation.$3;
    final displayTitle = _displayTitle(n);
    final timeLabel = n.createdAt ?? '';
    final isUnread = !n.read;

    Widget card = Material(
      color: isUnread ? kAccent.withValues(alpha: 0.04) : kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: opening ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread ? accent.withValues(alpha: 0.2) : kBorder.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon tile ──────────────────────────────────────────
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isUnread ? 0.12 : 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                // ── Content ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category badge + time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryLabel,
                              style: dashText(TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                            ),
                          ),
                          const Spacer(),
                          if (timeLabel.isNotEmpty)
                            Text(
                              timeLabel,
                              style: dashText(const TextStyle(
                                color: kTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              )),
                            ),
                          // Unread dot
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Title
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          height: 1.3,
                        )),
                      ),
                      const SizedBox(height: 3),
                      // Body preview
                      Text(
                        n.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12,
                          height: 1.4,
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // ── Loading / chevron ──────────────────────────────────
                if (opening)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Swipe to mark read (unread only)
    if (isUnread) {
      card = Dismissible(
        key: ValueKey('notif-${n.id}-${n.title}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(
            color: kGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreen.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.done_rounded, color: kGreen, size: 18),
              SizedBox(width: 5),
              Text(
                'Mark read',
                style: TextStyle(
                  color: kGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

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
          Icon(icon, size: 48, color: kTextSecondary.withValues(alpha: 0.4)),
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
            style: dashText(const TextStyle(
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
