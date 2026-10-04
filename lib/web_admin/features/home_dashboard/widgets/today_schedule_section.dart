import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

class TodayScheduleSection extends StatelessWidget {
  const TodayScheduleSection({
    super.key,
    required this.items,
    required this.onNavigate,
  });

  final List<TodayScheduleItem> items;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: "Today's Schedule",
            subtitle: 'Upcoming and ongoing events.',
            icon: Icons.calendar_month_outlined,
            iconColor: AdminTheme.accentBlue,
            trailing: HomeTextButton(
              label: 'Open calendar',
              icon: Icons.chevron_right_rounded,
              onPressed: () => onNavigate(AdminRoute.eventCalendar),
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const AdminEmptyState(
              title: 'No events scheduled today',
              message: 'Enjoy your day!',
              icon: Icons.event_available_outlined,
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 0),
                  _ScheduleRow(item: items[i], isLast: i == items.length - 1),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item, required this.isLast});

  final TodayScheduleItem item;
  final bool isLast;

  Color get _dotColor {
    final s = item.status.toLowerCase();
    if (s.contains('ongoing') || s.contains('live')) return AdminTheme.success;
    if (s.contains('done') || s.contains('complete')) return AdminTheme.textSecondary;
    return AdminTheme.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AdminTheme.textSecondary,
                ),
              ),
            ),
          ),
          // Timeline connector
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: _dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AdminTheme.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Event details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: item.eventName.isEmpty
                  ? _NoEventRow()
                  : _EventDetailRow(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoEventRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No events scheduled',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Enjoy your day!',
          style: TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({required this.item});

  final TodayScheduleItem item;

  Color get _statusColor {
    final s = item.status.toLowerCase();
    if (s.contains('upcoming')) return AdminTheme.accentBlue;
    if (s.contains('ongoing') || s.contains('live')) return AdminTheme.success;
    if (s.contains('done') || s.contains('complete')) return AdminTheme.textSecondary;
    return AdminTheme.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AdminTheme.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.eventName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.location != null && item.location!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AdminTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${item.location}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.documenterCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Documenters: ${item.documenterCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ] else if (item.documenterCount > 0) ...[
                const SizedBox(height: 3),
                Text(
                  'Documenters: ${item.documenterCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
