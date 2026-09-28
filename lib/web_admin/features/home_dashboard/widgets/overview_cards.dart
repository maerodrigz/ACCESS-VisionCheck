import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

class OverviewStatCards extends StatelessWidget {
  const OverviewStatCards({super.key, required this.stats, required this.onNavigate});

  final HomeOverviewStats stats;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 5 : c.maxWidth >= 640 ? 3 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols >= 5 ? 1.55 : 1.45,
          children: [
            _OverviewCard(
              icon: Icons.mark_email_unread_outlined,
              label: 'Pending Requests',
              value: '${stats.pendingRequests}',
              color: AdminTheme.danger,
              onTap: () => onNavigate(AdminRoute.docRequests),
            ),
            _OverviewCard(
              icon: Icons.event_outlined,
              label: 'Today\'s Events',
              value: '${stats.todayEvents}',
              color: AdminTheme.accentBlue,
              onTap: () => onNavigate(AdminRoute.eventCalendar),
            ),
            _OverviewCard(
              icon: Icons.psychology_outlined,
              label: 'Integrity Alerts',
              value: '${stats.mediaPendingEvaluation}',
              color: const Color(0xFF0891B2),
              onTap: () => onNavigate(AdminRoute.mediaEvaluation),
            ),
            _OverviewCard(
              icon: Icons.groups_outlined,
              label: 'Active Members',
              value: '${stats.activeMembers}',
              color: AdminTheme.success,
              onTap: () => onNavigate(AdminRoute.members),
            ),
            _OverviewCard(
              icon: Icons.notifications_outlined,
              label: 'Unread Alerts',
              value: '${stats.unreadNotifications}',
              color: const Color(0xFF7C3AED),
              badge: stats.unreadNotifications > 0,
              onTap: () => onNavigate(AdminRoute.notifications),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewCard extends StatefulWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final bool badge;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: AdminTheme.surface,
        elevation: _hovered ? 2 : 0,
        shadowColor: const Color(0x140F2744),
        borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
              border: Border.all(color: _hovered ? widget.color.withValues(alpha: 0.35) : AdminTheme.border),
              boxShadow: _hovered ? AdminTheme.cardShadow : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, size: 20, color: widget.color),
                      ),
                      if (widget.badge) ...[
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AdminTheme.danger, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.value,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, height: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AdminTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
