import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

String _formatRole(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Assignment';
  final normalized = raw.trim().replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

String _formatDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final dt = DateTime.tryParse(raw.trim());
  if (dt == null) return raw.trim();
  final local = dt.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 18});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < rating ? kYellow : kTextSecondary,
          size: size,
        ),
      ),
    );
  }
}

/// Requestor ratings and comments received by the logged-in documentation member.
class MemberProfileRequestorFeedbackSection extends StatelessWidget {
  const MemberProfileRequestorFeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        if (!memberDataController.requestorRatingsLoaded) {
          return const SizedBox.shrink();
        }

        final count = memberDataController.requestorRatingCount;
        final average = memberDataController.requestorRatingAverage;
        final ratings = memberDataController.requestorRatings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccessSectionHeader(title: 'Requester Feedback'),
            const SizedBox(height: 12),
            if (count <= 0)
              MemberDashboardCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    MemberDashboardIconTile(
                      icon: Icons.rate_review_outlined,
                      size: 42,
                      iconSize: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No requester feedback yet',
                            style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'After events, requestors can rate your work. Feedback will appear here.',
                            style: memberDashboardMetaStyle.copyWith(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              MemberDashboardCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    MemberDashboardIconTile(
                      icon: Icons.star_rate_rounded,
                      size: 42,
                      iconSize: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            average != null ? average.toStringAsFixed(1) : 'N/A',
                            style: memberDashboardCardTitleStyle.copyWith(fontSize: 20),
                          ),
                          Text(
                            count == 1 ? '1 requester rating' : '$count requester ratings',
                            style: memberDashboardMetaStyle,
                          ),
                        ],
                      ),
                    ),
                    if (average != null)
                      _StarRow(rating: average.round().clamp(1, 5), size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...ratings.map((row) {
                final rating = (row['rating'] as num?)?.toInt() ?? 0;
                final eventTitle = row['event_title'] as String?;
                final requestorName = row['requestor_name'] as String?;
                final taskRole = _formatRole(row['task_role'] as String?);
                final comment = row['comment'] as String?;
                final dateLabel = _formatDate(row['created_at'] as String?);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MemberDashboardCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eventTitle?.trim().isNotEmpty == true
                                        ? eventTitle!.trim()
                                        : 'Event #${row['request_id']}',
                                    style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (requestorName?.trim().isNotEmpty == true)
                                        requestorName!.trim(),
                                      taskRole,
                                    ].join(' · '),
                                    style: memberDashboardMetaStyle,
                                  ),
                                ],
                              ),
                            ),
                            if (dateLabel.isNotEmpty)
                              Text(dateLabel, style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _StarRow(rating: rating.clamp(0, 5)),
                        if (comment != null && comment.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            comment.trim(),
                            style: memberDashboardBodyStyle.copyWith(
                              color: kTextPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}
