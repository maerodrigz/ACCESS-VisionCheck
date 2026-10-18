import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_evaluation_summary.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_settings_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_logout_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_achievements.dart';

const _kSectionGap = 20.0;
/// Thin strip between pinned profile hero and stats card (scroll area only).
const _kProfileStatsCardTopGap = 6.0;
// ─────────────────────────────────────────────────────────────────────────────
// Profile screen
// ─────────────────────────────────────────────────────────────────────────────

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

        Widget fixedHeader;
        if (profileLoading) {
          fixedHeader = const MemberProfileHeroSkeleton();
        } else if (profileLoadFailed) {
          fixedHeader = _ProfileHeaderShell(
            compact: compact,
            onNotificationsTap: widget.onNotificationsTap,
          );
        } else {
          fixedHeader = _ProfileHeader(
            onEdit: _openEditProfile,
            compact: compact,
            onNotificationsTap: widget.onNotificationsTap,
          );
        }

        return Scaffold(
          backgroundColor: kBg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fixedHeader,
              Expanded(
                child: RefreshIndicator(
                  color: kAccent,
                  onRefresh: () => memberDataController.refreshAll(),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      if (profileLoadFailed)
                        Padding(
                          padding: EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, 0),
                          child: MemberProfileLoadError(
                            onRetry: memberDataController.refreshProfile,
                          ),
                        )
                      else if (profileLoading)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            pagePadding,
                            _kProfileStatsCardTopGap,
                            pagePadding,
                            0,
                          ),
                          child: const MemberProfileAchievementsSkeleton(),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            pagePadding,
                            _kProfileStatsCardTopGap,
                            pagePadding,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PerformanceSummaryCard(compact: compact),
                              const SizedBox(height: _kSectionGap),
                              _ProfileAchievementsSection(
                                onViewRankings: widget.onViewRankings,
                                onViewEvaluations: widget.onViewEvaluations,
                              ),
                              const SizedBox(height: _kSectionGap),
                              KeyedSubtree(
                                key: _requestorFeedbackSectionKey,
                                child: const _ProfileFeedbackSection(),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          pagePadding,
                          _kSectionGap,
                          pagePadding,
                          kMemberDashboardPagePadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!profileLoading) ...[
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header — cyan mini-hero (matches sign-in + home dashboard).
// ─────────────────────────────────────────────────────────────────────────────

/// Top bar only when profile body failed to load (header stays pinned).
class _ProfileHeaderShell extends StatelessWidget {
  const _ProfileHeaderShell({
    required this.compact,
    this.onNotificationsTap,
  });

  final bool compact;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: kMemberDashboardHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberProfileHeroBottomRadius),
          bottomRight: Radius.circular(kMemberProfileHeroBottomRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 4, padding - 4, 14),
          child: Row(
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: kMemberCyanHeroSubtitleColor,
                  iconSize: 22,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
              Expanded(
                child: Text(
                  'Profile',
                  style: memberCyanHeroNavLabelStyle(),
                ),
              ),
              MemberDarkHeroNotificationButton(
                onTap: onNotificationsTap,
                compact: compact,
                onCyanHero: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
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
    final padding = mobilePagePaddingOf(context);
    final displayName = appState.profileName.trim();
    final email = appState.profileEmail.trim();
    final rawStatus = appState.profileStatus.trim();
    final statusLabel = rawStatus.isNotEmpty ? _accountStatusLabel(rawStatus) : '';
    final isActive = _isActiveStatus(rawStatus);
    final rank = appState.profileRank;
    final competencyLevel = memberDashboardCompetencyLevel();
    final titleLabel = appState.profileTitleLabel;
    final imageUrl = appState.profileImageUrl;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: kMemberDashboardHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberProfileHeroBottomRadius),
          bottomRight: Radius.circular(kMemberProfileHeroBottomRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar: back / title / notifications / edit
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 4, padding - 4, 0),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: kMemberCyanHeroSubtitleColor,
                      iconSize: 22,
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                    ),
                  Expanded(
                    child: Text(
                      'Profile',
                      style: memberCyanHeroNavLabelStyle(),
                    ),
                  ),
                  MemberDarkHeroNotificationButton(
                    onTap: onNotificationsTap,
                    compact: compact,
                    onCyanHero: true,
                  ),
                ],
              ),
            ),

            // Avatar + identity block
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with rank badge
                  _ProfileAvatar(
                    rank: rank,
                    imageUrl: imageUrl,
                    compact: compact,
                    onDarkHero: true,
                  ),
                  SizedBox(width: compact ? 12 : 14),
                  // Identity text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayName.isNotEmpty)
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: memberCyanHeroIdentityNameStyle(compact: compact),
                          ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: 13,
                              color: kMemberCyanHeroMetaIconColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Title: $titleLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: memberCyanHeroIdentityMetaStyle(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium_outlined,
                              size: 13,
                              color: kMemberCyanHeroMetaIconColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Skill: $competencyLevel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: memberCyanHeroIdentityMetaStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 13,
                                color: kMemberCyanHeroMetaIconColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: memberCyanHeroIdentityMetaStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Status chip + Edit button in one row
                        Row(
                          children: [
                            if (statusLabel.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isActive ? 10 : 8,
                                  vertical: isActive ? 5 : 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? kGreen
                                      : kSurface.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive ? kGreen : kYellow,
                                    width: isActive ? 0 : 1.2,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: kGreen.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.check_circle_rounded
                                          : Icons.schedule_rounded,
                                      size: isActive ? 14 : 11,
                                      color: isActive ? Colors.white : kYellow,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusLabel,
                                      style: dashText(TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : kMemberCyanHeroSubtitleColor,
                                        fontSize: isActive ? 12 : 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: isActive ? 0.2 : 0,
                                      )),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            // Edit profile button
                            Material(
                              color: kSurface.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: onEdit,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        size: compact ? 14 : 15,
                                        color: kMemberButtonPrimary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Edit Profile',
                                        style: dashText(const TextStyle(
                                          color: kTextPrimary,
                                          fontSize: 12,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.rank,
    required this.compact,
    this.imageUrl,
    this.onDarkHero = false,
  });

  final int rank;
  final bool compact;
  final String? imageUrl;
  final bool onDarkHero;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 30.0 : 34.0;
    final initials = appState.profileInitials.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: onDarkHero
                  ? Colors.white.withValues(alpha: 0.78)
                  : kAccent.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: onDarkHero
                ? kAccent.withValues(alpha: 0.35)
                : kAccent.withValues(alpha: 0.12),
            backgroundImage:
                imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null || imageUrl!.isEmpty
                ? Text(
                    initials.isNotEmpty && initials != '?' ? initials : '?',
                    style: dashText(TextStyle(
                      color: onDarkHero ? Colors.white : kAccent,
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
                border: Border.all(
                  color: onDarkHero ? kMemberCyanHeroBadgeRing : kSurface,
                  width: 1.5,
                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Performance summary — 4 compact stats + XP progress
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceSummaryCard extends StatelessWidget {
  const _PerformanceSummaryCard({required this.compact});

  final bool compact;

  static String _fmt(int v) {
    final s = v.abs().toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final snapshot = MemberCompetencySnapshot.fromAppState();
        final summary = MemberEvaluationSummaryData.fromAppState();
        final rank = appState.profileRank;
        final xp = appState.profilePoints;

        final stats = [
          (
            rank > 0 ? '#$rank' : '-',
            appState.profileRankStatLabel,
            Icons.leaderboard_outlined,
          ),
          (_fmt(xp), 'Total XP', Icons.bolt_rounded),
          ('${summary.completedCount}', 'Evaluations', Icons.fact_check_outlined),
          (
            summary.averageScorePercent != null
                ? '${summary.averageScorePercent}%'
                : '-',
            'Avg Score',
            Icons.insights_outlined,
          ),
        ];

        return Container(
          decoration: BoxDecoration(
            gradient: kMemberBrandAccentGradient,
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3300C4E8),
                blurRadius: 10,
                spreadRadius: -2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4 stat tiles
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      Expanded(
                        child: _StatTile(
                          value: stats[i].$1,
                          label: stats[i].$2,
                          icon: stats[i].$3,
                          compact: compact,
                          onBrandGradient: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // XP progress (only when not max level)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: snapshot.isMaxLevel
                    ? const _MaxLevelBadge(onBrandGradient: true)
                    : snapshot.progressUsesSkillScore
                        ? _XpProgressRow(snapshot: snapshot, onBrandGradient: true)
                        : Text(
                            snapshot.progressSubtitle,
                            textAlign: TextAlign.center,
                            style: dashText(TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            )),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.compact,
    this.onBrandGradient = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool compact;
  final bool onBrandGradient;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        onBrandGradient ? Colors.white.withValues(alpha: 0.88) : kAccent.withValues(alpha: 0.7);
    final valueColor = onBrandGradient ? Colors.white : kTextPrimary;
    final labelColor =
        onBrandGradient ? Colors.white.withValues(alpha: 0.78) : kTextSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: dashText(TextStyle(
            color: valueColor,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w800,
            height: 1,
          )),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: dashText(TextStyle(
            color: labelColor,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w500,
          )),
        ),
      ],
    );
  }
}

class _XpProgressRow extends StatelessWidget {
  const _XpProgressRow({
    required this.snapshot,
    this.onBrandGradient = false,
  });

  final MemberCompetencySnapshot snapshot;
  final bool onBrandGradient;

  @override
  Widget build(BuildContext context) {
    final trackColor =
        onBrandGradient ? Colors.white.withValues(alpha: 0.22) : kBorder;
    final subtitleColor =
        onBrandGradient ? Colors.white.withValues(alpha: 0.78) : kTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: snapshot.progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: trackColor),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: v,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: onBrandGradient
                              ? [Colors.white, Colors.white.withValues(alpha: 0.85)]
                              : [kCyan, kAccent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          snapshot.progressSubtitle,
          style: dashText(TextStyle(
            color: subtitleColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          )),
        ),
      ],
    );
  }
}

class _MaxLevelBadge extends StatelessWidget {
  const _MaxLevelBadge({this.onBrandGradient = false});

  final bool onBrandGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onBrandGradient
            ? Colors.white.withValues(alpha: 0.14)
            : kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onBrandGradient
              ? Colors.white.withValues(alpha: 0.28)
              : kAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 15,
            color: onBrandGradient ? Colors.white : kAccent,
          ),
          const SizedBox(width: 6),
          Text(
            'Highest competency level reached',
            style: dashText(TextStyle(
              color: onBrandGradient ? Colors.white : kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Achievements — badge strip with View All, no duplicate detail list
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAchievementsSection extends StatefulWidget {
  const _ProfileAchievementsSection({
    this.onViewRankings,
    this.onViewEvaluations,
  });

  final VoidCallback? onViewRankings;
  final VoidCallback? onViewEvaluations;

  @override
  State<_ProfileAchievementsSection> createState() =>
      _ProfileAchievementsSectionState();
}

class _ProfileAchievementsSectionState extends State<_ProfileAchievementsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final achievements = MemberAchievementsResolver.resolve(
          serverMilestones: memberDataController.memberMilestones,
        );

        if (achievements.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(title: 'Achievements'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.emoji_events_outlined,
                        size: 18,
                        color: kAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No badges yet',
                            style: dashText(const TextStyle(
                              color: kTextPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            )),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Complete quality evaluations to unlock milestones.',
                            style: dashText(const TextStyle(
                              color: kTextSecondary,
                              fontSize: 11,
                              height: 1.35,
                            )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Show latest 3–4 badges; expand on "View All"
        const previewCount = 4;
        final displayItems =
            _showAll ? achievements : achievements.take(previewCount).toList();
        final hasMore = achievements.length > previewCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _SectionLabel(title: 'Achievements')),
                if (hasMore)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    style: TextButton.styleFrom(
                      foregroundColor: kAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(_showAll ? 'Show less' : 'View All'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Milestone badges from your evaluation history. Official skill tier is shown above.',
              style: dashText(const TextStyle(
                color: kTextSecondary,
                fontSize: 11,
                height: 1.35,
              )),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _CompactBadgeTile(achievement: displayItems[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactBadgeTile extends StatelessWidget {
  const _CompactBadgeTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achievement.color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: achievement.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(achievement.icon, size: 18, color: achievement.color),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
            )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Requester feedback — compact, with latest preview
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileFeedbackSection extends StatelessWidget {
  const _ProfileFeedbackSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        if (!memberDataController.requestorRatingsLoaded) {
          final err = memberDataController.requestorRatingsLoadError;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(title: 'Requester Feedback'),
              const SizedBox(height: 10),
              if (err != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: kRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          err,
                          style: dashText(const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12,
                          )),
                        ),
                      ),
                      TextButton(
                        onPressed: memberDataController.refreshRequestorRatings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(
                    children: [
                      MemberProfileSkeletonBone(height: 18, width: 18, radius: 4),
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
                ),
            ],
          );
        }

        final count = memberDataController.requestorRatingCount;
        final average = memberDataController.requestorRatingAverage;
        final ratings = memberDataController.requestorRatings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(title: 'Requester Feedback'),
            const SizedBox(height: 10),
            if (count <= 0)
              // Compact empty state — single row, no large card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined, size: 18, color: kTextSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'No requester feedback yet.',
                      style: dashText(const TextStyle(
                        color: kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                  border: Border.all(color: kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Average + count row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        children: [
                          Text(
                            average != null ? average.toStringAsFixed(1) : 'N/A',
                            style: dashText(const TextStyle(
                              color: kTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            )),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (average != null)
                                _StarRow(rating: average.round().clamp(1, 5), size: 14),
                              const SizedBox(height: 2),
                              Text(
                                count == 1 ? '1 rating' : '$count ratings',
                                style: dashText(const TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                )),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Latest feedback preview (max 2)
                    if (ratings.isNotEmpty)
                      for (var i = 0; i < ratings.take(2).length; i++) ...[
                        Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: kBorder.withValues(alpha: 0.7),
                        ),
                        _FeedbackRow(row: ratings[i]),
                      ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final rating = (row['rating'] as num?)?.toInt() ?? 0;
    final eventTitle = row['event_title'] as String?;
    final comment = row['comment'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarRow(rating: rating.clamp(0, 5), size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eventTitle?.trim().isNotEmpty == true
                      ? eventTitle!.trim()
                      : 'Event',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(const TextStyle(
                    color: kTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
                ),
              ),
            ],
          ),
          if (comment != null && comment.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: dashText(const TextStyle(
                color: kTextPrimary,
                fontSize: 12,
                height: 1.4,
              )),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 16});

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
          color: i < rating ? kYellow : kTextSecondary.withValues(alpha: 0.4),
          size: size,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: dashText(const TextStyle(
        color: kTextPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      )),
    );
  }
}

// end of file
