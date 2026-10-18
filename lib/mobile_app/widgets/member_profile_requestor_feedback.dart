import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

String _formatRole(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Assignment';
  final normalized = raw.trim().replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

String formatRequestorFeedbackDate(String? raw) {
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

class RequestorFeedbackStarRow extends StatelessWidget {
  const RequestorFeedbackStarRow({super.key, required this.rating, this.size = 18});

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

/// Single requestor rating row (stars, event, comment, date).
class RequestorFeedbackEntryCard extends StatelessWidget {
  const RequestorFeedbackEntryCard({
    super.key,
    required this.row,
    this.compact = false,
    this.showRequestorMeta = true,
  });

  final Map<String, dynamic> row;
  final bool compact;
  final bool showRequestorMeta;

  @override
  Widget build(BuildContext context) {
    final rating = (row['rating'] as num?)?.toInt() ?? 0;
    final eventTitle = row['event_title'] as String?;
    final requestorName = row['requestor_name'] as String?;
    final taskRole = _formatRole(row['task_role'] as String?);
    final comment = row['comment'] as String?;
    final dateLabel = formatRequestorFeedbackDate(row['created_at'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                eventTitle?.trim().isNotEmpty == true
                    ? eventTitle!.trim()
                    : 'Event #${row['request_id']}',
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: memberDashboardCardTitleStyle.copyWith(fontSize: compact ? 13 : 14),
              ),
            ),
            if (dateLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: memberDashboardMetaStyle.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
        if (showRequestorMeta &&
            (requestorName?.trim().isNotEmpty == true || taskRole.isNotEmpty)) ...[
          const SizedBox(height: 2),
          Text(
            [
              if (requestorName?.trim().isNotEmpty == true) requestorName!.trim(),
              taskRole,
            ].join(' · '),
            style: memberDashboardMetaStyle,
          ),
        ],
        SizedBox(height: compact ? 8 : 10),
        RequestorFeedbackStarRow(
          rating: rating.clamp(0, 5),
          size: compact ? 16 : 18,
        ),
        if (comment != null && comment.trim().isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 10),
          Text(
            comment.trim(),
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: memberDashboardBodyStyle.copyWith(
              color: kTextPrimary,
              height: 1.4,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact home dashboard block; uses the same [memberDataController] data as Profile.
class MemberDashboardRequestorFeedbackSection extends StatelessWidget {
  const MemberDashboardRequestorFeedbackSection({
    super.key,
    required this.onViewAll,
  });

  final VoidCallback onViewAll;

  bool get _isMemberUser =>
      authController.isLoggedIn && !(authController.user?.role.isOrganization ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_isMemberUser) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        final loaded = memberDataController.requestorRatingsLoaded;
        final loadError = memberDataController.requestorRatingsLoadError;
        final loading = !loaded &&
            loadError == null &&
            (memberDataController.isLoading || !memberDataController.profileLoadAttempted);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rate_rounded, size: 20, color: kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requestor Feedback',
                    style: dashText(const TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    )),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: dashText(const TextStyle(
                      color: kMemberButtonPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              _RequestorFeedbackShell(
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: kMemberButtonPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading requestor feedback…',
                      style: memberDashboardMetaStyle,
                    ),
                  ],
                ),
              )
            else if (loadError != null && !loaded)
              _RequestorFeedbackShell(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 20, color: kRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loadError,
                        style: memberDashboardMetaStyle.copyWith(color: kTextPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => memberDataController.refreshRequestorRatings(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (!loaded)
              const SizedBox.shrink()
            else if (memberDataController.requestorRatingCount <= 0)
              _RequestorFeedbackShell(
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined, size: 18, color: kTextSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No requestor feedback yet.',
                        style: memberDashboardMetaStyle.copyWith(
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _RequestorFeedbackShell(
                child: memberDataController.requestorRatings.isEmpty
                    ? const SizedBox.shrink()
                    : RequestorFeedbackEntryCard(
                        row: memberDataController.requestorRatings.first,
                        compact: true,
                        showRequestorMeta: false,
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _RequestorFeedbackShell extends StatelessWidget {
  const _RequestorFeedbackShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
                      RequestorFeedbackStarRow(
                        rating: average.round().clamp(1, 5),
                        size: 20,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...ratings.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MemberDashboardCard(
                    padding: const EdgeInsets.all(16),
                    child: RequestorFeedbackEntryCard(row: row),
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
