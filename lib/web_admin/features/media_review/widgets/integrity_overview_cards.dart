import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class IntegrityOverviewCards extends StatelessWidget {
  const IntegrityOverviewCards({super.key, required this.stats});

  final IntegrityOverviewStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 560 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols >= 4 ? 2.3 : 2.0,
          children: [
            _Card(icon: Icons.pending_actions_outlined, label: 'Pending Review Alerts', value: '${stats.pendingReviewAlerts}', color: AdminTheme.warning),
            _Card(icon: Icons.gavel_outlined, label: 'Confirmed Violations', value: '${stats.confirmedViolations}', color: AdminTheme.danger),
            _Card(icon: Icons.warning_amber_rounded, label: 'Warnings Issued', value: '${stats.warningsIssued}', color: const Color(0xFFEA580C)),
            _Card(icon: Icons.task_alt_outlined, label: 'Resolved Alerts', value: '${stats.resolvedAlerts}', color: AdminTheme.success),
          ],
        );
      },
    );
  }
}

class _Card extends StatefulWidget {
  const _Card({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: AdminTheme.cardDecoration().copyWith(
          border: Border.all(color: _hovered ? widget.color.withValues(alpha: 0.35) : AdminTheme.border),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
                  Text(widget.label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntegrityStatusBadge extends StatelessWidget {
  const IntegrityStatusBadge({super.key, required this.status});

  final IntegrityAlertStatus status;

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class IntegrityLevelBadge extends StatelessWidget {
  const IntegrityLevelBadge({super.key, required this.level});

  final IntegrityAlertLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: level.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('${level.emoji} ${level.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: level.color)),
    );
  }
}
