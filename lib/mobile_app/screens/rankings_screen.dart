import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_skill_level_guide_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';

enum _LeaderboardPeriod { thisMonth, allTime }

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, this.onNotificationsTap, this.onProfileTap});

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  _LeaderboardPeriod _period = _LeaderboardPeriod.allTime;
  bool _xpExpanded = false;

  List<Member> _sortedMembers(List<Member> source) {
    final monthly = _period == _LeaderboardPeriod.thisMonth;
    final copy = [...source]
      ..sort((a, b) {
        final xpCompare =
            b.xpForPeriod(monthly: monthly).compareTo(a.xpForPeriod(monthly: monthly));
        if (xpCompare != 0) return xpCompare;
        return a.name.compareTo(b.name);
      });
    return copy.where((m) => monthly ? m.monthlyPoints > 0 : true).toList();
  }

  bool _isCurrentMember(Member m) {
    final userId = authController.user?.id;
    if (userId != null && m.userId == userId) return true;
    final name = appState.profileName.trim();
    return name.isNotEmpty && m.name.trim() == name;
  }

  int _myRank(List<Member> sorted) {
    final i = sorted.indexWhere(_isCurrentMember);
    if (i >= 0) return i + 1;
    if (_period == _LeaderboardPeriod.allTime &&
        appState.profileRankPosition != null &&
        appState.profileRankPosition! > 0) {
      return appState.profileRankPosition!;
    }
    return sorted.length + 1;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final loading =
              memberDataController.rankingsLoading && appState.members.isEmpty;
          final error = memberDataController.rankingsError;

          if (loading) {
            return const MobileLoadingView(message: 'Loading rankings…');
          }

          if (error != null && appState.members.isEmpty) {
            return RefreshIndicator(
              color: kAccent,
              onRefresh: memberDataController.refreshRankings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.14),
                  MobileEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load rankings',
                    subtitle: error,
                    actionLabel: 'Try again',
                    onAction: memberDataController.refreshRankings,
                  ),
                ],
              ),
            );
          }

          final sorted = _sortedMembers(appState.members);
          final snapshot = MemberCompetencySnapshot.fromAppState();
          final myRank = _myRank(sorted);
          final monthly = _period == _LeaderboardPeriod.thisMonth;
          final myXp = monthly
              ? appState.members
                  .where(_isCurrentMember)
                  .fold(0, (sum, m) => sum + m.monthlyPoints)
              : appState.profilePoints;
          final displayName = appState.profileName.trim().isNotEmpty
              ? appState.profileName.trim()
              : authController.user?.name ?? 'Member';
          final rest = sorted.length > 3 ? sorted.sublist(3) : const <Member>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Light page header ──────────────────────────────────────
              _RankingsPageHeader(
                onNotificationsTap: widget.onNotificationsTap,
                onProfileTap: widget.onProfileTap,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: kAccent,
                  onRefresh: memberDataController.refreshRankings,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // ── My Ranking card ────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            mobilePagePaddingOf(context),
                            10,
                            mobilePagePaddingOf(context),
                            0,
                          ),
                          child: _MyRankingCard(
                            rank: myRank,
                            name: displayName,
                            skillLevel: snapshot.levelName,
                            achievedTitle: appState.profileRole,
                            profileImageUrl: appState.profileImageUrl,
                            totalXp: appState.profilePoints,
                            periodXp: myXp,
                            monthlyPeriod: monthly,
                            progress: snapshot.progress,
                            remainingXp: snapshot.remainingPoints,
                            nextLevel: snapshot.nextLevelName,
                            isMaxLevel: snapshot.isMaxLevel,
                            skillScore: snapshot.skillScore,
                            progressUsesSkillScore: snapshot.progressUsesSkillScore,
                          ),
                        ),
                      ),
                      // ── Period filter + section label ──────────────────
                      SliverToBoxAdapter(
                        child: _LeaderboardSectionHeader(
                          selected: _period,
                          memberCount: sorted.length,
                          onSelected: (p) => setState(() => _period = p),
                        ),
                      ),
                      if (sorted.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: MobileEmptyState(
                            icon: Icons.emoji_events_outlined,
                            title: _period == _LeaderboardPeriod.thisMonth
                                ? 'No XP earned this month yet'
                                : 'No rankings yet',
                            subtitle: _period == _LeaderboardPeriod.thisMonth
                                ? 'Upload and get evaluated to appear on the monthly board.'
                                : 'Member rankings appear after evaluations are recorded.',
                            actionLabel: 'Refresh',
                            onAction: memberDataController.refreshRankings,
                          ),
                        )
                      else ...[
                        // ── Top 3 podium ───────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              mobilePagePaddingOf(context),
                              0,
                              mobilePagePaddingOf(context),
                              12,
                            ),
                            child: _RankingsPodium(
                              top3: sorted.take(3).toList(),
                              monthly: monthly,
                            ),
                          ),
                        ),
                        // ── Full leaderboard ───────────────────────────
                        if (rest.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                mobilePagePaddingOf(context),
                                4,
                                mobilePagePaddingOf(context),
                                6,
                              ),
                              child: Text(
                                'Full leaderboard',
                                style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                mobilePagePaddingOf(context),
                                0,
                                mobilePagePaddingOf(context),
                                12,
                              ),
                              child: Container(
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
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (var i = 0; i < rest.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: kBorder.withValues(alpha: 0.7),
                                          indent: 14,
                                          endIndent: 14,
                                        ),
                                      _LeaderboardRow(
                                        rank: i + 4,
                                        member: rest[i],
                                        monthly: monthly,
                                        isCurrentMember: _isCurrentMember(rest[i]),
                                        inGroup: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      // ── Skill tier card ────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            mobilePagePaddingOf(context),
                            4,
                            mobilePagePaddingOf(context),
                            12,
                          ),
                          child: _SkillProgressCard(snapshot: snapshot),
                        ),
                      ),
                      // ── How XP works ───────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            mobilePagePaddingOf(context),
                            0,
                            mobilePagePaddingOf(context),
                            32,
                          ),
                          child: _HowXpWorksSection(
                            expanded: _xpExpanded,
                            onToggle: () => setState(() => _xpExpanded = !_xpExpanded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light page header — replaces the old dark hero
// ─────────────────────────────────────────────────────────────────────────────

class _RankingsPageHeader extends StatelessWidget {
  const _RankingsPageHeader({
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return ColoredBox(
      color: kSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, compact ? 10 : 12, padding - 4, compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Rankings',
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: compact ? 22 : 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              MemberPageNotificationButton(onTap: onNotificationsTap),
              MemberPageProfileAvatar(onTap: onProfileTap),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact "My Ranking" card — replaces the dark hero body
// ─────────────────────────────────────────────────────────────────────────────

class _MyRankingCard extends StatelessWidget {
  static const _cardBg = Color(0xFF0A1628);
  static const _onDarkPrimary = Color(0xFFF8FAFC);
  static const _onDarkSecondary = Color(0xFF94A3B8);

  const _MyRankingCard({
    required this.rank,
    required this.name,
    required this.skillLevel,
    required this.achievedTitle,
    required this.totalXp,
    required this.periodXp,
    required this.monthlyPeriod,
    required this.progress,
    required this.remainingXp,
    required this.nextLevel,
    required this.isMaxLevel,
    this.profileImageUrl,
    this.skillScore,
    this.progressUsesSkillScore = false,
  });

  final int rank;
  final String name;
  final String skillLevel;
  final String achievedTitle;
  final String? profileImageUrl;
  final int totalXp;
  final int periodXp;
  final bool monthlyPeriod;
  final double progress;
  final int remainingXp;
  final String? nextLevel;
  final bool isMaxLevel;
  final double? skillScore;
  final bool progressUsesSkillScore;

  static String _fmtXp(int v) {
    final s = v.abs().toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top row: avatar · info · rank badge ─────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              _RankingsMemberAvatar(
                name: name,
                initials: _initialsFor(name),
                imageUrl: profileImageUrl,
                radius: compact ? 22 : 24,
                backgroundColor: kAccent,
                borderColor: kAccent.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 12),
              // Name / title / competency
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _onDarkPrimary,
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skillLevel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kCyan,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (achievedTitle.trim().isNotEmpty &&
                        achievedTitle.trim().toLowerCase() != skillLevel.trim().toLowerCase()) ...[
                      const SizedBox(height: 1),
                      Text(
                        achievedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _onDarkSecondary,
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Rank badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '#$rank',
                    style: TextStyle(
                      color: _onDarkPrimary,
                      fontSize: compact ? 24 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  Text(
                    'rank',
                    style: TextStyle(
                      color: _onDarkSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _XpPill(
                  icon: monthlyPeriod ? Icons.calendar_today_rounded : Icons.bolt_rounded,
                  label: monthlyPeriod
                      ? '${_fmtXp(periodXp)} XP this month'
                      : '${_fmtXp(totalXp)} XP all time',
                  color: monthlyPeriod ? kCyan : _onDarkPrimary,
                  bgColor: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              if (!monthlyPeriod && periodXp > 0 && periodXp != totalXp) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _XpPill(
                    icon: Icons.calendar_today_rounded,
                    label: '${_fmtXp(periodXp)} XP this month',
                    color: kCyan,
                    bgColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ] else if (monthlyPeriod && totalXp != periodXp) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _XpPill(
                    icon: Icons.bolt_rounded,
                    label: '${_fmtXp(totalXp)} XP all time',
                    color: _onDarkPrimary,
                    bgColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ],
          ),
          if (progressUsesSkillScore) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.white.withValues(alpha: 0.22)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kCyan, Color(0xFF0052D4)],
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
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final subtitle = MemberCompetencySnapshot.fromAppState().progressSubtitle;
                return Text(
                  subtitle,
                  style: TextStyle(
                    color: isMaxLevel ? kCyan : _onDarkSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _XpPill extends StatelessWidget {
  const _XpPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared avatar widget
// ─────────────────────────────────────────────────────────────────────────────

class _RankingsMemberAvatar extends StatelessWidget {
  const _RankingsMemberAvatar({
    required this.name,
    required this.initials,
    required this.radius,
    required this.backgroundColor,
    this.imageUrl,
    this.borderColor,
  });

  final String name;
  final String initials;
  final double radius;
  final Color backgroundColor;
  final String? imageUrl;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? kBorder,
          width: 1.5,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
        child: hasImage
            ? null
            : Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.46,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period filter + section header
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardSectionHeader extends StatelessWidget {
  const _LeaderboardSectionHeader({
    required this.selected,
    required this.memberCount,
    required this.onSelected,
  });

  final _LeaderboardPeriod selected;
  final int memberCount;
  final ValueChanged<_LeaderboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented period filter
          _LeaderboardPeriodTabs(selected: selected, onSelected: onSelected),
          const SizedBox(height: 12),
          // "Top members" label + count
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Top members',
                  style: memberDashboardSectionTitleStyle.copyWith(fontSize: compact ? 15 : 16),
                ),
              ),
              Text(
                memberCount == 0
                    ? 'No entries'
                    : '$memberCount member${memberCount == 1 ? '' : 's'}',
                style: memberDashboardMetaStyle.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPeriodTabs extends StatelessWidget {
  const _LeaderboardPeriodTabs({
    required this.selected,
    required this.onSelected,
  });

  final _LeaderboardPeriod selected;
  final ValueChanged<_LeaderboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _PeriodTab(
                label: 'This Month',
                active: selected == _LeaderboardPeriod.thisMonth,
                onTap: () => onSelected(_LeaderboardPeriod.thisMonth),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _PeriodTab(
                label: 'All Time',
                active: selected == _LeaderboardPeriod.allTime,
                onTap: () => onSelected(_LeaderboardPeriod.allTime),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? kAccent : Colors.transparent,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : kTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Top 3 podium
// ─────────────────────────────────────────────────────────────────────────────

class _RankingsPodium extends StatelessWidget {
  const _RankingsPodium({required this.top3, required this.monthly});

  final List<Member> top3;
  final bool monthly;

  static const _gold = Color(0xFFF59E0B);
  static const _silver = Color(0xFF94A3B8);
  static const _bronze = Color(0xFFCD7C2F);

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();

    if (top3.length == 1) {
      return _PodiumSlot(
        member: top3.first,
        place: 1,
        podiumColor: _gold,
        podiumHeight: 44,
        avatarRadius: 26,
        monthly: monthly,
      );
    }

    final first = top3[0];
    final second = top3.length > 1 ? top3[1] : top3[0];
    final third = top3.length > 2 ? top3[2] : top3.last;

    return Container(
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
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 — left
          Expanded(
            child: _PodiumSlot(
              member: second,
              place: 2,
              podiumColor: _silver,
              podiumHeight: 34,
              avatarRadius: 22,
              monthly: monthly,
            ),
          ),
          // #1 — center, raised
          Expanded(
            child: _PodiumSlot(
              member: first,
              place: 1,
              podiumColor: _gold,
              podiumHeight: 48,
              avatarRadius: 28,
              monthly: monthly,
            ),
          ),
          // #3 — right
          Expanded(
            child: _PodiumSlot(
              member: third,
              place: 3,
              podiumColor: _bronze,
              podiumHeight: 26,
              avatarRadius: 20,
              monthly: monthly,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.member,
    required this.place,
    required this.podiumColor,
    required this.podiumHeight,
    required this.avatarRadius,
    required this.monthly,
  });

  final Member member;
  final int place;
  final Color podiumColor;
  final double podiumHeight;
  final double avatarRadius;
  final bool monthly;

  @override
  Widget build(BuildContext context) {
    final xp = member.xpForPeriod(monthly: monthly);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal icon
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: podiumColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: podiumColor.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.emoji_events_rounded, size: 13, color: podiumColor),
        ),
        const SizedBox(height: 6),
        // Avatar
        _RankingsMemberAvatar(
          name: member.name,
          initials: member.initials,
          imageUrl: member.profileImageUrl,
          radius: avatarRadius,
          backgroundColor: member.avatarColor,
          borderColor: podiumColor.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 6),
        // Name
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
          )),
        ),
        const SizedBox(height: 2),
        // Role
        Text(
          member.rankingsRoleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: dashText(TextStyle(
            color: member.achievedTitle != null ? kAccent : kTextSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
          )),
        ),
        const SizedBox(height: 4),
        // XP
        Text(
          monthly ? '$xp XP (month)' : '$xp XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: dashText(TextStyle(
            color: podiumColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1.2,
          )),
        ),
        const SizedBox(height: 6),
        // Podium block
        Container(
          height: podiumHeight,
          decoration: BoxDecoration(
            color: podiumColor.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: podiumColor.withValues(alpha: 0.35)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$place',
            style: TextStyle(
              color: podiumColor.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full leaderboard row
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.member,
    required this.monthly,
    required this.isCurrentMember,
    this.inGroup = false,
  });

  final int rank;
  final Member member;
  final bool monthly;
  final bool isCurrentMember;
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final xp = member.xpForPeriod(monthly: monthly);
    final imageUrl = (member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty)
        ? member.profileImageUrl
        : (isCurrentMember ? appState.profileImageUrl : null);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isCurrentMember ? kAccent : kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Avatar
          _RankingsMemberAvatar(
            name: member.name,
            initials: member.initials,
            imageUrl: imageUrl,
            radius: 16,
            backgroundColor: member.avatarColor,
            borderColor: isCurrentMember ? kAccent.withValues(alpha: 0.35) : kBorder,
          ),
          const SizedBox(width: 10),
          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(const TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        )),
                      ),
                    ),
                    if (isCurrentMember) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'You',
                          style: dashText(const TextStyle(
                            color: kAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.rankingsRoleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: member.achievedTitle != null ? kAccent : kTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  )),
                ),
              ],
            ),
          ),
          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$xp',
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1,
                )),
              ),
              Text(
                monthly ? 'XP (month)' : 'XP (all time)',
                style: dashText(const TextStyle(
                  color: kTextSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                )),
              ),
            ],
          ),
        ],
      ),
    );

    if (inGroup) {
      return ColoredBox(
        color: isCurrentMember ? kAccent.withValues(alpha: 0.04) : Colors.transparent,
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isCurrentMember ? kAccent.withValues(alpha: 0.05) : kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(
          color: isCurrentMember ? kAccent.withValues(alpha: 0.3) : kBorder,
        ),
      ),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skill tier progress card (unchanged logic, kept as-is)
// ─────────────────────────────────────────────────────────────────────────────

class _SkillProgressCard extends StatelessWidget {
  const _SkillProgressCard({required this.snapshot});

  final MemberCompetencySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final track = snapshot.skillTrackStates;

    return Container(
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
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAccent.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: kAccent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill tier track',
                      style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
                    ),
                    Text(
                      'Current: ${snapshot.levelName}'
                      '${snapshot.skillScore != null ? ' · ${snapshot.skillScore!.round()} score' : ''}',
                      style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: track
                .map(
                  (step) => Expanded(
                    child: _SkillTrackNode(
                      label: step.name,
                      state: step.state,
                      compact: compact,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => showMemberSkillLevelGuideSheet(context),
            style: TextButton.styleFrom(
              foregroundColor: kAccent,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 15),
            label: Text(
              'How your level is calculated',
              style: memberDashboardMetaStyle.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillTrackNode extends StatelessWidget {
  const _SkillTrackNode({
    required this.label,
    required this.state,
    required this.compact,
  });

  final String label;
  final SkillTierTrackState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == SkillTierTrackState.current;
    final isCompleted = state == SkillTierTrackState.completed;
    final dotColor = isCurrent
        ? kAccent
        : isCompleted
            ? kAccent.withValues(alpha: 0.55)
            : kBorder;

    return Column(
      children: [
        Container(
          width: isCurrent ? 12 : 10,
          height: isCurrent ? 12 : 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: kAccent.withValues(alpha: 0.35), width: 2) : null,
            boxShadow: isCurrent
                ? [BoxShadow(color: kAccent.withValues(alpha: 0.22), blurRadius: 4)]
                : null,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: memberDashboardMetaStyle.copyWith(
            fontSize: compact ? 9 : 10,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? kAccent : kTextSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How XP works (expandable, unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

class _HowXpWorksSection extends StatelessWidget {
  const _HowXpWorksSection({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Container(
          decoration: BoxDecoration(
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
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kCyan.withValues(alpha: 0.22)),
                      ),
                      child: const Icon(Icons.stars_rounded, color: kCyan, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How XP Works',
                            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 14),
                          ),
                          Text(
                            expanded
                                ? 'Rules for practice evaluations and skill tiers'
                                : MemberXpConfig.collapsedXpHint,
                            style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: kIconInactive),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, color: kBorder),
                      const SizedBox(height: 12),
                      Text(
                        MemberXpConfig.howXpIntro,
                        style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ...MemberXpConfig.earningRules.map(
                        (rule) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 7, right: 9),
                                decoration: const BoxDecoration(
                                  color: kAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rule.title,
                                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rule.body,
                                      style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        'Skill tier score bands',
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        MemberXpConfig.skillLevelIntro,
                        style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: MemberXpConfig.skillLevelTiers.map((tier) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: kCyanDim,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: kCyan.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '${tier.name} (${tier.range})',
                              style: dashText(const TextStyle(
                                color: kAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 260),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
