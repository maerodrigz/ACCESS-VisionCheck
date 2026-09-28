import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class SendWarningModal {
  static Future<SendWarningResult?> show(
    BuildContext context, {
    required IntegrityWarningLevel suggestedLevel,
  }) {
    return showDialog<SendWarningResult>(
      context: context,
      builder: (ctx) => _SendWarningDialog(suggestedLevel: suggestedLevel),
    );
  }
}

class SendWarningResult {
  const SendWarningResult({
    required this.level,
    required this.reason,
    required this.message,
  });

  final IntegrityWarningLevel level;
  final String reason;
  final String message;
}

class _SendWarningDialog extends StatefulWidget {
  const _SendWarningDialog({required this.suggestedLevel});

  final IntegrityWarningLevel suggestedLevel;

  @override
  State<_SendWarningDialog> createState() => _SendWarningDialogState();
}

class _SendWarningDialogState extends State<_SendWarningDialog> {
  late IntegrityWarningLevel _level;
  late final TextEditingController _reasonController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _level = widget.suggestedLevel;
    _reasonController = TextEditingController(text: kDefaultWarningReason);
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Send Warning', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Warning Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<IntegrityWarningLevel>(
              segments: const [
                ButtonSegment(value: IntegrityWarningLevel.first, label: Text('First')),
                ButtonSegment(value: IntegrityWarningLevel.second, label: Text('Second')),
                ButtonSegment(value: IntegrityWarningLevel.finalWarning, label: Text('Final')),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(controller: _reasonController, maxLines: 3),
            const SizedBox(height: 16),
            const Text('Administrator Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Optional personal message to the member…'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            SendWarningResult(
              level: _level,
              reason: _reasonController.text.trim(),
              message: _messageController.text.trim(),
            ),
          ),
          style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
          child: const Text('Send Warning'),
        ),
      ],
    );
  }
}
