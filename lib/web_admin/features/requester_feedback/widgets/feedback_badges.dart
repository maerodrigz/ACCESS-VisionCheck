import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 18,
    this.showValue = false,
  });

  final int rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating ? const Color(0xFFF59E0B) : AdminTheme.border,
          ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text('$rating/5', style: TextStyle(fontSize: size * 0.65, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
        ],
      ],
    );
  }
}

class FeedbackStatusBadge extends StatelessWidget {
  const FeedbackStatusBadge({super.key, required this.status});

  final FeedbackReviewStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
    );
  }
}

class LowRatingAlertBanner extends StatelessWidget {
  const LowRatingAlertBanner({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_outlined, size: 20, color: AdminTheme.danger.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Needs Administrator Attention',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(reason, style: const TextStyle(fontSize: 12, height: 1.4, color: AdminTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
