import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/integrity_overview_cards.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class IntegrityAlertCard extends StatefulWidget {
  const IntegrityAlertCard({
    super.key,
    required this.alert,
    required this.onReview,
  });

  final IntegrityAlert alert;
  final VoidCallback onReview;

  @override
  State<IntegrityAlertCard> createState() => _IntegrityAlertCardState();
}

class _IntegrityAlertCardState extends State<IntegrityAlertCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: AdminTheme.cardDecoration(radius: 18).copyWith(
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
          border: Border.all(
            color: a.alertLevel == IntegrityAlertLevel.high
                ? AdminTheme.danger.withValues(alpha: _hovered ? 0.5 : 0.25)
                : _hovered
                    ? AdminTheme.accentBlue.withValues(alpha: 0.35)
                    : AdminTheme.border,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                  child: Text(a.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminTheme.accentBlue)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.memberName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(a.memberRole, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Text(a.eventName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                      if (a.uploadDate != null)
                        Text('Uploaded ${formatIntegrityDate(a.uploadDate!)}', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: !a.isVideo && a.thumbnailUrl.isNotEmpty
                        ? Image.network(a.thumbnailUrl, fit: BoxFit.cover)
                        : Container(color: AdminTheme.border, child: const Icon(Icons.videocam_outlined)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Metric(label: 'AI Confidence', value: '${a.confidencePercent}%'),
                const SizedBox(width: 12),
                Expanded(child: IntegrityLevelBadge(level: a.alertLevel)),
              ],
            ),
            const SizedBox(height: 10),
            IntegrityStatusBadge(status: a.status),
            if (a.underMonitoring) ...[
              const SizedBox(height: 8),
              Text('Under monitoring', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminTheme.accentBlue.withValues(alpha: 0.9))),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: widget.onReview,
              style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue, padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Review Alert', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
        ],
      ),
    );
  }
}
