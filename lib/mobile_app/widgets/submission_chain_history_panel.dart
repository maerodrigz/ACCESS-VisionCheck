import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/models/submission_chain_history.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class SubmissionChainHistoryPanel extends StatelessWidget {
  const SubmissionChainHistoryPanel({
    super.key,
    required this.history,
  });

  final SubmissionChainHistory history;

  @override
  Widget build(BuildContext context) {
    if (history.media.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: evalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Submission history',
            style: evalSectionTitleStyle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Original evidence is kept. Replacements stay linked to this evaluation chain.',
            style: evalSectionSubtitleStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...history.media.map((item) => _ChainMediaTile(item: item, rootId: history.rootMediaId)),
        ],
      ),
    );
  }
}

class _ChainMediaTile extends StatelessWidget {
  const _ChainMediaTile({required this.item, required this.rootId});

  final SubmissionChainMediaItem item;
  final int rootId;

  String get _roleLabel {
    if (item.mediaId == rootId) return 'Original submission';
    if (item.replacementLifecycle == 'active') return 'Replacement (in review)';
    if (item.replacementLifecycle == 'superseded') return 'Replacement (accepted)';
    if (item.replacementLifecycle == 'terminal') return 'Replacement (rejected)';
    return 'Replacement';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.mediaId == rootId ? Icons.photo_library_outlined : Icons.swap_horiz_rounded,
            size: 20,
            color: kAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 2),
                Text(
                  _roleLabel,
                  style: const TextStyle(color: kTextSecondary, fontSize: 11),
                ),
                if (item.reviewStatus != null && item.reviewStatus!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AdminReviewStatusBadge(reviewStatus: item.reviewStatus!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
