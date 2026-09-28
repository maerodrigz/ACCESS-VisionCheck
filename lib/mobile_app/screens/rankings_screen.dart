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
          final myXp = _period == _LeaderboardPeriod.thisMonth
              ? appState.members
                  .where(_isCurrentMember)
                  .fold(0, (sum, m) => sum + m.monthlyPoints)
              : appState.profilePoints;
          final displayName = appState.profileName.trim().isNotEmpty
              ? appState.profileName.trim()
              : authController.user?.name ?? 'Member';
          final rest = sorted.length > 3 ? sorted.sublist(3) : const <Member>[];
          final monthly = _period == _LeaderboardPeriod.thisMonth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RankingsMiniHero(
                rank: myRank,
                name: displayName,
                skillLevel: snapshot.levelName,
                achievedTitle: appState.profileRole,
                profileImageUrl: appState.profileImageUrl,
                totalXp: appState.profilePoints,
                periodXp: myXp,
                periodLabel: monthly ? 'this month' : 'all time',
                progress: snapshot.progress,
                remainingXp: snapshot.remainingPoints,
                nextLevel: snapshot.nextLevelName,
                isMaxLevel: snapshot.isMaxLevel,
                memberCount: sorted.length,
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
                  if (sorted.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          mobilePagePaddingOf(context),
                          8,
                          mobilePagePaddingOf(context),
                          16,
                        ),
                        child: _RankingsPodium(
                          top3: sorted.take(3).toList(),
                          monthly: monthly,
                        ),
                      ),
                    ),
                  if (rest.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          mobilePagePaddingOf(context),
                          4,
                          mobilePagePaddingOf(context),
                          8,
                        ),
                        child: Text(
                          'Full leaderboard',
                          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
                        ),
                      ),
                    ),
                  if (rest.isNotEmpty)
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
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
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
                                    color: kBorder.withValues(alpha: 0.85),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobilePagePaddingOf(context),
                      12,
                      mobilePagePaddingOf(context),
                      12,
                    ),
                    child: _SkillProgressCard(snapshot: snapshot),
                  ),
                ),
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

class _RankingsMiniHero extends StatelessWidget {
  const _RankingsMiniHero({
    required this.rank,
    required this.name,
    required this.skillLevel,
    required this.achievedTitle,
    required this.totalXp,
    required this.periodXp,
    required this.periodLabel,
    required this.progress,
    required this.remainingXp,
    required this.nextLevel,
    required this.isMaxLevel,
    required this.memberCount,
    this.profileImageUrl,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final int rank;
  final String name;
  final String skillLevel;
  final String achievedTitle;
  final String? profileImageUrl;
  final int totalXp;
  final int periodXp;
  final String periodLabel;
  final double progress;
  final int remainingXp;
  final String? nextLevel;
  final bool isMaxLevel;
  final int memberCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  static String _formatXp(int value) {
    final s = value.abs().toString();
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
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 4, padding, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MemberDarkHeroNotificationButton(onTap: onNotificationsTap),
                  MemberDarkHeroProfileAvatar(onTap: onProfileTap),
                ],
              ),
              Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RankingsMemberAvatar(
                  name: name,
                  initials: _initialsForName(name),
                  imageUrl: profileImageUrl,
                  radius: 24,
                  backgroundColor: kAccent,
                  borderColor: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ranking',
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.2,
                        )),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        achievedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: kCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                      if (achievedTitle != skillLevel) ...[
                        const SizedBox(height: 2),
                        Text(
                          skillLevel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '#$rank',
                  style: dashText(const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_formatXp(totalXp)} total XP · ${_formatXp(periodXp)} XP $periodLabel',
              style: dashText(TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.35,
              )),
            ),
            if (memberCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$memberCount member${memberCount == 1 ? '' : 's'} on the board',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                )),
              ),
            ],
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
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (isMaxLevel)
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
                '${_formatXp(remainingXp)} XP to reach ${nextLevel ?? 'next level'}',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
              ),
          ],
        ),
      ),
      ),
    );
  }

  static String _initialsForName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

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
          color: borderColor ?? Colors.white.withValues(alpha: 0.2),
          width: 2,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Top members',
                  style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
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
          const SizedBox(height: 10),
          _LeaderboardPeriodTabs(selected: selected, onSelected: onSelected),
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
        color: kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _PeriodTab(
                label: 'This Month',
                active: selected == _LeaderboardPeriod.thisMonth,
                onTap: () => onSelected(_LeaderboardPeriod.thisMonth),
              ),
            ),
            const SizedBox(width: 4),
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? kAccent : Colors.transparent,
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

class _RankingsPodium extends StatelessWidget {
  const _RankingsPodium({
    required this.top3,
    required this.monthly,
  });

  final List<Member> top3;
  final bool monthly;

  static const _gold = Color(0xFFF59E0B);
  static const _silver = Color(0xFF94A3B8);
  static const _bronze = Color(0xFFCD7C2F);

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();

    if (top3.length == 1) {
      final m = top3.first;
      return _PodiumSlot(
        member: m,
        place: 1,
        podiumColor: _gold,
        podiumHeight: 88,
        avatarRadius: 32,
        monthly: monthly,
      );
    }

