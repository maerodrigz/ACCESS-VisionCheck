import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/layout/status_badge.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Member task assignments linked to documentation requests.
class MemberAssignmentsPanel extends StatefulWidget {
  const MemberAssignmentsPanel({super.key, this.onRegisterRefresh});

  final void Function(Future<void> Function() refresh)? onRegisterRefresh;

  @override
  State<MemberAssignmentsPanel> createState() => _MemberAssignmentsPanelState();
}

class _MemberAssignmentsPanelState extends State<MemberAssignmentsPanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.onRegisterRefresh?.call(_load);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await adminApi.allTasks();
      if (mounted) {
        setState(() {
          _rows = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _rows = [];
          _loading = false;
        });
      }
    }
  }

  Widget _statusChip(String? raw) {
    final status = (raw ?? 'assigned').toLowerCase();
    if (status == 'completed' || status == 'done') {
      return StatusBadge(label: 'Completed', color: AdminTheme.success);
    }
    if (status == 'assigned') {
      return StatusBadge(label: 'Assigned', color: AdminTheme.accentBlue);
    }
    return StatusBadge(label: raw ?? '—', color: AdminTheme.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
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
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: AdminTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('No member assignments yet',
                style: TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
            const SizedBox(height: 4),
            const Text('Assign members from approved requests.',
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = _rows[i];
        return Container(
          decoration: AdminTheme.cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['request_title'] as String? ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r['member_name']} · ${r['task_role']} · ${r['event_date'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusChip(r['status'] as String?),
            ],
          ),
        );
      },
    );
  }
}
