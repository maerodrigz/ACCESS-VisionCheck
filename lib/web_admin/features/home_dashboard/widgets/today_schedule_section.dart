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
            title: 'Today\'s Schedule',
            subtitle: 'Approved documentation events happening today',
            trailing: HomeTextButton(
              label: 'Open calendar',
              onPressed: () => onNavigate(AdminRoute.eventCalendar),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const AdminEmptyState(
              title: 'Nothing scheduled today',
              message: 'No approved documentation events on today\'s calendar.',
              icon: Icons.event_available_outlined,
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ScheduleRow(item: items[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item});

  final TodayScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              item.timeLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.accentBlue),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.eventName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.assignedMembers,
                  style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HomeStatusBadge(label: item.status),
        ],
      ),
    );
  }
}
