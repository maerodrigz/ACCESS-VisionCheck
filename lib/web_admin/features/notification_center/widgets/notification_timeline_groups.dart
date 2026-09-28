import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/notification_center/notification_center_models.dart';
import 'package:access_mobile/web_admin/features/notification_center/widgets/notification_card.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class NotificationTimelineGroups extends StatelessWidget {
  const NotificationTimelineGroups({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onMarkRead,
    required this.onDelete,
    this.compact = false,
  });

  final List<CenterNotificationItem> items;
  final NotificationAction onOpen;
  final NotificationAction onMarkRead;
  final NotificationAction onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final groups = NotificationTimelineGroup.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          if (items.any((n) => n.timelineGroup == group)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text(group.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminTheme.textSecondary)),
            ),
            for (final n in items.where((i) => i.timelineGroup == group))
              NotificationCard(
                item: n,
                compact: compact,
                onOpen: onOpen,
                onMarkRead: onMarkRead,
                onDelete: onDelete,
              ),
          ],
        ],
      ],
    );
  }
}

class NotificationSectionHeader extends StatelessWidget {
  const NotificationSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
    required this.color,
  });

  final String title;
  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}
