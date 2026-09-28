import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/documentation_management/widgets/pending_requests_panel.dart';
import 'package:access_mobile/web_admin/features/task_status/widgets/member_assignments_panel.dart';
import 'package:access_mobile/web_admin/features/task_status/widgets/request_status_panel.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum DocMgmtTab { request, requestStatus, taskStatus }

/// Unified Documentation Management hub: pending requests, processed status, and tasks.
class DocumentationManagementPage extends StatefulWidget {
  const DocumentationManagementPage({super.key});

  @override
  State<DocumentationManagementPage> createState() => _DocumentationManagementPageState();
}

class _DocumentationManagementPageState extends State<DocumentationManagementPage> {
  DocMgmtTab _tab = DocMgmtTab.request;
  String? _requestStatusFilter;
  Future<void> Function()? _refreshPending;
  Future<void> Function()? _refreshRequestStatus;
  Future<void> Function()? _refreshTasks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRouteIntent());
  }

  void _applyRouteIntent() {
    final params = AdminNavigationScope.consumeParams(context, AdminRoute.docRequests) ??
        AdminNavigationScope.consumeParams(context, AdminRoute.requestStatus) ??
        AdminNavigationScope.consumeParams(context, AdminRoute.taskAssignments);
    if (params == null) return;

    final tab = params['docMgmtTab'] as String? ??
        (params['taskStatusTab'] == 'assignments' ? 'taskStatus' : null) ??
        (params.containsKey('statusFilter') ? 'requestStatus' : null);

    setState(() {
      switch (tab) {
        case 'requestStatus':
          _tab = DocMgmtTab.requestStatus;
        case 'taskStatus':
          _tab = DocMgmtTab.taskStatus;
        default:
          _tab = DocMgmtTab.request;
      }
      final filter = params['statusFilter'] as String?;
      if (filter != null && filter != 'Pending') {
        _requestStatusFilter = filter;
      }
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      if (_refreshPending != null) _refreshPending!(),
      if (_refreshRequestStatus != null) _refreshRequestStatus!(),
      if (_refreshTasks != null) _refreshTasks!(),
    ]);
  }

  void _onRequestProcessed() {
    _refreshRequestStatus?.call();
  }

  @override
  Widget build(BuildContext context) {
    final compact = AdminBreakpoints.widthOf(context) < AdminBreakpoints.tablet;

    return Container(
      color: AdminTheme.contentBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AdminBreakpoints.pagePadding(context).copyWith(bottom: 0),
            child: PageHeader(
              title: 'Request',
              subtitle: 'Review pending requests, track approvals, and monitor member assignments.',
              breadcrumbs: breadcrumbsForRoute(AdminRoute.docRequests),
              actions: [PageHeaderRefreshButton(onPressed: _refreshAll)],
            ),
          ),
          Padding(
            padding: AdminBreakpoints.pagePadding(context).copyWith(top: 16, bottom: 12),
            child: _DocMgmtTabBar(
              selected: _tab,
              onSelected: (tab) => setState(() => _tab = tab),
              compact: compact,
            ),
          ),
          Expanded(
            child: Padding(
              padding: AdminBreakpoints.pagePadding(context).copyWith(top: 0),
              child: IndexedStack(
                index: _tab.index,
                children: [
                  PendingRequestsPanel(
                    key: const ValueKey('pending-requests-panel'),
                    onRegisterRefresh: (fn) => _refreshPending = fn,
                    onRequestProcessed: _onRequestProcessed,
                  ),
                  RequestStatusPanel(
                    key: const ValueKey('request-status-panel'),
                    initialStatusFilter: _requestStatusFilter,
                    onRegisterRefresh: (fn) => _refreshRequestStatus = fn,
                  ),
                  MemberAssignmentsPanel(
                    key: const ValueKey('member-assignments-panel'),
                    onRegisterRefresh: (fn) => _refreshTasks = fn,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocMgmtTabBar extends StatelessWidget {
  const _DocMgmtTabBar({
    required this.selected,
    required this.onSelected,
    required this.compact,
  });

  final DocMgmtTab selected;
  final ValueChanged<DocMgmtTab> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final segments = [
      ButtonSegment(
        value: DocMgmtTab.request,
        label: const Text('Request'),
        icon: const Icon(Icons.inbox_outlined, size: 18),
      ),
      ButtonSegment(
        value: DocMgmtTab.requestStatus,
        label: Text(compact ? 'Status' : 'Request status'),
        icon: const Icon(Icons.pending_actions_outlined, size: 18),
      ),
      ButtonSegment(
        value: DocMgmtTab.taskStatus,
        label: Text(compact ? 'Tasks' : 'Task status'),
        icon: const Icon(Icons.assignment_outlined, size: 18),
      ),
    ];

    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AdminTheme.accentBlue.withValues(alpha: 0.12);
        }
        return AdminTheme.surface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AdminTheme.accentBlue;
        }
        return AdminTheme.textSecondary;
      }),
      side: WidgetStateProperty.all(const BorderSide(color: AdminTheme.border)),
    );

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<DocMgmtTab>(
          segments: segments,
          selected: {selected},
          onSelectionChanged: (values) => onSelected(values.first),
          style: style,
          showSelectedIcon: false,
        ),
      );
    }

    return SegmentedButton<DocMgmtTab>(
      segments: segments,
      selected: {selected},
      onSelectionChanged: (values) => onSelected(values.first),
      style: style,
      showSelectedIcon: false,
    );
  }
}
