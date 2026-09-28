import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class RequestPriorityBadge extends StatelessWidget {
  const RequestPriorityBadge({super.key, required this.priority});

  final RequestPriority priority;

  Color get _color => switch (priority) {
        RequestPriority.urgent => AdminTheme.danger,
        RequestPriority.high => const Color(0xFFEA580C),
        RequestPriority.normal => AdminTheme.accentBlue,
        RequestPriority.low => AdminTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Text(
        priority.name[0].toUpperCase() + priority.name.substring(1),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _color),
      ),
    );
  }
}

class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge({super.key, required this.status});

  final RequestDisplayStatus status;

  Color get _color => switch (status) {
        RequestDisplayStatus.pending => AdminTheme.warning,
        RequestDisplayStatus.approved => AdminTheme.accentBlue,
        RequestDisplayStatus.rejected => AdminTheme.danger,
        RequestDisplayStatus.completed => AdminTheme.success,
      };

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      RequestDisplayStatus.pending => 'Pending',
      RequestDisplayStatus.approved => 'Approved',
      RequestDisplayStatus.rejected => 'Rejected',
      RequestDisplayStatus.completed => 'Completed',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color)),
    );
  }
}

class MemberAvatarStack extends StatelessWidget {
  const MemberAvatarStack({super.key, required this.members, this.maxVisible = 3});

  final List<AssignedMemberInfo> members;
  final int maxVisible;

  static const _colors = [
    AdminTheme.accentBlue,
    AdminTheme.success,
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    AdminTheme.warning,
  ];

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'Unassigned',
        style: TextStyle(fontSize: 11, color: AdminTheme.textSecondary.withValues(alpha: 0.9)),
      );
    }

    final visible = members.take(maxVisible).toList();
    final extra = members.length - visible.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: visible.length * 22.0 + (extra > 0 ? 28 : 6),
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * 20.0,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: _colors[i % _colors.length].withValues(alpha: 0.15),
                    child: Text(
                      visible[i].avatarLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _colors[i % _colors.length],
                      ),
                    ),
                  ),
                ),
              if (extra > 0)
                Positioned(
                  left: visible.length * 20.0,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AdminTheme.border,
                    child: Text('+$extra', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