    final first = top3[0];
    final second = top3.length > 1 ? top3[1] : top3[0];
    final third = top3.length > 2 ? top3[2] : top3.last;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumSlot(
            member: second,
            place: 2,
            podiumColor: _silver,
            podiumHeight: 72,
            avatarRadius: 26,
            monthly: monthly,
          ),
        ),
        Expanded(
          child: _PodiumSlot(
            member: first,
            place: 1,
            podiumColor: _gold,
            podiumHeight: 96,
            avatarRadius: 32,
            monthly: monthly,
          ),
        ),
        Expanded(
          child: _PodiumSlot(
            member: third,
            place: 3,
            podiumColor: _bronze,
            podiumHeight: 60,
            avatarRadius: 24,
            monthly: monthly,
          ),
        ),
      ],
    );
  }
}

class _PodiumMedal extends StatelessWidget {
  const _PodiumMedal({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) {
    final color = switch (place) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF94A3B8),
      _ => const Color(0xFFCD7C2F),
    };
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Icon(Icons.emoji_events_rounded, size: 17, color: color),
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
        _PodiumMedal(place: place),
            const SizedBox(height: 6),
        _RankingsMemberAvatar(
          name: member.name,
          initials: member.initials,
          imageUrl: member.profileImageUrl,
          radius: avatarRadius,
          backgroundColor: member.avatarColor,
        ),
            const SizedBox(height: 8),
        Text(
          member.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: memberDashboardCardTitleStyle.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          member.rankingsRoleLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: memberDashboardMetaStyle.copyWith(
            color: member.achievedTitle != null ? kAccent : kTextSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$xp XP',
          style: memberDashboardMetaStyle.copyWith(
            color: kCyan,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
            const SizedBox(height: 8),
            Container(
          height: podiumHeight,
          margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$place',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

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
      padding: EdgeInsets.symmetric(
        horizontal: inGroup ? 14 : 14,
        vertical: inGroup ? 11 : 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isCurrentMember ? kAccent : kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _RankingsMemberAvatar(
            name: member.name,
            initials: member.initials,
            imageUrl: imageUrl,
            radius: 18,
            backgroundColor: member.avatarColor,
          ),
          const SizedBox(width: 12),
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
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                      ),
                    ),
                    if (isCurrentMember) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
                          color: kBlueDim,
                          borderRadius: BorderRadius.circular(999),
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
                  style: memberDashboardMetaStyle.copyWith(
                    color: member.achievedTitle != null ? kAccent : kTextSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$xp',
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                )),
              ),
              Text(
                'XP',
                style: memberDashboardMetaStyle.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );

    if (inGroup) {
      return ColoredBox(
        color: isCurrentMember ? kBlueDim.withValues(alpha: 0.35) : Colors.transparent,
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isCurrentMember ? kBlueDim.withValues(alpha: 0.5) : kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(
          color: isCurrentMember ? kAccent.withValues(alpha: 0.35) : kBorder,
        ),
      ),
      child: content,
    );
  }
}

class _SkillProgressCard extends StatelessWidget {
  const _SkillProgressCard({required this.snapshot});

  final MemberCompetencySnapshot snapshot;

  static const _trackLevels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: memberDashboardCardDecoration(),
      padding: const EdgeInsets.all(kMemberDashboardCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
    decoration: BoxDecoration(
                  color: kMemberPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kMemberPrimary.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: kMemberPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill tier track',
                      style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
                    ),
                    Text(
                      'Where ${snapshot.levelName} sits on the member path',
                      style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _trackLevels.map((label) {
              final active = _levelMatches(snapshot.levelName, label);
              return Expanded(
                child: Column(
                  children: [
      Container(
                      width: active ? 12 : 10,
                      height: active ? 12 : 10,
                      decoration: BoxDecoration(
                        color: active ? kMemberPrimary : kBorder,
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: kMemberPrimary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? kMemberPrimary : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => showMemberSkillLevelGuideSheet(context),
            style: TextButton.styleFrom(
              foregroundColor: kMemberPrimary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 16),
            label: Text(
              'How your level is calculated',
              style: memberDashboardMetaStyle.copyWith(
                color: kMemberPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _levelMatches(String current, String trackLabel) {
    final c = current.toLowerCase();
    final t = trackLabel.toLowerCase();
    if (c.contains(t)) return true;
    if (t == 'beginner' && (c.contains('novice') || c.contains('beginner'))) {
      return true;
    }
    if (t == 'advanced' && (c.contains('advanced') || c.contains('expert') || c.contains('master'))) {
      return true;
    }
    return false;
  }
}

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
      borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
    child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kMemberCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kMemberCyan.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.stars_rounded, color: kMemberCyan, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How XP Works',
                            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
                          ),
                          Text(
                            'Learn how you earn XP',
                            style: memberDashboardMetaStyle,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: kIconInactive,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, color: kBorder),
                      const SizedBox(height: 14),
                      Text(
                        MemberXpConfig.howXpIntro,
                        style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      ...MemberXpConfig.earningRules.map(
                        (rule) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6, right: 10),
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
                                      style: memberDashboardCardTitleStyle.copyWith(
                                        fontSize: 13,
                                      ),
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
                        'Skill tiers',
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MemberXpConfig.skillTiers.map((tier) {
                          final next = tier.nextMinPoints;
                          final label = next == null
                              ? '${tier.name} (${tier.minPoints}+ XP)'
                              : '${tier.name} (${tier.minPoints}–${next - 1} XP)';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kMemberDashboardAccentLight,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: kMemberDashboardAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              label,
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
                crossFadeState:
                    expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
