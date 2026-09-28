import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/integrity_overview_cards.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/member_integrity_history.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class IntegrityReviewDrawer extends StatefulWidget {
  const IntegrityReviewDrawer({
    super.key,
    required this.alert,
    required this.memberRecord,
    required this.open,
    required this.onClose,
    required this.onDismiss,
    required this.onSendWarning,
    required this.onReject,
    required this.onKeepMonitoring,
    required this.onNotesChanged,
  });

  final IntegrityAlert? alert;
  final MemberIntegrityRecord? memberRecord;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onDismiss;
  final VoidCallback onSendWarning;
  final VoidCallback onReject;
  final VoidCallback onKeepMonitoring;
  final ValueChanged<String> onNotesChanged;

  @override
  State<IntegrityReviewDrawer> createState() => _IntegrityReviewDrawerState();
}

class _IntegrityReviewDrawerState extends State<IntegrityReviewDrawer> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.alert?.adminNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant IntegrityReviewDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert?.id != widget.alert?.id) {
      _notesController.text = widget.alert?.adminNotes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: widget.open ? 0 : -580,
      width: 560,
      child: Material(
        elevation: 16,
        child: Container(
          decoration: const BoxDecoration(color: AdminTheme.surface, border: Border(left: BorderSide(color: AdminTheme.border))),
          child: a == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onClose: widget.onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: !a.isVideo && a.thumbnailUrl.isNotEmpty
                                    ? Image.network(a.thumbnailUrl, fit: BoxFit.cover)
                                    : Container(
                                        color: AdminTheme.border,
                                        child: a.isVideo ? const Center(child: Icon(Icons.play_circle_fill, size: 56)) : null,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Member information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _Row(label: 'Name', value: a.memberName),
                            _Row(label: 'Role', value: a.memberRole),
                            _Row(label: 'Skill level', value: a.skillLevel ?? 'Not classified'),
                            const SizedBox(height: 16),
                            const Text('Submission information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _Row(label: 'Event', value: a.eventName),
                            _Row(label: 'Upload date', value: a.uploadDate != null ? formatIntegrityDate(a.uploadDate!) : '—'),
                            _Row(label: 'File name', value: a.fileName),
                            const SizedBox(height: 16),
                            const Text('AI detection result', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _Row(label: 'Confidence', value: '${a.confidencePercent}%'),
                            _Row(label: 'Summary', value: a.detectionSummary),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                IntegrityLevelBadge(level: a.alertLevel),
                                IntegrityStatusBadge(status: a.status),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AdminTheme.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminTheme.warning.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'This submission has been identified as potentially AI-generated and requires administrator verification before any action is taken.',
                                style: TextStyle(fontSize: 12, height: 1.45, color: AdminTheme.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Administrator notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesController,
                              maxLines: 4,
                              onChanged: widget.onNotesChanged,
                              decoration: const InputDecoration(hintText: 'Document verification observations…'),
                            ),
                            if (widget.memberRecord != null) ...[
                              const SizedBox(height: 20),
                              MemberIntegrityHistoryPanel(record: widget.memberRecord!),
                            ],
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(onPressed: widget.onDismiss, child: const Text('Dismiss Alert')),
                                FilledButton(onPressed: widget.onSendWarning, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)), child: const Text('Send Warning')),
                                OutlinedButton(onPressed: widget.onReject, style: OutlinedButton.styleFrom(foregroundColor: AdminTheme.danger), child: const Text('Reject Submission')),
                                FilledButton(onPressed: widget.onKeepMonitoring, style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue), child: const Text('Keep Under Monitoring')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AdminTheme.border))),
      child: Row(
        children: [
          const Expanded(child: Text('Review Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
