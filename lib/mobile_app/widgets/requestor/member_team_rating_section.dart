import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

const _kDocStar = Color(0xFFF5B400);
const _kDocCyan = Color(0xFF079FC6);
const _kDocNavy = Color(0xFF173650);
const _kDocMeta = Color(0xFF617F91);
const _kDocSky = Color(0xFFEAF7FC);
const _kDocBorder = Color(0xFFD0EBF5);

class MemberTeamRatingTarget {
  MemberTeamRatingTarget({
    required this.assignmentId,
    required this.memberName,
    required this.taskRole,
    required this.rated,
    this.existingRating,
    this.existingComment,
    this.memberId,
    this.profileImageUrl,
  });

  factory MemberTeamRatingTarget.fromMap(Map<String, dynamic> m) {
    String? imageUrl;
    for (final key in const ['profile_image_url', 'avatar_url']) {
      final raw = (m[key] as String?)?.trim();
      if (raw != null && raw.isNotEmpty) {
        imageUrl = raw;
        break;
      }
    }
    return MemberTeamRatingTarget(
      assignmentId: (m['assignment_id'] as num).toInt(),
      memberId: (m['member_id'] as num?)?.toInt(),
      memberName: m['member_name'] as String? ?? 'Documenter',
      taskRole: m['task_role'] as String? ?? 'coverage',
      rated: m['rated'] == true,
      existingRating: (m['rating'] as num?)?.toInt(),
      existingComment: m['comment'] as String?,
      profileImageUrl: imageUrl,
    );
  }

  final int assignmentId;
  final int? memberId;
  final String memberName;
  final String taskRole;
  final bool rated;
  final int? existingRating;
  final String? existingComment;
  final String? profileImageUrl;

  String get roleLabel {
    final r = taskRole.toLowerCase();
    if (r.contains('video')) return 'Videographer';
    if (r.contains('photo')) return 'Photographer';
    return 'Documenter';
  }

  String get initials {
    final parts = memberName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    final out = '$a$b'.toUpperCase();
    return out.isEmpty ? '?' : out;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate Your Documenters',
          style: memberDashboardMetaStyle.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: _kDocNavy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Rate each documenter assigned to your event.',
          style: memberDashboardMetaStyle.copyWith(
            fontSize: 11,
            color: _kDocMeta,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (targets.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Required for every listed documenter',
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 11,
              color: _kDocCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (targets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _kDocSky,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kDocBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _kDocCyan.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No eligible documenters available for individual feedback. '
                    'You can still submit Event Coverage Feedback.',
                    style: memberDashboardMetaStyle.copyWith(
                      fontSize: 11.5,
                      height: 1.35,
                      color: _kDocMeta,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
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
    final imageUrl = target.profileImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final needsRating = !target.rated && rating <= 0;

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
                backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
                child: hasImage
                    ? null
                    : Text(
                        target.initials,
                        style: memberDashboardBodyStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: kAccent,
                        ),
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
              if (!target.rated)
                Text(
                  'Required',
                  style: memberDashboardMetaStyle.copyWith(
                    fontSize: 11,
                    color: _kDocCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Semantics(
                  button: true,
                  label: 'Rate ${target.memberName} ${i + 1} stars',
                  child: GestureDetector(
                    onTap: target.rated ? null : () => onRatingChanged(i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < rating ? _kDocStar : kTextSecondary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              if (needsRating) ...[
                const SizedBox(width: 4),
                Text(
                  'Select a rating',
                  style: memberDashboardMetaStyle.copyWith(
                    fontSize: 11,
                    color: kRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentController,
            enabled: !target.rated,
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
