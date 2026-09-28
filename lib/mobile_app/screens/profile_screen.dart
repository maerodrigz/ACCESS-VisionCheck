import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_evaluation_summary.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_settings_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_logout_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_achievements.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_requestor_feedback.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';

const _kProfileSectionGap = kMemberDashboardSectionGap;

/// Member Profile screen — opened from the header avatar on any tab.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onViewRankings,
    this.onViewEvaluations,
    this.onNotificationsTap,
  });

  final VoidCallback? onViewRankings;
  final VoidCallback? onViewEvaluations;
  final VoidCallback? onNotificationsTap;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();

  Future<void> _openEditProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (saved == true && mounted) {
      await memberDataController.refreshAll();
    }
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
      builder: (context, __) {
        final compact = MediaQuery.sizeOf(context).width < 360;
        final profileLoadFailed = memberDataController.profileLoadError != null &&
            !memberDataController.isLoading &&
            !memberDataController.profileLoaded;
        final profileLoading = !memberDataController.profileLoaded &&
            !profileLoadFailed &&
            (memberDataController.isLoading ||
                !memberDataController.profileLoadAttempted);

        final pagePadding = mobilePagePaddingOf(context);

        return Scaffold(
          backgroundColor: kMemberDashboardBg,
          body: RefreshIndicator(
            color: kAccent,
            onRefresh: () => memberDataController.refreshAll(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: profileLoading
                      ? const MemberProfileHeroSkeleton()
                      : profileLoadFailed
                          ? Padding(
                              padding: EdgeInsets.fromLTRB(
                                pagePadding,
                                12,
                                pagePadding,
                                0,
                              ),
                              child: MemberProfileLoadError(
                                onRetry: memberDataController.refreshProfile,
                              ),
                            )
                          : _ProfileMiniHero(
                              onEdit: _openEditProfile,
                              compact: compact,
                              onNotificationsTap: widget.onNotificationsTap,
                            ),
                ),
                if (profileLoading)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          MemberProfileActionRowSkeleton(),
                          SizedBox(height: _kProfileSectionGap),
                          MemberProfileAchievementsSkeleton(),
                        ],
                      ),
                    ),
                  )
                else if (!profileLoadFailed)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                                _ProfileActionRow(
                                  compact: compact,
                                  onRankings: widget.onViewRankings,
                                ),
                          const SizedBox(height: _kProfileSectionGap),
                          MemberProfileAchievementsSection(
                            onViewRankings: widget.onViewRankings,
                            onViewEvaluations: widget.onViewEvaluations,
                          ),
                          const SizedBox(height: _kProfileSectionGap),
                          const MemberProfileRequestorFeedbackSection(),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding,
                    _kProfileSectionGap,
                    pagePadding,
                    kMemberDashboardPagePadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const MemberProfileSettingsSection(),
                        const SizedBox(height: 12),
                        const MemberProfileLogoutSection(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
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

String _formatXp(int value) {
  final s = value.abs().toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _ProfileMiniHero extends StatelessWidget {
  const _ProfileMiniHero({
    required this.onEdit,
    required this.compact,
    this.onNotificationsTap,
  });

  final VoidCallback onEdit;
  final bool compact;
  final VoidCallback? onNotificationsTap;

  static String _accountStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return 'Active Member';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'inactive':
        return 'Inactive';
      default:
        if (status.trim().isEmpty) return '';
        return status.trim()[0].toUpperCase() +
            status.trim().substring(1).toLowerCase();
    }
  }

  static bool _isActiveStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'approved' || s == 'active';
  }

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final snapshot = MemberCompetencySnapshot.fromAppState();
    final rawStatus = appState.profileStatus.trim();
    final statusLabel =
        rawStatus.isNotEmpty ? _accountStatusLabel(rawStatus) : '';
    final isActive = _isActiveStatus(rawStatus);
    final isPending = rawStatus.toLowerCase() == 'pending';
    final displayName = appState.profileName.trim();
    final role = appState.profileRole;
    final email = appState.profileEmail.trim();
    final rank = appState.profileRank;
    final skillLevel = memberDashboardCompetencyLevel();
    final summary = MemberEvaluationSummaryData.fromAppState();

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
          padding: EdgeInsets.fromLTRB(padding, 4, padding, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (Navigator.canPop(context))
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: kMobileMinTouch,
                          height: kMobileMinTouch,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'Your profile',
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      )),
                    ),
                  ),
                  MemberDarkHeroNotificationButton(onTap: onNotificationsTap),
                ],
              ),
              SizedBox(height: compact ? 10 : 12),
              Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileAvatarWithRank(rank: rank, compact: compact),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayName.isNotEmpty)
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.15,
                          )),
                        ),
                      if (role.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: dashText(TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ],
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          )),
                        ),
                      ],
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_rounded,
                        size: compact ? 18 : 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ProfileHeroChip(
                  icon: Icons.workspace_premium_rounded,
                  label: skillLevel,
                  compact: compact,
                ),
                if (statusLabel.isNotEmpty)
                  _ProfileHeroChip(
                    icon: isActive
                        ? Icons.check_circle_rounded
                        : isPending
                            ? Icons.schedule_rounded
                            : Icons.info_outline_rounded,
                    label: statusLabel,
                    compact: compact,
                    filled: isActive,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.white.withValues(alpha: 0.2)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: snapshot.progress.clamp(0.0, 1.0),
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (snapshot.isMaxLevel)
              Text(
                'Maximum skill tier reached',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
              )
            else
              Text(
                '${_formatXp(snapshot.points)} XP · ${_formatXp(snapshot.remainingPoints)} to ${snapshot.nextLevelName ?? 'next level'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
              ),
            const SizedBox(height: 14),
            _ProfileHeroStatsRow(
              compact: compact,
              rank: rank,
              xp: appState.profilePoints,
              evaluationCount: summary.completedCount,
              averageScore: summary.averageScorePercent,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ProfileHeroStatsRow extends StatelessWidget {
  const _ProfileHeroStatsRow({
    required this.compact,
    required this.rank,
    required this.xp,
    required this.evaluationCount,
    required this.averageScore,
  });

  final bool compact;
  final int rank;
  final int xp;
  final int evaluationCount;
  final int? averageScore;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (rank > 0 ? '#$rank' : '-', 'Rank'),
      (_formatXp(xp), 'Total XP'),
      ('$evaluationCount', evaluationCount == 1 ? 'Evaluation' : 'Evaluations'),
      (averageScore != null ? '$averageScore%' : '-', 'Avg Score'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 28,
                margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
                color: Colors.white.withValues(alpha: 0.16),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stats[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: dashText(TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    )),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: dashText(TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: compact ? 8.5 : 10,
                      fontWeight: FontWeight.w500,
                    )),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHeroChip extends StatelessWidget {
  const _ProfileHeroChip({
    required this.icon,
    required this.label,
    required this.compact,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final maxChipWidth = MediaQuery.sizeOf(context).width - 32;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: Colors.white),
          SizedBox(width: compact ? 5 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                fontSize: compact ? 11 : 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatarWithRank extends StatelessWidget {
  const _ProfileAvatarWithRank({
    required this.rank,
    required this.compact,
  });

  final int rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 34.0 : 38.0;
    final imageUrl = appState.profileImageUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? _DefaultAvatarContent(compact: compact)
                : null,
          ),
        ),
        if (rank > 0)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '#$rank',
                style: dashText(const TextStyle(
                  color: kMemberPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                )),
              ),
            ),
          ),
      ],
    );
  }
}

