import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/reject_request_dialog.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/request_badges.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class RequestReviewDrawer extends StatefulWidget {
  const RequestReviewDrawer({
    super.key,
    required this.item,
    required this.open,
    required this.onClose,
    required this.onApproved,
    required this.onRejected,
    required this.onAssigned,
  });

  final DocumentationRequestItem? item;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onApproved;
  final VoidCallback onRejected;
  final VoidCallback onAssigned;

  @override
  State<RequestReviewDrawer> createState() => _RequestReviewDrawerState();
}

class _RequestReviewDrawerState extends State<RequestReviewDrawer> {
  static const _roles = [
    ('photographer', 'Photographer'),
    ('videographer', 'Videographer'),
    ('editor', 'Editor'),
  ];

  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = true;
  bool _submitting = false;
  int? _selectedMemberId;
  String _taskRole = 'photographer';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant RequestReviewDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.id != widget.item?.id) {
      _notesController.clear();
      _selectedMemberId = null;
      _taskRole = 'photographer';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final users = await adminApi.allUsers();
      final members = users.where((u) {
        final role = (u['role'] as String? ?? '').toLowerCase();
        final status = (u['status'] as String? ?? '').toLowerCase();
        return role == 'member' && status == 'approved';
      }).toList()
        ..sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      if (mounted) {
        setState(() {
          _members = members;
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _approve() async {
    final item = widget.item;
    if (item == null) return;
    final ok = await ConfirmDialog.show(
      context,
      title: 'Approve this request?',
      message: 'The requestor will be notified. You can assign members before or after approval.',
      confirmLabel: 'Approve',
      icon: Icons.check_circle_outline,
    );
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      await adminApi.setRequestStatus(item.id, 'Approved');
      if (_selectedMemberId != null) {
        await adminApi.assignMemberToRequest(
          item.id,
          memberId: _selectedMemberId!,
          taskRole: _taskRole,
          adminNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        widget.onAssigned();
      }
      if (mounted) {
        widget.onApproved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not approve: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reject() async {
    final item = widget.item;
    if (item == null) return;
    final reason = await RejectRequestDialog.show(context, eventName: item.eventTitle);
    if (reason == null || reason.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await adminApi.setRequestStatus(item.id, 'Rejected', rejectionReason: reason);
      if (mounted) {
        widget.onRejected();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected — requestor notified')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reject: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _assignOnly() async {
    final item = widget.item;
    if (item == null || _selectedMemberId == null) return;
    setState(() => _submitting = true);
    try {
      await adminApi.assignMemberToRequest(
        item.id,
        memberId: _selectedMemberId!,
        taskRole: _taskRole,
        adminNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) {
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member assigned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canApprove = AdminSessionScope.of(context).role.can(AdminCapability.approveMembers);
    final isPending = item?.displayStatus == RequestDisplayStatus.pending;
    final isApproved = item?.displayStatus == RequestDisplayStatus.approved;
    final showWorkflow = isPending || isApproved;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: widget.open ? 0 : -520,
      width: 500,
      child: Material(
        elevation: 16,
        shadowColor: Colors.black26,
        child: Container(
          decoration: const BoxDecoration(
            color: AdminTheme.surface,
            border: Border(left: BorderSide(color: AdminTheme.border)),
          ),
          child: item == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DrawerHeader(title: item.eventTitle, onClose: widget.onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                RequestStatusBadge(status: item.displayStatus),
                                const SizedBox(width: 8),
                                RequestPriorityBadge(priority: item.priority),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _Section(
                              title: 'Event information',
                              child: Column(
                                children: [
                                  _InfoRow(label: 'Event', value: item.eventTitle),
                                  _InfoRow(label: 'Date', value: item.eventDateLabel),
                                  _InfoRow(label: 'Venue', value: item.venue ?? '—'),
                                  _InfoRow(label: 'Requested', value: item.createdAtLabel),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Section(
                              title: 'Requestor',
                              child: _InfoRow(label: 'Name', value: item.requestor),
                            ),
                            const SizedBox(height: 16),
                            _Section(
                              title: 'Documentation requirements',
                              child: Text(
                                item.details?.trim().isNotEmpty == true
                                    ? item.details!.trim()
                                    : 'Standard photo and video coverage for the event.',
                                style: const TextStyle(fontSize: 13, color: AdminTheme.textSecondary, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Section(
                              title: 'Assigned members',
                              child: MemberAvatarStack(members: item.assignedMembers),
                            ),
                            if (showWorkflow && canApprove) ...[
                              const SizedBox(height: 20),
                              _Section(
                                title: 'Assign member',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_loadingMembers)
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    else if (_members.isEmpty)
                                      const Text(
                                        'No approved members available.',
                                        style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                      )
                                    else ...[
                                      DropdownButtonFormField<int>(
                                        value: _selectedMemberId,
                                        decoration: const InputDecoration(labelText: 'Member', isDense: true),
                                        items: [
                                          for (final m in _members)
                                            DropdownMenuItem(
                                              value: m['id'] as int,
                                              child: Text(m['name'] as String? ?? 'Member'),
                                            ),
                                        ],
                                        onChanged: _submitting ? null : (v) => setState(() => _selectedMemberId = v),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        value: _taskRole,
                                        decoration: const InputDecoration(labelText: 'Coverage role', isDense: true),
                                        items: [
                                          for (final r in _roles)
                                            DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                                        ],
                                        onChanged: _submitting ? null : (v) => setState(() => _taskRole = v ?? 'photographer'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Admin notes',
                                  hintText: 'Internal notes for the assigned member…',
                                  alignLabelWithHint: true,
                                ),
                                enabled: !_submitting,
                              ),
                            ],
                            if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _Section(
                                title: 'Rejection reason',
                                child: Text(
                                  item.rejectionReason!,
                                  style: const TextStyle(fontSize: 13, color: AdminTheme.danger, height: 1.45),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (showWorkflow && canApprove)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AdminTheme.border)),
                          color: Color(0xFFFAFBFC),
                        ),
                        child: Row(
                          children: [
                            if (isPending) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _submitting ? null : _reject,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AdminTheme.danger,
                                    side: const BorderSide(color: AdminTheme.danger),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              flex: isPending ? 2 : 1,
                              child: FilledButton(
                                onPressed: _submitting
                                    ? null
                                    : isPending
                                        ? _approve
                                        : (_selectedMemberId == null ? null : _assignOnly),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isPending ? AdminTheme.success : AdminTheme.accentBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(isPending ? 'Approve' : 'Assign member'),
                              ),
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Review request',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
