import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Post-approval dialog: pick a member and coverage role for the event.
class AssignMemberDialog extends StatefulWidget {
  const AssignMemberDialog({
    super.key,
    required this.eventName,
    required this.eventDate,
    required this.venue,
    required this.onAssign,
  });

  final String eventName;
  final String? eventDate;
  final String? venue;
  final Future<void> Function(int memberId, String taskRole, String? adminNotes) onAssign;

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> request,
    required Future<void> Function(int memberId, String taskRole, String? adminNotes) onAssign,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignMemberDialog(
        eventName: (request['event_name'] ?? request['title'] ?? 'Event').toString(),
        eventDate: request['event_date'] as String?,
        venue: request['venue'] as String?,
        onAssign: onAssign,
      ),
    );
  }

  @override
  State<AssignMemberDialog> createState() => _AssignMemberDialogState();
}

class _AssignMemberDialogState extends State<AssignMemberDialog> {
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
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
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
          if (members.length == 1) {
            _selectedMemberId = members.first['id'] as int?;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final notes = _notesController.text.trim();
      await widget.onAssign(
        _selectedMemberId!,
        _taskRole,
        notes.isEmpty ? null : notes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign member: $e')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminTheme.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_outlined, color: AdminTheme.accentBlue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Assign Member',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.eventName,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
              ),
              if (widget.eventDate != null || widget.venue != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (widget.eventDate != null) widget.eventDate,
                    if (widget.venue != null) widget.venue,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'Choose a member to cover this event. They will receive a notification.',
                style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (_loadingMembers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No approved members found. Approve member registrations first.',
                    style: TextStyle(color: AdminTheme.textSecondary),
                  ),
                )
              else ...[
                DropdownButtonFormField<int>(
                  value: _selectedMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Member',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final m in _members)
                      DropdownMenuItem(
                        value: m['id'] as int,
                        child: Text(m['name'] as String? ?? 'Member'),
                      ),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _selectedMemberId = v),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _taskRole,
                  decoration: const InputDecoration(
                    labelText: 'Coverage role',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final r in _roles)
                      DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _taskRole = v ?? 'photographer'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes for member (optional)',
                    hintText: 'Arrive 30 minutes early, bring telephoto lens…',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  enabled: !_submitting,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context, false),
                    child: const Text('Skip for now'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submitting || _members.isEmpty ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(_submitting ? 'Assigning…' : 'Assign & notify'),
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
