import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/notifications/notification_models.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';

/// Modern notification center — dropdown on desktop, bottom sheet on mobile.
class NotificationCenterPanel extends StatefulWidget {
  const NotificationCenterPanel({
    super.key,
    required this.notifications,
    required this.onRefresh,
    required this.onMarkAllRead,
    required this.onClearRead,
    required this.onMarkRead,
    required this.onClose,
    this.loading = false,
    this.scrollController,
  });

  final List<AdminNotificationItem> notifications;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onMarkAllRead;
  final Future<void> Function() onClearRead;
  final Future<void> Function(int id) onMarkRead;
  final VoidCallback onClose;
  final bool loading;
  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required List<AdminNotificationItem> notifications,
    required Future<void> Function() onRefresh,
    required Future<void> Function() onMarkAllRead,
    required Future<void> Function() onClearRead,
    required Future<void> Function(int id) onMarkRead,
    required bool loading,
  }) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return showDialog(
        context: context,
        barrierColor: Colors.black26,
        builder: (ctx) => Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 72, right: 24, left: 24, bottom: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
            child: NotificationCenterPanel(
              notifications: notifications,
              onRefresh: onRefresh,
              onMarkAllRead: onMarkAllRead,
              onClearRead: onClearRead,
              onMarkRead: onMarkRead,
              onClose: () => Navigator.pop(ctx),
              loading: loading,
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => NotificationCenterPanel(
          notifications: notifications,
          onRefresh: onRefresh,
          onMarkAllRead: onMarkAllRead,
          onClearRead: onClearRead,
          onMarkRead: onMarkRead,
          onClose: () => Navigator.pop(ctx),
          loading: loading,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<NotificationCenterPanel> createState() => _NotificationCenterPanelState();
}

class _NotificationCenterPanelState extends State<NotificationCenterPanel> {
  NotificationFilterTab _tab = NotificationFilterTab.all;

  int get _unreadCount => widget.notifications.where((n) => n.unread).length;

  List<AdminNotificationItem> get _filtered =>
      widget.notifications.where((n) => n.matchesFilter(_tab)).toList();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminTheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 12,
      shadowColor: const Color(0xFF0F2744).withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          _filterTabs(),
          const Divider(height: 1),
          Expanded(
            child: widget.loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filtered.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NotificationCard(
                          item: _filtered[i],
                          onTap: () => _openItem(_filtered[i]),
                          onAction: () => _openItem(_filtered[i], action: true),
                        ),
                      ),
          ),
          const Divider(height: 1),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
      child: Row(
        children: [
          const AccessBrandMark.iconOnly(logoSize: 22),
          const SizedBox(width: 10),
          const Icon(Icons.notifications_active_outlined, color: AdminTheme.accentCyan, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  _unreadCount > 0 ? '$_unreadCount unread' : 'All caught up',
                  style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                ),
              ],
            ),
          ),
          PageHeaderRefreshButton(
            onPressed: () => widget.onRefresh(),
            enabled: !widget.loading,
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _filterTabs() {
    const tabs = [
      (NotificationFilterTab.all, 'All'),
      (NotificationFilterTab.unread, 'Unread'),
      (NotificationFilterTab.requests, 'Requests'),
      (NotificationFilterTab.mediaEvaluation, 'Media'),
      (NotificationFilterTab.aiAlerts, 'AI Alerts'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: tabs.map((t) {
          final selected = _tab == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(t.$2, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              selected: selected,
              onSelected: (_) => setState(() => _tab = t.$1),
              selectedColor: AdminTheme.accentCyan.withValues(alpha: 0.18),
              checkmarkColor: AdminTheme.accentBlue,
              side: BorderSide(
                color: selected ? AdminTheme.accentCyan.withValues(alpha: 0.5) : AdminTheme.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: AdminTheme.textSecondary.withValues(alpha: 0.45)),
            const SizedBox(height: 12),
            const Text('No notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              _tab == NotificationFilterTab.unread
                  ? 'You have no unread notifications.'
                  : 'New activity will appear here in real time.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: _unreadCount == 0 ? null : () => widget.onMarkAllRead(),
                child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => widget.onClearRead(),
                child: const Text('Clear read', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () {
              widget.onClose();
              AdminNavigationScope.go(context, AdminRoute.notifications);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AdminTheme.accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View All Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openItem(AdminNotificationItem item, {bool action = false}) async {
    if (item.unread && item.id > 0) await widget.onMarkRead(item.id);
    if (!mounted) return;
    widget.onClose();
    if (item.route != null) AdminNavigationScope.go(context, item.route!);
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({required this.item, required this.onTap, required this.onAction});
  final AdminNotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.item;
    final priorityColor = switch (n.priority) {
      NotificationPriority.high => AdminTheme.danger,
      NotificationPriority.low => AdminTheme.textSecondary,
      NotificationPriority.normal => AdminTheme.accentBlue,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: n.unread
              ? AdminTheme.accentCyan.withValues(alpha: _hovered ? 0.12 : 0.07)
              : (_hovered ? AdminTheme.contentBg : AdminTheme.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.unread
                ? AdminTheme.accentCyan.withValues(alpha: 0.35)
                : (_hovered ? AdminTheme.accentCyan.withValues(alpha: 0.25) : AdminTheme.border),
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: const Color(0xFF0F2744).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: n.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(n.icon, color: n.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: n.unread ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (n.unread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AdminTheme.danger, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _chip(n.categoryLabel, n.accentColor),
                          _chip(n.priorityLabel, priorityColor),
                          Text(n.timeAgo, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                        ],
                      ),
                      if (n.actionButtonLabel != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: widget.onAction,
                            icon: const Icon(Icons.arrow_forward, size: 14),
                            label: Text(n.actionButtonLabel!, style: const TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: AdminTheme.accentBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Calendar shortcut — matches [NotificationBell] styling in the top bar.
class EventCalendarButton extends StatelessWidget {
  const EventCalendarButton({
    super.key,
    required this.onOpen,
    this.active = false,
  });

  final VoidCallback onOpen;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Event Calendar',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? AdminTheme.accentBlue.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AdminTheme.accentBlue.withValues(alpha: 0.35) : AdminTheme.border,
            ),
          ),
          child: Icon(
            Icons.calendar_month_outlined,
            color: active ? AdminTheme.accentBlue : AdminTheme.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Bell trigger with unread badge — opens [NotificationCenterPanel].
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.unreadCount,
    required this.onOpen,
  });

  final int unreadCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: unreadCount > 0 ? '$unreadCount unread notifications' : 'Notifications',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.border),
              ),
              child: const Icon(Icons.notifications_outlined, color: AdminTheme.textPrimary, size: 22),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.surface, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
