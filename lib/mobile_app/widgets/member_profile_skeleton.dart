import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

/// Shimmer-style bone used across profile skeleton placeholders.
class MemberProfileSkeletonBone extends StatefulWidget {
  const MemberProfileSkeletonBone({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<MemberProfileSkeletonBone> createState() => _MemberProfileSkeletonBoneState();
}

class _MemberProfileSkeletonBoneState extends State<MemberProfileSkeletonBone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final value = 0.35 + (_pulse.value * 0.3);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [
                kDashBorder.withValues(alpha: value),
                kDashBorder.withValues(alpha: value * 0.55),
                kDashBorder.withValues(alpha: value),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dark hero placeholder aligned with profile mini-hero.
class MemberProfileHeroSkeleton extends StatelessWidget {
  const MemberProfileHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final padding = mobilePagePaddingOf(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberDarkHeroMiniBottomRadius),
          bottomRight: Radius.circular(kMemberDarkHeroMiniBottomRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(padding, 6, padding, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemberProfileSkeletonBone(
            height: 11,
            width: compact ? 72 : 80,
            radius: 4,
          ),
          SizedBox(height: compact ? 10 : 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberProfileSkeletonBone(
                height: compact ? 72 : 80,
                width: compact ? 72 : 80,
                radius: 999,
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MemberProfileSkeletonBone(
                      height: compact ? 18 : 20,
                      width: double.infinity,
                      radius: 6,
                    ),
                    const SizedBox(height: 8),
                    MemberProfileSkeletonBone(
                      height: 12,
                      width: double.infinity,
                      radius: 4,
                    ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      alignment: Alignment.centerLeft,
                      child: MemberProfileSkeletonBone(
                        height: 12,
                        width: double.infinity,
                        radius: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const MemberProfileSkeletonBone(height: 36, width: 36, radius: 10),
            ],
          ),
          const SizedBox(height: 14),
          MemberProfileSkeletonBone(
            height: 28,
            width: compact ? 120 : 140,
            radius: 999,
          ),
          const SizedBox(height: 12),
          const MemberProfileSkeletonBone(height: 8, width: double.infinity, radius: 999),
          const SizedBox(height: 10),
          MemberProfileSkeletonBone(height: 12, width: compact ? 180 : 220, radius: 4),
          const SizedBox(height: 14),
          MemberProfileSkeletonBone(
            height: compact ? 56 : 60,
            width: double.infinity,
            radius: 14,
          ),
        ],
      ),
    );
  }
}

/// Requestor profile hero placeholder — no member XP/stats strip.
class RequestorProfileHeroSkeleton extends StatelessWidget {
  const RequestorProfileHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberDarkHeroMiniBottomRadius),
          bottomRight: Radius.circular(kMemberDarkHeroMiniBottomRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 6, 18, compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FractionallySizedBox(
                widthFactor: 0.34,
                alignment: Alignment.centerLeft,
                child: MemberProfileSkeletonBone(
                  height: 11,
                  width: double.infinity,
                  radius: 4,
                ),
              ),
              SizedBox(height: compact ? 12 : 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemberProfileSkeletonBone(
                    height: compact ? 72 : 80,
                    width: compact ? 72 : 80,
                    radius: 999,
                  ),
                  SizedBox(width: compact ? 12 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MemberProfileSkeletonBone(
                          height: compact ? 18 : 20,
                          width: double.infinity,
                          radius: 6,
                        ),
                        const SizedBox(height: 8),
                        MemberProfileSkeletonBone(
                          height: 12,
                          width: double.infinity,
                          radius: 4,
                        ),
                      ],
                    ),
                  ),
                  const MemberProfileSkeletonBone(height: 36, width: 36, radius: 10),
                ],
              ),
              const SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: 0.48,
                alignment: Alignment.centerLeft,
                child: MemberProfileSkeletonBone(
                  height: 24,
                  width: double.infinity,
                  radius: 999,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four-stat strip placeholder.
class MemberProfileStatStripSkeleton extends StatelessWidget {
  const MemberProfileStatStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: memberDashboardCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Row(
                children: [
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      color: kDashBorder,
                    ),
                  Expanded(
                    child: Column(
                      children: const [
                        MemberProfileSkeletonBone(height: 18, width: 36, radius: 4),
                        SizedBox(height: 6),
                        MemberProfileSkeletonBone(height: 10, width: 48, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Two action tile placeholders.
class MemberProfileActionRowSkeleton extends StatelessWidget {
  const MemberProfileActionRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: MemberProfileSkeletonBone(height: 118, radius: 20)),
        SizedBox(width: 10),
        Expanded(child: MemberProfileSkeletonBone(height: 118, radius: 20)),
      ],
    );
  }
}

/// Achievements section placeholder.
class MemberProfileAchievementsSkeleton extends StatelessWidget {
  const MemberProfileAchievementsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AccessSectionHeader(title: 'Achievements'),
        const SizedBox(height: 12),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => const MemberProfileSkeletonBone(
              height: 108,
              width: 88,
              radius: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width error state when `/member/profile` cannot be loaded.
class MemberProfileLoadError extends StatelessWidget {
  const MemberProfileLoadError({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: memberDashboardCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: MobileEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to Load Profile',
            subtitle:
                'Something went wrong while loading your profile information.',
            actionLabel: 'Retry',
            onAction: onRetry,
          ),
        ),
      ),
    );
  }
}

// Legacy skeleton aliases kept for any external references.
typedef MemberProfileHeaderSkeleton = MemberProfileHeroSkeleton;
typedef MemberProfileEditButtonSkeleton = MemberProfileHeroSkeleton;
typedef MemberProfileQuickNavSkeleton = MemberProfileActionRowSkeleton;
typedef MemberProfileSkillProgressSkeleton = MemberProfileStatStripSkeleton;
typedef MemberProfileEvaluationSummarySkeleton = MemberProfileAchievementsSkeleton;
typedef MemberProfileActionButtonsSkeleton = MemberProfileActionRowSkeleton;
