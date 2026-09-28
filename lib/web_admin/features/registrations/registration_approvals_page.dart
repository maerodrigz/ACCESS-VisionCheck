import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/registrations/registration_models.dart';
import 'package:access_mobile/web_admin/layout/admin_feature_page.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/layout/status_badge.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class RegistrationApprovalsPage extends StatefulWidget {
  const RegistrationApprovalsPage({super.key});

  @override
  State<RegistrationApprovalsPage> createState() => _RegistrationApprovalsPageState();
}

class _RegistrationApprovalsPageState extends State<RegistrationApprovalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _statusFilter = 'pending';
  String _search = '';
  final _searchCtrl = TextEditingController();

  List<MemberRegistrationRow> _members = [];
  List<OrganizationRegistrationRow> _organizations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final memberData = await adminApi.memberRegistrations(status: _statusFilter);
      final orgData = await adminApi.organizationRegistrations(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _members = memberData.map(MemberRegistrationRow.fromMap).toList();
        _organizations = orgData.map(OrganizationRegistrationRow.fromMap).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AdminTheme.success : AdminTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<MemberRegistrationRow> get _filteredMembers {
    if (_search.isEmpty) return _members;
    final q = _search.toLowerCase();
    return _members.where((r) {
      return r.fullName.toLowerCase().contains(q) ||
          r.email.toLowerCase().contains(q) ||
          (r.studentId ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<OrganizationRegistrationRow> get _filteredOrgs {
    if (_search.isEmpty) return _organizations;
    final q = _search.toLowerCase();
    return _organizations.where((r) {
      return r.organizationName.toLowerCase().contains(q) ||
          r.organizationEmail.toLowerCase().contains(q) ||
          (r.adviserName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _approveMember(MemberRegistrationRow row) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Approve member?',
      message: 'Grant ${row.fullName} access to ACCESS Sync.',
      confirmLabel: 'Approve',
      icon: Icons.check_circle_outline,
    );
    if (ok != true) return;
    try {
      await adminApi.approveMemberRegistration(row.id);
      await _load();
      _toast('${row.fullName} approved');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _rejectMember(MemberRegistrationRow row) async {
    final reason = await _rejectionReasonDialog(
      title: 'Reject member registration',
      name: row.fullName,
    );
    if (reason == null) return;
    try {
      await adminApi.rejectMemberRegistration(row.id, reason);
      await _load();
      _toast('${row.fullName} rejected');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _approveOrg(OrganizationRegistrationRow row) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Approve organization?',
      message: 'Grant ${row.organizationName} access to ACCESS Sync.',
      confirmLabel: 'Approve',
      icon: Icons.check_circle_outline,
    );
    if (ok != true) return;
    try {
      await adminApi.approveOrganizationRegistration(row.id);
      await _load();
      _toast('${row.organizationName} approved');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _rejectOrg(OrganizationRegistrationRow row) async {
    final reason = await _rejectionReasonDialog(
      title: 'Reject organization registration',
      name: row.organizationName,
    );
    if (reason == null) return;
    try {
      await adminApi.rejectOrganizationRegistration(row.id, reason);
      await _load();
      _toast('${row.organizationName} rejected');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<String?> _rejectionReasonDialog({required String title, required String name}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Provide a reason for rejecting $name. This is stored for audit purposes.',
              style: const TextStyle(color: AdminTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Rejection reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminTheme.danger),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.length < 3) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason (min 3 characters)')),
                );
                return;
              }
              Navigator.pop(ctx, text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showMemberDetails(MemberRegistrationRow row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(row.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: _detailGrid({
          'Student ID': row.studentId ?? '—',
          'Email': row.email,
          'Contact': row.contactNumber ?? '—',
          'Status': registrationStatusLabel(row.status),
          'Registered': _formatDate(row.dateRegistered),
          if (row.rejectionReason != null) 'Rejection reason': row.rejectionReason!,
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showOrgDetails(OrganizationRegistrationRow row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(row.organizationName, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: _detailGrid({
          'Email': row.organizationEmail,
          'Adviser / Representative': row.adviserName ?? '—',
          'Contact': row.contactNumber ?? '—',
          'Status': registrationStatusLabel(row.status),
          'Registered': _formatDate(row.dateRegistered),
          if (row.rejectionReason != null) 'Rejection reason': row.rejectionReason!,
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailGrid(Map<String, String> fields) {
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: fields.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _statusBadge(String status) {
    return switch (status.toLowerCase()) {
      'approved' => StatusBadge.approved(),
      'rejected' => StatusBadge.rejected(),
      _ => StatusBadge.pending(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AdminFeaturePage(
      title: 'Registration Approvals',
      subtitle:
          'Review and approve or reject newly registered members and organizations before they can sign in.',
      breadcrumbs: breadcrumbsForRoute(AdminRoute.registrationApprovals),
      loading: _loading,
      error: _error,
      onRetry: _load,
      actions: [
        PageHeaderButton(
          icon: Icons.group_outlined,
          label: 'Member Management',
          onPressed: () => AdminNavigationScope.go(context, AdminRoute.members),
        ),
        PageHeaderRefreshButton(onPressed: _load),
      ],
      filter: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AdminTheme.cardDecoration(),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name, email, or ID…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['pending', 'approved', 'rejected', 'all'].map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      s == 'all' ? 'All' : registrationStatusLabel(s),
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _statusFilter = s);
                      _load();
                    },
                    selectedColor: AdminTheme.accentCyan.withValues(alpha: 0.18),
                    checkmarkColor: AdminTheme.accentBlue,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            labelColor: AdminTheme.accentBlue,
            unselectedLabelColor: AdminTheme.textSecondary,
            indicatorColor: AdminTheme.accentBlue,
            tabs: [
              Tab(text: 'Member Approvals (${_filteredMembers.length})'),
              Tab(text: 'Organization Approvals (${_filteredOrgs.length})'),
            ],
          ),
        ],
      ),
      body: SizedBox(
        height: 560,
        child: TabBarView(
          controller: _tabs,
          children: [
            _membersTable(_filteredMembers),
            _organizationsTable(_filteredOrgs),
          ],
        ),
      ),
    );
  }

  Widget _membersTable(List<MemberRegistrationRow> rows) {
    return DataTableCard(
      title: 'Member registrations',
      shownCount: rows.length,
      totalCount: rows.length,
      emptyTitle: 'No member registrations',
      emptyMessage: _statusFilter == 'pending'
          ? 'No pending member registrations.'
          : 'No records match this filter.',
      emptyIcon: Icons.person_outline,
      child: AdminDataTableTheme(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Full Name')),
            DataColumn(label: Text('Student ID')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Date Registered')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(r.studentId ?? '—')),
                DataCell(Text(r.email)),
                DataCell(Text(r.contactNumber ?? '—')),
                DataCell(Text(_formatDate(r.dateRegistered))),
                DataCell(_statusBadge(r.status)),
                DataCell(_memberActions(r)),
              ],
            );
          }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _memberActions(MemberRegistrationRow r) {
    return Wrap(
      spacing: 4,
      children: [
        if (r.status == 'pending') ...[
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle_outline, color: AdminTheme.success, size: 20),
            onPressed: () => _approveMember(r),
          ),
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel_outlined, color: AdminTheme.danger, size: 20),
            onPressed: () => _rejectMember(r),
          ),
        ],
        IconButton(
          tooltip: 'View details',
          icon: const Icon(Icons.visibility_outlined, size: 20),
          onPressed: () => _showMemberDetails(r),
        ),
      ],
    );
  }

  Widget _organizationsTable(List<OrganizationRegistrationRow> rows) {
    return DataTableCard(
      title: 'Organization registrations',
      shownCount: rows.length,
      totalCount: rows.length,
      emptyTitle: 'No organization registrations',
      emptyMessage: _statusFilter == 'pending'
          ? 'No pending organization registrations.'
          : 'No records match this filter.',
      emptyIcon: Icons.business_outlined,
      child: AdminDataTableTheme(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Organization')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Adviser / Rep.')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Date Registered')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r.organizationName, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(r.organizationEmail)),
                DataCell(Text(r.adviserName ?? '—')),
                DataCell(Text(r.contactNumber ?? '—')),
                DataCell(Text(_formatDate(r.dateRegistered))),
                DataCell(_statusBadge(r.status)),
                DataCell(_orgActions(r)),
              ],
            );
          }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _orgActions(OrganizationRegistrationRow r) {
    return Wrap(
      spacing: 4,
      children: [
        if (r.status == 'pending') ...[
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle_outline, color: AdminTheme.success, size: 20),
            onPressed: () => _approveOrg(r),
          ),
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel_outlined, color: AdminTheme.danger, size: 20),
            onPressed: () => _rejectOrg(r),
          ),
        ],
        IconButton(
          tooltip: 'View details',
          icon: const Icon(Icons.visibility_outlined, size: 20),
          onPressed: () => _showOrgDetails(r),
        ),
      ],
    );
  }
}
