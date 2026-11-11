import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/screens/member_achievements_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_evaluation_summary.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_settings_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_logout_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_skeleton.dart';

const _kSectionGap = 12.0;
const _kSkyBg = Color(0xFFF3F9FF);

/// Member Profile tab: compact identity, stats, skill, activity, and settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onViewRankings,
    this.onViewEvaluations,
    this.onNotificationsTap,
    this.scrollToRequestorFeedback = false,
  });

  final VoidCallback? onViewRankings;
  final VoidCallback? onViewEvaluations;
  final VoidCallback? onNotificationsTap;
  final bool scrollToRequestorFeedback;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();
  final _requestorFeedbackSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(memberDataController.syncRankingsForProfileIfNeeded());
      unawaited(memberDataController.refreshMilestones());
    });
    if (widget.scrollToRequestorFeedback) {
      _scheduleScrollToRequestorFeedback();
    }
  }

  void _scheduleScrollToRequestorFeedback() {
    var attempts = 0;
    void attempt() {
      if (!mounted || attempts > 90) return;
      attempts++;
      if (memberDataController.requestorRatingsLoaded) {
        _scrollToRequestorFeedback();
        return;
      }
      if (memberDataController.profileLoadError != null) return;
      if (memberDataController.profileLoaded &&
          !memberDataController.requestorRatingsLoaded) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _scrollToRequestorFeedback() {
    final target = _requestorFeedbackSectionKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _openEditProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (saved == true && mounted) {
      await memberDataController.refreshAll();
    }
  }

  void _openAchievements() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemberAchievementsScreen(
          onViewEvaluations: widget.onViewEvaluations,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final compact = MediaQuery.sizeOf(context).width < 360;
        final pagePadding = mobilePagePaddingOf(context);

        final profileLoadFailed = memberDataController.profileLoadError != null &&
            !memberDataController.isLoading &&
            !memberDataController.profileLoaded;
        final profileLoading = !memberDataController.profileLoaded &&
            !profileLoadFailed &&
            (memberDataController.isLoading || !memberDataController.profileLoadAttempted);

        return Scaffold(
          backgroundColor: _kSkyBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileTopBar(
                  compact: compact,
                  onNotificationsTap: widget.onNotificationsTap,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: kCyan,
                    onRefresh: () => memberDataController.refreshAll(),
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        pagePadding,
                        8,
                        pagePadding,
                        kMemberDashboardPagePadding,
                      ),
                      children: [
                        if (profileLoadFailed)
                          MemberProfileLoadError(
                            onRetry: memberDataController.refreshProfile,
                          )
                        else if (profileLoading) ...[
                          const MemberProfileHeroSkeleton(),
                          const SizedBox(height: _kSectionGap),
                          const MemberProfileStatStripSkeleton(),
                          const SizedBox(height: _kSectionGap),
                          const MemberProfileAchievementsSkeleton(),
                        ] else ...[
                          _CompactProfileCard(
                            compact: compact,
                            onEdit: _openEditProfile,
                          ),
                          const SizedBox(height: _kSectionGap),
                          const _QuickStatsStrip(),
                          const SizedBox(height: _kSectionGap),
                          const MemberProfileSkillProgressSection(),
                          const SizedBox(height: _kSectionGap),
                          _MyActivitySection(
                            onViewEvaluations: widget.onViewEvaluations,
                            onViewAchievements: _openAchievements,
                          ),
                          const SizedBox(height: _kSectionGap),
                          KeyedSubtree(
                            key: _requestorFeedbackSectionKey,
                            child: const _CompactRequestorFeedbackCard(),
                          ),
                        ],
                        if (!profileLoading) ...[
                          const SizedBox(height: _kSectionGap),
                          const MemberProfileSettingsSection(),
                          const MemberProfileLogoutSection(),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Center(
                            child: Text(
                              '${brandingController.appName} · ${brandingController.organization}',
                              textAlign: TextAlign.center,
                              style: memberDashboardMetaStyle.copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    required this.compact,
    this.onNotificationsTap,
  });

  final bool compact;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 8, 2, 4, 2),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              color: kTextPrimary,
              iconSize: 22,
              style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
            ),
          Expanded(
            child: Text(
              'Profile',
              style: dashText(const TextStyle(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              )),
            ),
          ),
          MemberDarkHeroNotificationButton(
            onTap: onNotificationsTap,
            compact: compact,
            onCyanHero: false,
          ),
        ],
      ),
    );
  }
}

class _CompactProfileCard extends StatelessWidget {
  const _CompactProfileCard({
    required this.compact,
    required this.onEdit,
  });

  final bool compact;
  final VoidCallback onEdit;

