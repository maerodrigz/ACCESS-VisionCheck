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
    final cards = [
      _CardConfig(
        icon: Icons.description_outlined,
        label: 'Pending Requests',
        sublabel: 'needs approval',
        value: stats.pendingRequests,
        color: AdminTheme.danger,
        bgColor: const Color(0xFFFFF5F5),
        route: AdminRoute.docRequests,
      ),
      _CardConfig(
        icon: Icons.calendar_today_outlined,
        label: "Today's Events",
        sublabel: 'scheduled today',
        value: stats.todayEvents,
        color: AdminTheme.accentBlue,
        bgColor: const Color(0xFFF0F5FF),
        route: AdminRoute.eventCalendar,
      ),
      _CardConfig(
        icon: Icons.photo_library_outlined,
        label: 'Media Awaiting Review',
        sublabel: 'for AI evaluation',
        value: stats.mediaPendingEvaluation,
        color: AdminTheme.accentCyan,
        bgColor: const Color(0xFFF0FBFF),
        route: AdminRoute.mediaEvaluation,
      ),
      _CardConfig(
        icon: Icons.notifications_outlined,
        label: 'Unread Alerts',
        sublabel: 'new notifications',
        value: stats.unreadNotifications,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F0FF),
        route: AdminRoute.notifications,
        badge: stats.unreadNotifications,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols == 4 ? 1.8 : cols == 2 ? 2.2 : 3.5,
          children: cards.map((c) => _OverviewCard(
            config: c,
            onTap: () => onNavigate(c.route),
          )).toList(),
        );
      },
    );
  }
}

class _CardConfig {
  const _CardConfig({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.route,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final int value;
  final Color color;
  final Color bgColor;
  final AdminRoute route;
  final int badge;
}

class _OverviewCard extends StatefulWidget {
  const _OverviewCard({required this.config, required this.onTap});

  final _CardConfig config;
  final VoidCallback onTap;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.config;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AdminTheme.surface,
            borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
            border: Border.all(
              color: _hovered ? c.color.withValues(alpha: 0.4) : AdminTheme.border,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: c.color.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AdminTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon tile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(c.icon, size: 24, color: c.color),
              ),
              const SizedBox(width: 14),
              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      c.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminTheme.textSecondary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.value}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AdminTheme.textPrimary,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.sublabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AdminTheme.textSecondary.withValues(alpha: 0.85),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _hovered ? c.color : AdminTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
