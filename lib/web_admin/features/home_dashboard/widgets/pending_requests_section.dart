import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

class PendingRequestsSection extends StatelessWidget {
  const PendingRequestsSection({
    super.key,
    required this.requests,
    required this.onNavigate,
  });

  final List<PendingRequestItem> requests;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Pending Documentation Requests',
            subtitle: 'Review and approve incoming documentation requests',
            trailing: HomeTextButton(
              label: 'View all',
              onPressed: () => onNavigate(AdminRoute.docRequests),
            ),
          ),
          const SizedBox(height: 16),
          if (requests.isEmpty)
            const AdminEmptyState(
              title: 'No pending requests',
              message: 'All documentation requests have been reviewed.',
              icon: Icons.check_circle_outline,
            )
          else
            Column(
              children: [
                for (var i = 0; i < requests.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AdminTheme.border),
                  _PendingRequestRow(
                    item: requests[i],
                    onReview: () => onNavigate(AdminRoute.docRequests, params: {'docMgmtTab': 'pendingRequests'}),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PendingRequestRow extends StatefulWidget {
  const _PendingRequestRow({required this.item, required this.onReview});

  final PendingRequestItem item;
  final VoidCallback onReview;

  @override
  State<_PendingRequestRow> createState() => _PendingRequestRowState();
}

class _PendingRequestRowState extends State<_PendingRequestRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? AdminTheme.contentBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.eventTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.requestor,
                    style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.item.requestedDate,
                style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
              ),
            ),
            HomeStatusBadge(label: widget.item.status),
            const SizedBox(width: 12),
            HomePrimaryButton(label: 'Review', compact: true, onPressed: widget.onReview),
          ],
        ),
      ),
    );
  }
}