class _DefaultAvatarContent extends StatelessWidget {
  const _DefaultAvatarContent({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final initials = appState.profileInitials.trim();
    if (initials.isNotEmpty && initials != '?') {
      return Text(
        initials,
        style: dashText(const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        )),
      );
    }
    return Icon(
      Icons.person_rounded,
      size: compact ? 32 : 36,
      color: Colors.white.withValues(alpha: 0.9),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.compact,
    this.onRankings,
  });

  final bool compact;
  final VoidCallback? onRankings;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 8.0 : 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ProfileActionTile(
                compact: compact,
                icon: Icons.assignment_rounded,
                title: 'My Assignments',
                subtitle: 'Coverage and tasks',
                backgroundColor: kAccent.withValues(alpha: 0.07),
                borderColor: kAccent.withValues(alpha: 0.18),
                iconColor: kAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _ProfileActionTile(
                compact: compact,
                icon: Icons.leaderboard_rounded,
                title: 'Leaderboard',
                subtitle: 'Rankings and XP',
                backgroundColor: kCyan.withValues(alpha: 0.10),
                borderColor: kCyan.withValues(alpha: 0.22),
                iconColor: kCyan,
                onTap: onRankings,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.compact,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.backgroundColor = kSurface,
    this.borderColor = kBorder,
    this.iconColor,
    this.onTap,
  });

  final bool compact;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color borderColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberDashboardIconTile(
                icon: icon,
                size: compact ? 38 : 42,
                iconSize: compact ? 19 : 21,
                color: iconColor ?? kAccent,
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: memberDashboardCardTitleStyle.copyWith(fontSize: compact ? 13 : 14),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: memberDashboardMetaStyle.copyWith(fontSize: compact ? 10 : 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
