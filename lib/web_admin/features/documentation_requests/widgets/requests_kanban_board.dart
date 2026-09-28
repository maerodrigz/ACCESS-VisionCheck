import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/documentation_request_card.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/request_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class RequestsKanbanBoard extends StatelessWidget {
  const RequestsKanbanBoard({
    super.key,
    required this.items,
    required this.onAction,
    required this.onNavigate,
  });

  final List<DocumentationRequestItem> items;
  final RequestAction onAction;
  final RequestNavigate onNavigate;

  static const _columns = [
    RequestDisplayStatus.pending,
    RequestDisplayStatus.approved,
    RequestDisplayStatus.rejected,
    RequestDisplayStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final horizontal = c.maxWidth >= 900;
        if (horizontal) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _columns.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _KanbanColumn(
                    status: _columns[i],
                    items: items.where((e) => e.displayStatus == _columns[i]).toList(),
                    onAction: onAction,
                    onNavigate: onNavigate,
                  ),
                ),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final status in _columns) ...[
              _KanbanColumn(
                status: status,
                items: items.where((e) => e.displayStatus == status).toList(),
                onAction: onAction,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.items,
    required this.onAction,
    required this.onNavigate,
  });

  final RequestDisplayStatus status;
  final List<DocumentationRequestItem> items;
  final RequestAction onAction;
  final RequestNavigate onNavigate;

  String get _title => switch (status) {
        RequestDisplayStatus.pending => 'Pending',
        RequestDisplayStatus.approved => 'Approved',
        RequestDisplayStatus.rejected => 'Rejected',
        RequestDisplayStatus.completed => 'Completed',
      };

  Color get _accent => switch (status) {
        RequestDisplayStatus.pending => AdminTheme.warning,
        RequestDisplayStatus.approved => AdminTheme.accentBlue,
        RequestDisplayStatus.rejected => AdminTheme.danger,
        RequestDisplayStatus.completed => AdminTheme.success,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
        border: Border.all(color: AdminTheme.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(_title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Text('${items.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No items',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary.withValues(alpha: 0.8)),
              ),
            )
          else
            for (final item in items) ...[
              _KanbanCard(item: item, onAction: onAction, onNavigate: onNavigate),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _KanbanCard extends StatefulWidget {
  const _KanbanCard({required this.item, required this.onAction, required this.onNavigate});

  final DocumentationRequestItem item;
  final RequestAction onAction;
  final RequestNavigate onNavigate;

  @override
  State<_KanbanCard> createState() => _KanbanCardState();
}

class _KanbanCardState extends State<_KanbanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AdminTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.3) : AdminTheme.border),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        child: InkWell(
          onTap: () => widget.onAction(item, item.displayStatus == RequestDisplayStatus.pending ? 'review' : 'details'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.eventTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RequestPriorityBadge(priority: item.priority),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.requestor, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(item.eventDateLabel, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                const SizedBox(height: 10),
                MemberAvatarStack(members: item.assignedMembers, maxVisible: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
