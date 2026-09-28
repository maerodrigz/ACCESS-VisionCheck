import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/notification_center/notification_center_models.dart';
import 'package:access_mobile/web_admin/features/notification_center/widgets/notification_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef NotificationAction = void Function(CenterNotificationItem item);

class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onMarkRead,
    required this.onDelete,
    this.compact = false,
  });

  final CenterNotificationItem item;
  final NotificationAction onOpen;
  final NotificationAction onMarkRead;
  final NotificationAction onDelete;
  final bool compact;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _hovered = false;

  CenterNotificationItem get n => widget.item;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: n.unread ? AdminTheme.accentBlue.withValues(alpha: 0.04) : AdminTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.unread
                ? AdminTheme.accentBlue.withValues(alpha: 0.28)
                : (_hovered ? AdminTheme.accentBlue.withValues(alpha: 0.2) : AdminTheme.border),
          ),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 14 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: n.displayPriority.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(n.module.icon, color: n.displayPriority.color, size: 22),
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
                              fontSize: 14,
                              fontWeight: n.unread ? FontWeight.w800 : FontWeight.w700,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (n.unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(color: AdminTheme.accentBlue, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(n.message, style: const TextStyle(fontSize: 12, height: 1.4, color: AdminTheme.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ModuleBadge(module: n.module),
                        PriorityBadge(priority: n.displayPriority),
                        Text(n.timeLabel, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => widget.onOpen(n),
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminTheme.accentBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(n.actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        if (n.unread)
                          OutlinedButton(
                            onPressed: () => widget.onMarkRead(n),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Mark as Read', style: TextStyle(fontSize: 12)),
                          ),
                        IconButton(
                          onPressed: () => widget.onDelete(n),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
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
