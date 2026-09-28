import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class MemberTeamRatingTarget {
  MemberTeamRatingTarget({
    required this.assignmentId,
    required this.memberName,
    required this.taskRole,
    required this.rated,
    this.existingRating,
    this.existingComment,
  });

  factory MemberTeamRatingTarget.fromMap(Map<String, dynamic> m) {
    return MemberTeamRatingTarget(
      assignmentId: (m['assignment_id'] as num).toInt(),
      memberName: m['member_name'] as String? ?? 'Team member',
      taskRole: m['task_role'] as String? ?? 'coverage',
      rated: m['rated'] == true,
      existingRating: (m['rating'] as num?)?.toInt(),
      existingComment: m['comment'] as String?,
    );
  }

  final int assignmentId;
  final String memberName;
  final String taskRole;
  final bool rated;
  final int? existingRating;
  final String? existingComment;

  String get roleLabel {
    final r = taskRole.toLowerCase();
    if (r.contains('video')) return 'Videographer';
    if (r.contains('photo')) return 'Photographer';
    return 'Documentation member';
  }
}

class MemberTeamRatingSection extends StatelessWidget {
  const MemberTeamRatingSection({
    super.key,
    required this.targets,
    required this.ratings,
    required this.commentControllers,
    required this.onRatingChanged,
    required this.loading,
  });

  final List<MemberTeamRatingTarget> targets;
  final Map<int, int> ratings;
  final Map<int, TextEditingController> commentControllers;
  final void Function(int assignmentId, int rating) onRatingChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
          ),
        ),
      );
    }
    if (targets.isEmpty) {
      return Text(
        'No assigned photographers or videographers to rate yet. Team ratings unlock after members accept coverage.',
        style: memberDashboardMetaStyle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate your documentation team',
          style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Give a star rating for each photographer and videographer who covered this event.',
          style: memberDashboardMetaStyle.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 12),
        for (final t in targets) ...[
          _MemberRatingTile(
            target: t,
            rating: ratings[t.assignmentId] ?? t.existingRating ?? 0,
            commentController: commentControllers[t.assignmentId]!,
            onRatingChanged: (r) => onRatingChanged(t.assignmentId, r),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MemberRatingTile extends StatelessWidget {
  const _MemberRatingTile({
    required this.target,
    required this.rating,
    required this.commentController,
    required this.onRatingChanged,
  });

  final MemberTeamRatingTarget target;
  final int rating;
  final TextEditingController commentController;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: kAccent.withValues(alpha: 0.12),
                child: Icon(
                  target.roleLabel == 'Videographer'
                      ? Icons.videocam_rounded
                      : Icons.photo_camera_rounded,
                  color: kAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.memberName,
                      style: memberDashboardBodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(target.roleLabel, style: memberDashboardMetaStyle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => onRatingChanged(i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i < rating ? kYellow : kTextSecondary,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentController,
            maxLines: 2,
            style: memberDashboardBodyStyle.copyWith(color: kTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Optional comment about ${target.memberName}',
              hintStyle: memberDashboardMetaStyle.copyWith(fontSize: 12),
              filled: true,
              fillColor: kSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
