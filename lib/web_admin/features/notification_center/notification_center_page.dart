import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/notification_center/notification_center_models.dart';
import 'package:access_mobile/web_admin/features/notification_center/notification_center_repository.dart';
import 'package:access_mobile/web_admin/features/notification_center/widgets/notification_overview_cards.dart';
import 'package:access_mobile/web_admin/features/notification_center/widgets/notification_timeline_groups.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Notification & Activity Center — operational hub for administrators.
class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final _repo = NotificationCenterRepository();
  final _searchController = TextEditingController();

  NotificationCenterData? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  NotificationModuleFilter _chip = NotificationModuleFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<CenterNotificationItem> get _visible {
    final data = _data;
    if (data == null) return [];
    return _repo.filter(items: data.all, chip: _chip, search: _search);
  }

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AdminTheme.success : AdminTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await _repo.markAllRead();
      await _load();
      _toast('All notifications marked as read');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _clearRead() async {
    try {
      await _repo.clearRead();
      await _load();
      _toast('Read notifications cleared');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _open(CenterNotificationItem item) async {
    if (item.unread) {
      try {
        await _repo.markRead(item.id);
      } catch (_) {}
    }
    if (!mounted) return;
    AdminNavigationScope.go(context, item.route);
    await _load();
  }

  Future<void> _markRead(CenterNotificationItem item) async {
    try {
      await _repo.markRead(item.id);
      await _load();
      _toast('Notification marked as read');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _delete(CenterNotificationItem item) async {
    try {
      await _repo.dismiss(item.id);
      await _load();
      _toast('Notification removed');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = AdminBreakpoints.pagePadding(context);
    final visible = _visible;
    final actionRequired = visible.where((n) => n.requiresAction).toList();
    final recentActivity = visible.where((n) => !n.requiresAction).toList();
    final isEmpty = !_loading && _error == null && visible.isEmpty;

    return Container(
      color: AdminTheme.contentBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding.copyWith(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by event, member, type, priority, or date…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final chip in NotificationModuleFilter.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(chip.label),
                            selected: _chip == chip,
                            onSelected: (_) => setState(() => _chip = chip),
                            selectedColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                            checkmarkColor: AdminTheme.accentBlue,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _chip == chip ? AdminTheme.accentBlue : AdminTheme.textSecondary,
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.accentBlue))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: isEmpty
                            ? const AdminEmptyState(
                                key: ValueKey('empty'),
                                title: "You're all caught up!",
                                message: 'No new notifications.',
                                icon: Icons.notifications_none_outlined,
                              )
                            : SingleChildScrollView(
                                key: const ValueKey('content'),
                                padding: padding.copyWith(top: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_data != null) NotificationOverviewCards(stats: _data!.stats),
                                    const SizedBox(height: 28),
                                    if (actionRequired.isNotEmpty) ...[
                                      NotificationSectionHeader(
                                        title: 'Action Required',
                                        icon: Icons.error_outline,
                                        count: actionRequired.length,
                                        color: AdminTheme.danger,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Items that need your attention — review, approve, or respond.',
                                        style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 14),
                                      NotificationTimelineGroups(
                                        items: actionRequired,
                                        onOpen: _open,
                                        onMarkRead: _markRead,
                                        onDelete: _delete,
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                    if (recentActivity.isNotEmpty) ...[
                                      NotificationSectionHeader(
                                        title: 'Recent Activity',
                                        icon: Icons.campaign_outlined,
                                        count: recentActivity.length,
                                        color: AdminTheme.accentBlue,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Informational updates from across ACCESS VisionCheck.',
                                        style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 14),
                                      NotificationTimelineGroups(
                                        items: recentActivity,
                                        compact: true,
                                        onOpen: _open,
                                        onMarkRead: _markRead,
                                        onDelete: _delete,
                                      ),
                                    ],
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final narrow = AdminBreakpoints.widthOf(context) < 720;
    final unread = _data?.stats.unread ?? 0;

    final actions = [
      if (!narrow)
        OutlinedButton.icon(
          onPressed: unread == 0 || _loading ? null : _markAllRead,
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark All as Read'),
        ),
      if (!narrow) const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: _loading ? null : _clearRead,
        icon: const Icon(Icons.cleaning_services_outlined, size: 18),
        label: Text(narrow ? 'Clear Read' : 'Clear Read Notifications'),
      ),
      const SizedBox(width: 8),
      PageHeaderRefreshButton(onPressed: _load, enabled: !_loading),
    ];

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Center',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Central hub for system events, alerts, and reminders across all modules.',
            style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notification Center',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
              ),
              SizedBox(height: 6),
              Text(
                'Central hub for system events, alerts, and reminders across all modules.',
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}
