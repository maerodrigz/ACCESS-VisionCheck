import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/assign_member_dialog.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/layout/pagination_state.dart';
import 'package:access_mobile/web_admin/layout/search_filter_card.dart';
import 'package:access_mobile/web_admin/layout/status_badge.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Approved / rejected documentation requests (embedded in [TaskStatusPage]).
class RequestStatusPanel extends StatefulWidget {
  const RequestStatusPanel({
    super.key,
    this.initialStatusFilter,
    this.onRegisterRefresh,
  });

  final String? initialStatusFilter;
  final void Function(Future<void> Function() refresh)? onRegisterRefresh;

  @override
  State<RequestStatusPanel> createState() => _RequestStatusPanelState();
}

class _RequestStatusPanelState extends State<RequestStatusPanel> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  final _pagination = PaginationState();
  String _search = '';
  String? _statusFilter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
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
      final status = r['status'] as String? ?? 'Pending';
      if (status == 'Pending') return false;
      if (_statusFilter != null && status != _statusFilter) return false;
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

  @override
  Widget build(BuildContext context) {
    final canApprove = AdminSessionScope.of(context).role.can(AdminCapability.approveMembers);
    final filtered = _filtered;
    final pageRows = _pagination.slice(filtered);

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
        SearchFilterCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search event or requester…',
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
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Status', isDense: true),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _statusFilter,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All processed')),
                        DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                      ],
                      onChanged: (v) {
                        _statusFilter = v;
                        _pagination.reset();
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableCard(
            title: 'Processed requests',
            shownCount: pageRows.length,
            totalCount: filtered.length,
            pagination: _pagination,
            rangeLabel: _pagination.rangeLabel(filtered.length),
            onPageChanged: (p) => setState(() => _pagination.page = p),
            onPageSizeChanged: (size) => setState(() {
              _pagination.pageSize = size;
              _pagination.reset();
            }),
            emptyTitle: 'No processed requests',
            emptyMessage: 'Approved and rejected requests will appear here.',
            emptyIcon: Icons.pending_actions_outlined,
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
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Rejection reason')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: pageRows.map((r) {
                    final id = r['request_id'] as int;
                    final status = r['status'] as String? ?? 'Pending';
                    final reason = r['rejection_reason'] as String?;
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          r['event_name'] as String? ?? r['title'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text(r['requester_name'] as String? ?? '—')),
                        DataCell(Text(r['event_date'] as String? ?? '—')),
                        DataCell(Text(r['venue'] as String? ?? '—')),
                        DataCell(switch (status) {
                          'Approved' => StatusBadge.approved(),
                          'Rejected' => StatusBadge.rejected(),
                          _ => StatusBadge.pending(),
                        }),
                        DataCell(
                          status == 'Rejected' && reason != null && reason.isNotEmpty
                              ? Text(reason,
                                  style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))
                              : const Text('—'),
                        ),
                        DataCell(
                          status == 'Approved' && canApprove
                              ? OutlinedButton.icon(
                                  onPressed: () => _assignMember(id),
                                  icon: const Icon(Icons.person_add_outlined, size: 16),
                                  label: const Text('Assign'),
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
