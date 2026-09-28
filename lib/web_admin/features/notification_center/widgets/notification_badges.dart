import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/notification_center/notification_center_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final NotificationDisplayPriority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priority.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priority.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priority.icon, size: 12, color: priority.color),
          const SizedBox(width: 4),
          Text(priority.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priority.color)),
        ],
      ),
    );
  }
}

class ModuleBadge extends StatelessWidget {
  const ModuleBadge({super.key, required this.module});

  final NotificationModule module;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Text(module.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary)),
    );
  }
}
