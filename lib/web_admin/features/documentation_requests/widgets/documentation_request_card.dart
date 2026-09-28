import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/request_badges.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef RequestNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});
typedef RequestAction = void Function(DocumentationRequestItem item, String action);

class DocumentationRequestCard extends StatefulWidget {
  const DocumentationRequestCard({
    super.key,
    required this.item,
    required this.onAction,
    required this.onNavigate,
  });

  final DocumentationRequestItem item;
  final RequestAction onAction;
  final RequestNavigate onNavigate;

  @override
  State<DocumentationRequestCard> createState() => _DocumentationRequestCardState();
}

class _DocumentationRequestCardState extends State<DocumentationRequestCard> {
  bool _hovered = false;

  DocumentationRequestItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AdminTheme.surface,
          borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
          border: Border.all(
            color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.35) : AdminTheme.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AdminTheme.accentBlue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AdminTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.eventTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RequestPriorityBadge(priority: item.priority),
                ],
              ),
              const SizedBox(height: 10),
              _meta(Icons.person_outline, item.requestor),
              const SizedBox(height: 6),
              _meta(Icons.event_outlined, item.eventDateLabel),
              if (item.venue != null && item.venue!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _meta(Icons.location_on_outlined, item.venue!),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  RequestStatusBadge(status: item.displayStatus),
                  const Spacer(),
                  MemberAvatarStack(members: item.assignedMembers),
                ],
              ),
              if (item.details != null && item.details!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.details!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, height: 1.45),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _actionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AdminTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Widget> _actionButtons() {
    return switch (item.displayStatus) {
      RequestDisplayStatus.pending => [
          _ActionChip(label: 'Review', icon: Icons.rate_review_outlined, primary: true, onTap: () => widget.onAction(item, 'review')),
          _ActionChip(label: 'Assign Members', icon: Icons.person_add_outlined, onTap: () => widget.onAction(item, 'assign')),
          _ActionChip(label: 'View Details', icon: Icons.visibility_outlined, onTap: () => widget.onAction(item, 'details')),
        ],
      RequestDisplayStatus.approved => [
          _ActionChip(label: 'View Progress', icon: Icons.timeline_outlined, primary: true, onTap: () => widget.onAction(item, 'progress')),
          _ActionChip(label: 'Open Event', icon: Icons.calendar_month_outlined, onTap: () => widget.onNavigate(AdminRoute.eventCalendar)),
        ],
      RequestDisplayStatus.rejected => [
          _ActionChip(label: 'View Reason', icon: Icons.info_outline, primary: true, onTap: () => widget.onAction(item, 'reason')),
          _ActionChip(label: 'Resubmit', icon: Icons.replay_outlined, onTap: () => widget.onAction(item, 'resubmit')),
        ],
      RequestDisplayStatus.completed => [
          _ActionChip(label: 'View Documentation', icon: Icons.folder_open_outlined, primary: true, onTap: () => widget.onNavigate(AdminRoute.mediaRepository)),
          _ActionChip(label: 'Archive', icon: Icons.archive_outlined, onTap: () => widget.onAction(item, 'archive')),
        ],
    };
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AdminTheme.accentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AdminTheme.textSecondary),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminTheme.textPrimary,
        side: const BorderSide(color: AdminTheme.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
