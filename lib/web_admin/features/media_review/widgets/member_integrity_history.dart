import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class MemberIntegrityHistoryPanel extends StatelessWidget {
  const MemberIntegrityHistoryPanel({super.key, required this.record});

  final MemberIntegrityRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                child: Text(record.initials, style: const TextStyle(fontWeight: FontWeight.w800, color: AdminTheme.accentBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Integrity Record', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(record.memberName, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                  ],
                ),
              ),
              _ScoreRing(score: record.integrityScore),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _StatChip(label: 'Warnings', value: '${record.warningsIssued}'),
              _StatChip(label: 'Resolved', value: '${record.resolvedAlerts}'),
              _StatChip(label: 'Violations', value: '${record.confirmedViolations}'),
            ],
          ),
          if (record.lastWarningDate != null) ...[
            const SizedBox(height: 10),
            Text('Last warning: ${formatIntegrityDate(record.lastWarningDate!)}', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
          ],
          const SizedBox(height: 16),
          const Text('Recent Integrity Timeline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (record.timeline.isEmpty)
            const Text('No integrity events recorded yet.', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary))
          else
            ...record.timeline.take(6).map((e) => _TimelineItem(event: e)),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? AdminTheme.success : score >= 50 ? AdminTheme.warning : AdminTheme.danger;
    return Column(
      children: [
        Text('$score', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text('Integrity', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event});

  final IntegrityTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(event.icon, size: 16, color: event.color ?? AdminTheme.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatTimelineMonthDay(event.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
                Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (event.subtitle.isNotEmpty) Text(event.subtitle, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
