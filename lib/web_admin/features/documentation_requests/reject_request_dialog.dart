import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Required rejection reason before a documentation request is declined.
class RejectRequestDialog extends StatefulWidget {
  const RejectRequestDialog({
    super.key,
    required this.eventName,
  });

  final String eventName;

  static Future<String?> show(BuildContext context, {required String eventName}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RejectRequestDialog(eventName: eventName),
    );
  }

  @override
  State<RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<RejectRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: const Icon(Icons.cancel_outlined, size: 32, color: AdminTheme.danger),
      title: const Text('Reject request', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.eventName,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Provide a reason for rejection. The requestor will be notified with this message.',
              style: TextStyle(color: AdminTheme.textSecondary, height: 1.45, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                hintText: 'e.g. Event date unavailable, incomplete details…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Please enter at least 8 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AdminTheme.danger),
          onPressed: _submit,
          child: const Text('Reject & notify'),
        ),
      ],
    );
  }
}