  static String _accountStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return 'Active';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'inactive':
        return 'Inactive';
      default:
        if (status.trim().isEmpty) return '';
        final t = status.trim();
        return t[0].toUpperCase() + t.substring(1).toLowerCase();
    }
  }

  static bool _isActiveStatus(String s) {
    final l = s.trim().toLowerCase();
    return l == 'approved' || l == 'active';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = appState.profileName.trim();
    final rawStatus = appState.profileStatus.trim();
    final statusLabel = rawStatus.isNotEmpty ? _accountStatusLabel(rawStatus) : '';
    final isActive = _isActiveStatus(rawStatus);
    final competencyLevel = memberDashboardCompetencyLevel();
    final titleLabel = appState.profileTitleLabel;
    final imageUrl = appState.profileImageUrl;
    final rank = appState.profileRank;

    return Container(
      decoration: BoxDecoration(
        gradient: kMemberDashboardHeroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 14, compact ? 12 : 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatar(
                rank: rank,
                imageUrl: imageUrl,
                compact: compact,
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayName.isNotEmpty)
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 17 : 18,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.2,
                        )),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      titleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Skill: $competencyLevel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                    ),
                    if (statusLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? kGreen
                                : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                size: 13,
                                color: isActive ? Colors.white : kYellow,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: dashText(TextStyle(
                                  color: isActive ? Colors.white : kTextPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Material(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: kMemberPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Edit Profile',
                      style: dashText(const TextStyle(
                        color: kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.rank,
    required this.compact,
    this.imageUrl,
  });

  final int rank;
  final bool compact;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 28.0 : 32.0;
    final initials = appState.profileInitials.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: kAccent.withValues(alpha: 0.35),
            backgroundImage:
                imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null || imageUrl!.isEmpty
                ? Text(
                    initials.isNotEmpty && initials != '?' ? initials : '?',
                    style: dashText(TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.44,
                      fontWeight: FontWeight.w800,
                    )),
                  )
                : null,
          ),
        ),
        if (rank > 0)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '#$rank',
                style: dashText(const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                )),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final rank = appState.profileRank;
        final xp = appState.profilePoints;
        final evals = MemberEvaluationSummaryData.fromAppState().completedCount;
        final rankLabel = rank > 0 ? '#$rank' : 'N/A';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick stats',
              style: memberDashboardSectionTitleStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            MemberDashboardCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickStatTile(
                        icon: Icons.leaderboard_rounded,
                        value: rankLabel,
                        label: 'Rank',
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: kBorder.withValues(alpha: 0.7),
                    ),
                    Expanded(
                      child: _QuickStatTile(
                        icon: Icons.bolt_rounded,
                        value: MemberProfileSkillProgressSection.formatParticipationXp(xp),
                        label: 'XP',
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: kBorder.withValues(alpha: 0.7),
                    ),
                    Expanded(
                      child: _QuickStatTile(
                        icon: Icons.fact_check_outlined,
                        value: '$evals',
                        label: 'Evals',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  const _QuickStatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: kCyan),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: dashText(const TextStyle(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.05,
              )),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: memberDashboardMetaStyle.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MyActivitySection extends StatelessWidget {
  const _MyActivitySection({
    this.onViewEvaluations,
    required this.onViewAchievements,
  });

  final VoidCallback? onViewEvaluations;
  final VoidCallback onViewAchievements;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Activity',
          style: memberDashboardSectionTitleStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActivityNavCard(
                icon: Icons.analytics_rounded,
                title: 'Evaluations',
                subtitle: 'History & reports',
                onTap: onViewEvaluations,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityNavCard(
                icon: Icons.emoji_events_rounded,
                title: 'Achievements',
                subtitle: 'Badges & titles',
                onTap: onViewAchievements,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityNavCard extends StatelessWidget {
  const _ActivityNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder.withValues(alpha: 0.85)),
            boxShadow: memberDashboardCardShadows(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberDashboardIconTile(
                icon: icon,
                size: 40,
                iconSize: 20,
                color: kCyan,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: memberDashboardMetaStyle.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRequestorFeedbackCard extends StatelessWidget {
  const _CompactRequestorFeedbackCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        if (!memberDataController.requestorRatingsLoaded) {
          final err = memberDataController.requestorRatingsLoadError;
          return MemberDashboardCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: err != null
                ? Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: kRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          err,
                          style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: memberDataController.refreshRequestorRatings,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const Row(
                    children: [
                      MemberProfileSkeletonBone(height: 16, width: 16, radius: 4),
                      SizedBox(width: 12),
                      Expanded(
                        child: MemberProfileSkeletonBone(
                          height: 12,
                          width: double.infinity,
                          radius: 4,
                        ),
                      ),
                    ],
                  ),
          );
        }

        final count = memberDataController.requestorRatingCount;
        final average = memberDataController.requestorRatingAverage;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requester Feedback',
              style: memberDashboardSectionTitleStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            MemberDashboardCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  MemberDashboardIconTile(
                    icon: Icons.rate_review_outlined,
                    size: 40,
                    iconSize: 20,
                    color: kCyan,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: count <= 0
                        ? Text(
                            'No requester feedback yet.',
                            style: memberDashboardMetaStyle.copyWith(fontSize: 13),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                average != null
                                    ? '${average.toStringAsFixed(1)} average'
                                    : 'Feedback received',
                                style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                count == 1 ? '1 rating' : '$count ratings',
                                style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
