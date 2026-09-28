import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/gemini_service.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/features/notifications/notification_models.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_activity_timeline.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.items, required this.onNavigate});

  final List<AdminActivityItem> items;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Recent Activity',
            subtitle: 'Latest system updates across requests, media, and members',
            trailing: HomeTextButton(label: 'View all', onPressed: () => onNavigate(AdminRoute.docRequests)),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const AdminEmptyState(title: 'No recent activity', message: 'Activity will appear as your team works.')
          else
            AdminActivityTimeline(items: items),
        ],
      ),
    );
  }
}

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key, required this.items, required this.onNavigate});

  final List<AdminNotificationItem> items;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Notifications',
            trailing: HomeTextButton(label: 'View all', onPressed: () => onNavigate(AdminRoute.notifications)),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const AdminEmptyState(
              title: 'No notifications',
              message: 'You\'re all caught up.',
              icon: Icons.notifications_none_outlined,
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _NotificationRow(item: items[i], onTap: () {
                    final route = items[i].route ?? AdminRoute.notifications;
                    onNavigate(route);
                  }),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final AdminNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.unread ? AdminTheme.accentBlue.withValues(alpha: 0.04) : AdminTheme.contentBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 18, color: item.accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: item.unread ? FontWeight.w700 : FontWeight.w600,
                              color: AdminTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(color: AdminTheme.danger, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.timeAgo,
                      style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaEvaluationQueuePanel extends StatelessWidget {
  const MediaEvaluationQueuePanel({
    super.key,
    required this.queue,
    required this.onNavigate,
  });

  final MediaQueueSnapshot queue;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeSectionHeader(
            title: 'Media Integrity',
            subtitle: 'AI-generated media review alerts',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QueueStat(
                  label: 'Pending',
                  value: '${queue.pendingCount}',
                  color: AdminTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QueueStat(
                  label: 'Completed today',
                  value: '${queue.completedToday}',
                  color: AdminTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          HomePrimaryButton(
            label: 'Open Media Integrity',
            icon: Icons.verified_user_outlined,
            onPressed: () => onNavigate(AdminRoute.mediaEvaluation),
          ),
        ],
      ),
    );
  }
}

class _QueueStat extends StatelessWidget {
  const _QueueStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
        ],
      ),
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.onNavigate});

  final HomeNavigate onNavigate;

  static const _actions = [
    (Icons.fact_check_outlined, 'Review Requests', AdminRoute.docRequests, null),
    (Icons.person_add_alt_1_outlined, 'Assign Members', AdminRoute.docRequests, {'docMgmtTab': 'taskStatus'}),
    (Icons.cloud_upload_outlined, 'Upload Media', AdminRoute.mediaRepository, null),
    (Icons.campaign_outlined, 'Create Announcement', AdminRoute.notifications, null),
    (Icons.manage_accounts_outlined, 'Manage Users', AdminRoute.members, null),
    (Icons.bar_chart_outlined, 'Open Analytics', AdminRoute.analyticsDashboard, null),
  ];

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeSectionHeader(title: 'Quick Actions', subtitle: 'One-click shortcuts to common tasks'),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 360 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cols == 2 ? 2.8 : 3.6,
                children: [
                  for (final (icon, label, route, params) in _actions)
                    _QuickActionTile(
                      icon: icon,
                      label: label,
                      onTap: () => onNavigate(route, params: params),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.06) : AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.35) : AdminTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: AdminTheme.accentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 16, color: AdminTheme.textSecondary.withValues(alpha: _hovered ? 1 : 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnnouncementsPanel extends StatelessWidget {
  const AnnouncementsPanel({super.key, required this.items});

  final List<AnnouncementItem> items;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeSectionHeader(title: 'Announcements', subtitle: 'System updates and reminders'),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          items[i].title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
                        ),
                      ),
                      Text(items[i].dateLabel, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].body,
                    style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AiSummaryPanel extends StatefulWidget {
  const AiSummaryPanel({super.key, required this.snapshot});

  final HomeDashboardSnapshot snapshot;

  @override
  State<AiSummaryPanel> createState() => _AiSummaryPanelState();
}

class _AiSummaryPanelState extends State<AiSummaryPanel> {
  String? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant AiSummaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    final snap = widget.snapshot;
    final o = snap.overview;
    final gemini = await GeminiService.generateDailySummary(
      pendingRequests: o.pendingRequests,
      todayEvents: o.todayEvents,
      mediaPending: o.mediaPendingEvaluation,
      unreadNotifications: o.unreadNotifications,
      pendingMembers: snap.pendingMembers,
    );
    if (!mounted) return;
    setState(() {
      _summary = gemini ?? _localSummary(snap);
      _loading = false;
    });
  }

  String _localSummary(HomeDashboardSnapshot snap) {
    final parts = <String>[];
    final o = snap.overview;
    if (o.pendingRequests > 0) parts.add('${o.pendingRequests} pending request(s) need review.');
    if (o.todayEvents > 0) parts.add('${o.todayEvents} event(s) scheduled today.');
    if (o.mediaPendingEvaluation > 0) parts.add('${o.mediaPendingEvaluation} media item(s) await evaluation.');
    if (parts.isEmpty) return 'Operations look clear. Monitor Today\'s Schedule and notifications for updates.';
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      backgroundColor: const Color(0xFFF0F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: AdminTheme.accentBlue),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Daily Summary',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 48,
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            Text(
              _summary ?? '',
              style: const TextStyle(fontSize: 13, color: AdminTheme.textPrimary, height: 1.5),
            ),
          const SizedBox(height: 6),
          Text(
            'Powered by Google Gemini',
            style: TextStyle(fontSize: 10, color: AdminTheme.textSecondary.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class ViewAnalyticsBanner extends StatelessWidget {
  const ViewAnalyticsBanner({super.key, required this.onNavigate});

  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C4E8), Color(0xFF0052D4)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
        boxShadow: AdminTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need deeper insights?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Charts, trends, and performance reports live on the Analytics page.',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => onNavigate(AdminRoute.analyticsDashboard),
            icon: const Icon(Icons.insights_outlined, size: 18),
            label: const Text('View Full Analytics'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AdminTheme.accentBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
