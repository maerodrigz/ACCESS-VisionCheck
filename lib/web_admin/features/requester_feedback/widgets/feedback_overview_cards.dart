import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class FeedbackOverviewCards extends StatelessWidget {
  const FeedbackOverviewCards({super.key, required this.stats});

  final FeedbackOverviewStats stats;

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
            _Card(
              icon: Icons.star_rate_rounded,
              label: 'Average Satisfaction Rating',
              value: stats.averageRating > 0 ? stats.averageRating.toStringAsFixed(1) : '—',
              color: const Color(0xFFF59E0B),
            ),
            _Card(icon: Icons.inbox_outlined, label: 'Total Feedback Received', value: '${stats.totalReceived}', color: AdminTheme.accentBlue),
            _Card(icon: Icons.thumb_up_outlined, label: 'Positive Reviews', value: '${stats.positiveReviews}', color: AdminTheme.success),
            _Card(icon: Icons.report_outlined, label: 'Needs Attention', value: '${stats.needsAttention}', color: AdminTheme.danger),
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
