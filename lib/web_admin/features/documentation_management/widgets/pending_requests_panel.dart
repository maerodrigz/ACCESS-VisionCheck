import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/assign_member_dialog.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/reject_request_dialog.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/alert_banner.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/layout/pagination_state.dart';
import 'package:access_mobile/web_admin/layout/search_filter_card.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Pending documentation requests awaiting admin review.
class PendingRequestsPanel extends StatefulWidget {
  const PendingRequestsPanel({
    super.key,
    this.onRegisterRefresh,
    this.onRequestProcessed,
  });

  final void Function(Future<void> Function() refresh)? onRegisterRefresh;
  final VoidCallback? onRequestProcessed;

  @override
  State<PendingRequestsPanel> createState() => _PendingRequestsPanelState();
}

class _PendingRequestsPanelState extends State<PendingRequestsPanel> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  final _pagination = PaginationState();
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onRegisterRefresh?.call(_load);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await adminApi.allServiceRequests();
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
          _pagination.reset();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _all = [];
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _all.where((r) {
      if ((r['status'] as String? ?? 'Pending') != 'Pending') return false;
      final name = (r['event_name'] ?? r['title'] ?? '').toString().toLowerCase();
      final requester = (r['requester_name'] ?? '').toString().toLowerCase();
      if (_search.isNotEmpty &&
          !name.contains(_search.toLowerCase()) &&
          !requester.contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, dynamic>? _requestById(int id) {
    for (final r in _all) {
      if (r['request_id'] == id) return r;
    }
    return null;
  }

  Future<void> _assignMember(int id) async {
    final row = _requestById(id);
    if (row == null) return;
    final assigned = await AssignMemberDialog.show(
      context,
      request: row,
      onAssign: (memberId, taskRole, notes) => adminApi.assignMemberToRequest(
        id,
        memberId: memberId,
        taskRole: taskRole,
        adminNotes: notes,
      ),
    );
    if (assigned == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member assigned and notified')),
      );
    }
    if (mounted) await _load();
  }

  Future<void> _approve(int id) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Approve this request?',
      message: 'The request will move to Request status. You can then assign a member to cover the event.',
      confirmLabel: 'Approve',
      icon: Icons.check_circle_outline,
    );
    if (ok != true) return;

    try {
      await adminApi.setRequestStatus(id, 'Approved');
      if (mounted) {
        await _assignMember(id);
        widget.onRequestProcessed?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request approved — see Request status tab')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve request')),
        );
      }
    }
  }

  Future<void> _reject(int id) async {
    final row = _requestById(id);
    if (row == null) return;
    final eventName = (row['event_name'] ?? row['title'] ?? 'Request').toString();
    final reason = await RejectRequestDialog.show(context, eventName: eventName);
    if (reason == null || reason.isEmpty) return;

    try {
      await adminApi.setRequestStatus(id, 'Rejected', rejectionReason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected — requestor has been notified')),
        );
        widget.onRequestProcessed?.call();
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reject request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApprove = AdminSessionScope.of(context).role.can(AdminCapability.approveMembers);
    final filtered = _filtered;
    final pageRows = _pagination.slice(filtered);
    final pending = filtered.length;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending > 0) ...[
          AlertBanner(
            message: '$pending request${pending == 1 ? '' : 's'} pending review.',
            type: AlertBannerType.warning,
          ),
          const SizedBox(height: 16),
        ],
        SearchFilterCard(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search pending requests…',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) {
              _search = v;
              _pagination.reset();
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableCard(
            title: 'Pending review queue',
            shownCount: pageRows.length,
            totalCount: filtered.length,
            pagination: _pagination,
            rangeLabel: _pagination.rangeLabel(filtered.length),
            onPageChanged: (p) => setState(() => _pagination.page = p),
            onPageSizeChanged: (size) => setState(() {
              _pagination.pageSize = size;
              _pagination.reset();
            }),
            emptyTitle: 'No pending requests',
            emptyMessage: 'New documentation requests from requestors will appear here.',
            emptyIcon: Icons.inbox_outlined,
            emptyActionLabel: 'Refresh',
            onEmptyAction: _load,
            minHeight: 240,
            child: AdminDataTableTheme(
              child: ResponsiveTableScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Event')),
                    DataColumn(label: Text('Requester')),
                    DataColumn(label: Text('Event date')),
                    DataColumn(label: Text('Venue')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: pageRows.map((r) {
                    final id = r['request_id'] as int;
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          r['event_name'] as String? ?? r['title'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text(r['requester_name'] as String? ?? '—')),
                        DataCell(Text(r['event_date'] as String? ?? '—')),
                        DataCell(Text(r['venue'] as String? ?? '—')),
                        DataCell(
                          canApprove
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FilledButton(
                                      onPressed: () => _approve(id),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AdminTheme.success,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      onPressed: () => _reject(id),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
