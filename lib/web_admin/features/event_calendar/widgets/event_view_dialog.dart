import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/event_calendar/event_calendar_models.dart';
import 'package:access_mobile/web_admin/features/event_calendar/widgets/event_status_badge.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Read-only event details — view on tap, no editing.
class EventViewDialog extends StatelessWidget {
  const EventViewDialog({super.key, required this.event});

  final CalendarEventItem event;

  static Future<void> show(BuildContext context, {required CalendarEventItem event}) {
    return showDialog(
      context: context,
      builder: (_) => EventViewDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    final accent = eventStatusColor(e.status);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.2))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AdminTheme.surface,
                      border: Border.all(color: accent, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${e.eventDate.day}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AdminTheme.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.displayDateTimeLabel,
                          style: const TextStyle(fontSize: 13, color: AdminTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: EventStatusBadge(status: e.status)),
                    const SizedBox(height: 18),
                    _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: e.displayDateLabel),
                    _DetailRow(icon: Icons.schedule_outlined, label: 'Time', value: e.timeLabel),
                    _DetailRow(icon: Icons.place_outlined, label: 'Location', value: e.location ?? 'TBA'),
                    if (e.description != null && e.description!.isNotEmpty)
                      _DetailRow(icon: Icons.notes_outlined, label: 'Description', value: e.description!),
                    if (e.assignedMemberName != null)
                      _DetailRow(icon: Icons.person_outline, label: 'Assigned team', value: e.assignedMemberName!),
                    if (e.documentationRequestId != null)
                      _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Documentation request',
                        value: '#${e.documentationRequestId}',
                      ),
                    if (e.requestStatus != null)
                      _DetailRow(icon: Icons.fact_check_outlined, label: 'Request status', value: e.requestStatus!),
                    if (e.adminRemarks != null && e.adminRemarks!.isNotEmpty)
                      _DetailRow(icon: Icons.comment_outlined, label: 'Admin remarks', value: e.adminRemarks!),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AdminTheme.contentBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Icon(icon, size: 17, color: AdminTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
