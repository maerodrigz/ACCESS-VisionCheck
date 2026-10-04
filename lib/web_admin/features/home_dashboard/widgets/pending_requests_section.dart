import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

/// Action Center — priority items that need admin attention.
class ActionCenterSection extends StatelessWidget {
  const ActionCenterSection({
    super.key,
    required this.items,
    required this.pendingCount,
    required this.mediaPendingCount,
    required this.onNavigate,
  });

  final List<ActionCenterItem> items;
  final int pendingCount;
  final int mediaPendingCount;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          HomeSectionHeader(
            title: 'Action Center',
            subtitle: 'Priority items that need your attention.',
            icon: Icons.bolt_rounded,
            iconColor: AdminTheme.warning,
            trailing: HomeTextButton(
              label: 'View all',
              icon: Icons.chevron_right_rounded,
              onPressed: () => onNavigate(AdminRoute.docRequests),
            ),
          ),
          const SizedBox(height: 16),
          // Items
          if (items.isEmpty)
            const AdminEmptyState(
              title: 'All clear',
              message: 'No priority items right now. Check back later.',
              icon: Icons.check_circle_outline_rounded,
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ActionCenterRow(
                    item: items[i],
                    onTap: () => _handleTap(items[i]),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 16),
          // Bottom action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.fact_check_outlined,
                  label: pendingCount > 0
                      ? 'Review Requests ($pendingCount)'
                      : 'Review Requests',
                  onPressed: () => onNavigate(AdminRoute.docRequests),
                  primary: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.verified_user_outlined,
                  label: mediaPendingCount > 0
                      ? 'Review Media ($mediaPendingCount)'
                      : 'Review Media',
                  onPressed: () => onNavigate(AdminRoute.mediaEvaluation),
                  primary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTap(ActionCenterItem item) {
    switch (item.kind) {
      case 'request':
        onNavigate(AdminRoute.docRequests);
      case 'integrity':
        onNavigate(AdminRoute.aiDetection);
      default:
        onNavigate(AdminRoute.mediaEvaluation);
    }
  }
}

class _ActionCenterRow extends StatefulWidget {
  const _ActionCenterRow({required this.item, required this.onTap});

  final ActionCenterItem item;
  final VoidCallback onTap;

  @override
  State<_ActionCenterRow> createState() => _ActionCenterRowState();
}

class _ActionCenterRowState extends State<_ActionCenterRow> {
  bool _hovered = false;

  IconData get _icon => switch (widget.item.kind) {
        'request' => Icons.description_outlined,
        'integrity' => Icons.shield_outlined,
        _ => Icons.photo_library_outlined,
      };

  Color get _color => switch (widget.item.kind) {
        'request' => AdminTheme.danger,
        'integrity' => AdminTheme.warning,
        _ => AdminTheme.accentCyan,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.04) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.25) : AdminTheme.border,
            ),
          ),
          child: Row(
            children: [
              // Icon tile
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminTheme.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Time + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.item.timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _hovered ? color : AdminTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.primary) {
      return FilledButton.icon(
        onPressed: widget.onPressed,
        icon: Icon(widget.icon, size: 16),
        label: Text(
          widget.label,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AdminTheme.accentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: OutlinedButton.icon(
        onPressed: widget.onPressed,
        icon: Icon(widget.icon, size: 16),
        label: Text(
          widget.label,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _hovered ? AdminTheme.accentBlue : AdminTheme.textPrimary,
          side: BorderSide(
            color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.5) : AdminTheme.border,
          ),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
