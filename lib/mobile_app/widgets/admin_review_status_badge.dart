import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Member-facing badge for admin AI integrity review outcomes.
class AdminReviewStatusBadge extends StatelessWidget {
  const AdminReviewStatusBadge({
    super.key,
    required this.reviewStatus,
    this.compact = false,
  });

  final String reviewStatus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(reviewStatus);
    final color = _colorFor(reviewStatus);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _labelFor(String raw) {
    final n = raw.toLowerCase();
    if (n.contains('verified_human')) return 'Verified authentic';
    if (n.contains('confirmed_ai') || n.contains('verified_ai')) return 'AI confirmed';
    if (n.contains('accepted') && n.contains('warning')) return 'Accepted with warning';
    if (n.contains('reupload')) return 'Reupload requested';
    if (n.contains('reject')) return 'Rejected';
    if (n.contains('further') || n.contains('needs')) return 'Under review';
    if (n.contains('pending')) return 'Under review';
    return raw.replaceAll('_', ' ');
  }

  static Color _colorFor(String raw) {
    final n = raw.toLowerCase();
    if (n.contains('verified_human')) return kGreen;
    if (n.contains('confirmed_ai') || n.contains('verified_ai')) return kRed;
    if (n.contains('accepted') && n.contains('warning')) return kYellow;
    if (n.contains('reupload')) return kAccent;
    if (n.contains('reject')) return kRed;
    if (n.contains('further') || n.contains('needs') || n.contains('pending')) {
      return kYellow;
    }
    return kDashTextSecondary;
  }
}

/// Short panel when admin left remarks on an integrity review.
class AdminReviewRemarksPanel extends StatelessWidget {
  const AdminReviewRemarksPanel({super.key, required this.remarks});

  final String remarks;

  @override
  Widget build(BuildContext context) {
    if (remarks.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADMIN REMARKS',
            style: TextStyle(
              color: kTextSecondary,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            remarks.trim(),
            style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
