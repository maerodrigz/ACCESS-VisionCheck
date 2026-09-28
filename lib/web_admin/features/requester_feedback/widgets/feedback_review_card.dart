import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/feedback_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef FeedbackItemTap = void Function(RequesterFeedbackItem item);

class FeedbackReviewCard extends StatefulWidget {
  const FeedbackReviewCard({
    super.key,
    required this.item,
    required this.onViewDetails,
    required this.onRespond,
    required this.onArchive,
  });

  final RequesterFeedbackItem item;
  final FeedbackItemTap onViewDetails;
  final FeedbackItemTap onRespond;
  final FeedbackItemTap onArchive;

  @override
  State<FeedbackReviewCard> createState() => _FeedbackReviewCardState();
}

class _FeedbackReviewCardState extends State<FeedbackReviewCard> {
  bool _hovered = false;

  RequesterFeedbackItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AdminTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.35) : AdminTheme.border),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                  child: Text(
                    item.organizationInitials,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.accentBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.eventName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(item.organization, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Event · ${formatFeedbackDate(item.eventDate)}', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StarRatingDisplay(rating: item.rating, size: 22, showValue: true),
            if (item.needsAttention) ...[
              const SizedBox(height: 10),
              LowRatingAlertBanner(reason: item.attentionReason ?? 'Low rating'),
            ],
            const SizedBox(height: 12),
            Text(
              item.commentPreview,
              style: const TextStyle(fontSize: 12, height: 1.45, color: AdminTheme.textPrimary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text('Submitted ${formatFeedbackDate(item.submittedAt)}', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
            const Spacer(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => widget.onViewDetails(item), child: const Text('View Details')),
                FilledButton(
                  onPressed: () => widget.onRespond(item),
                  style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
                  child: const Text('Respond'),
                ),
                OutlinedButton(onPressed: () => widget.onArchive(item), child: const Text('Archive')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
