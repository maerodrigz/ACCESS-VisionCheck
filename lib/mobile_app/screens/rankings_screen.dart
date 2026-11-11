import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';

const _kRankingsNavy = Color(0xFF103E56);
const _kRankingsCardRadius = 18.0;

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
        final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameCompare != 0) return nameCompare;
        return (a.userId ?? 0).compareTo(b.userId ?? 0);
      });
    return copy.where((m) => monthly ? m.monthlyPoints > 0 : true).toList();
  }

  bool _isCurrentMember(Member m) {
    final userId = authController.user?.id;
    if (userId != null && m.userId == userId) return true;
    final name = appState.profileName.trim();
    return name.isNotEmpty && m.name.trim() == name;
  }

  /// XP leaderboard position for the selected period, or null when unranked.
  ///
  /// Always derived from the same sorted list as Top Members / Full Leaderboard.
  /// This Month with 0 awarded XP stays Unranked (excluded from the board).
  int? _myLeaderboardRank(List<Member> sorted) {
    final i = sorted.indexWhere(_isCurrentMember);
    if (i >= 0) return i + 1;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
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
          final myRank = _myLeaderboardRank(sorted);
          final monthly = _period == _LeaderboardPeriod.thisMonth;
          // Prefer the same member row used for podium/list so XP matches the board.
          Member? meOnBoard;
          for (final m in appState.members) {
            if (_isCurrentMember(m)) {
              meOnBoard = m;
              break;
            }
          }
          final myXp = meOnBoard != null
              ? meOnBoard.xpForPeriod(monthly: monthly)
              : (monthly ? 0 : appState.profilePoints);
          final displayName = appState.profileName.trim().isNotEmpty
              ? appState.profileName.trim()
              : authController.user?.name ?? 'Member';
          final rest = sorted.length > 3 ? sorted.sublist(3) : const <Member>[];
          final pagePad = mobilePagePaddingOf(context);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RequestorBrandAppBar(
                onNotifications: widget.onNotificationsTap,
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
                        child: _RankingsHeroHeader(padding: pagePad),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 0),
                          child: _MyRankingCard(
                            rank: myRank,
                            name: displayName,
                            skillLevel: snapshot.levelName,
                            profileImageUrl: appState.profileImageUrl,
                            periodXp: myXp,
                            monthlyPeriod: monthly,
                            progress: snapshot.progress,
                            remainingPoints: snapshot.remainingPoints,
                            nextLevel: snapshot.nextLevelName,
                            isMaxLevel: snapshot.isMaxLevel,
                            progressUsesSkillScore: snapshot.progressUsesSkillScore,
                            progressSubtitle: snapshot.progressSubtitle,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _LeaderboardSectionHeader(
                          selected: _period,
                          onSelected: (p) => setState(() => _period = p),
                        ),
                      ),
                      if (sorted.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 8),
                            child: _RankingsEmptyBoardCard(
                              monthly: monthly,
                              onRetry: memberDataController.refreshRankings,
                            ),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 6),
                            child: _RankingsPodium(
                              top3: sorted.take(3).toList(),
                              memberCount: sorted.length,
                              monthly: monthly,
                            ),
                          ),
                        ),
                        if (rest.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 6),
                              child: _FullLeaderboardCard(
                                members: rest,
                                startRank: 4,
                                monthly: monthly,
                                isCurrentMember: _isCurrentMember,
                              ),
                            ),
                          ),
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 8),
                          child: _SkillTierProgressCard(snapshot: snapshot),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pagePad, 0, pagePad, 20),
                          child: _HowRankingsWorkCard(
                            policyVersion:
                                appState.profileSkillProgressionPolicyVersion,
                            expanded: _xpExpanded,
                            onToggle: () =>
                                setState(() => _xpExpanded = !_xpExpanded),
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
// Rankings hero (title + subtitle + golden trophy illustration)
// ─────────────────────────────────────────────────────────────────────────────

class _RankingsHeroHeader extends StatelessWidget {
  const _RankingsHeroHeader({required this.padding});

  final double padding;

  static const _trophyAsset = 'assets/images/rankings/rankings_trophy.png';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final narrow = constraints.maxWidth < 340;
        // Compact illustration; scale with available width without crowding title.
        final trophyW = narrow
            ? 104.0
            : (compact ? 112.0 : (constraints.maxWidth * 0.28).clamp(112.0, 126.0));

        return Padding(
          padding: EdgeInsets.fromLTRB(
            padding,
            compact ? 2 : 3,
            padding,
            compact ? 4 : 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: compact ? 20 : 22,
                          color: kCyan,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Rankings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _kRankingsNavy,
                              fontSize: compact ? 24 : 26,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 5),
                    Text(
                      'See top documenters, your rank, and skill progress.',
                      softWrap: true,
                      style: TextStyle(
                        color: _kRankingsNavy.withValues(alpha: 0.78),
                        fontSize: compact ? 12.5 : 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              // Golden trophy sits on the sky-blue wave background (no card).
              SizedBox(
                width: trophyW,
                child: Image.asset(
                  _trophyAsset,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: 'Rankings trophy',
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
// Compact "My Rank" card — white / cyan-border premium card
// ─────────────────────────────────────────────────────────────────────────────

class _MyRankingCard extends StatelessWidget {
  const _MyRankingCard({
    required this.rank,
    required this.name,
    required this.skillLevel,
    required this.periodXp,
    required this.monthlyPeriod,
    required this.progress,
    required this.remainingPoints,
    required this.nextLevel,
    required this.isMaxLevel,
    required this.progressSubtitle,
    this.profileImageUrl,
    this.progressUsesSkillScore = false,
  });

  /// Null when the member has no valid leaderboard position for this period.
  final int? rank;
  final String name;
  final String skillLevel;
  final String? profileImageUrl;
  final int periodXp;
  final bool monthlyPeriod;
  final double progress;
  final int remainingPoints;
  final String? nextLevel;
  final bool isMaxLevel;
  final bool progressUsesSkillScore;
  final String progressSubtitle;

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
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get _compactProgressLine {
    if (isMaxLevel) return 'Maximum skill tier reached.';
    if (!progressUsesSkillScore) return progressSubtitle;
    if (nextLevel != null && remainingPoints > 0) {
      return '$remainingPoints quality points to reach $nextLevel.';
    }
    return progressSubtitle;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = rank != null && rank! > 0;
    final periodLabel = monthlyPeriod ? 'This Month' : 'All Time';
    final xpLabel = '${_fmtXp(periodXp)} XP ($periodLabel)';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final narrow = cardW < 340;
        final compact = cardW < 360;
        final avatarR = narrow ? 20.0 : (compact ? 22.0 : 24.0);
        final gapAvatar = narrow ? 8.0 : (compact ? 9.0 : 10.0);
        final gapBadge = narrow ? 6.0 : 8.0;
        final pad = compact ? 11.0 : 13.0;
        final xpSize = narrow ? 11.0 : (compact ? 11.5 : 12.0);

        return Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(_kRankingsCardRadius),
            border: Border.all(color: kCyan.withValues(alpha: 0.55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _RankingsMemberAvatar(
                    name: name,
                    initials: _initialsFor(name),
                    imageUrl: profileImageUrl,
                    radius: avatarR,
                    backgroundColor: kAccent,
                    borderColor: kCyan.withValues(alpha: 0.45),
                  ),
                  SizedBox(width: gapAvatar),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _kRankingsNavy,
                            fontSize: compact ? 14.5 : 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kCyanDim,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: kCyan.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            skillLevel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kAccent,
                              fontSize: compact ? 11 : 11.5,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                monthlyPeriod
                                    ? Icons.calendar_today_rounded
                                    : Icons.bolt_rounded,
                                size: 13,
                                color: _kRankingsNavy,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                xpLabel,
                                softWrap: true,
                                maxLines: 2,
                                style: TextStyle(
                                  color: _kRankingsNavy.withValues(alpha: 0.85),
                                  fontSize: xpSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: gapBadge),
                  _LeaderboardRankPanel(
                    rank: ranked ? rank : null,
                    compact: compact,
                    narrow: narrow,
                  ),
                ],
              ),
              if (progressUsesSkillScore) ...[
                SizedBox(height: compact ? 12 : 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFFE8EEF5)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: const ColoredBox(color: kAccent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isMaxLevel
                          ? Icons.check_circle_rounded
                          : Icons.arrow_upward_rounded,
                      size: 14,
                      color: isMaxLevel ? kAccent : kGreen,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _compactProgressLine,
                        style: TextStyle(
                          color: _kRankingsNavy.withValues(alpha: 0.82),
                          fontSize: compact ? 11.5 : 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Compact leaderboard rank badge (My Rank card).
///
/// Decorative capsule + laurels come from
/// [assets/images/rankings/rankings_rank_badge.png] (text-free).
/// Rank number and caption are always live Flutter [Text] overlays.
class _LeaderboardRankPanel extends StatelessWidget {
  const _LeaderboardRankPanel({
    required this.rank,
    required this.compact,
    this.narrow = false,
  });

  final int? rank;
  final bool compact;
  final bool narrow;

  static const _assetPath = 'assets/images/rankings/rankings_rank_badge.png';
  static const _rankBlue = Color(0xFF1E7FE0);

  @override
  Widget build(BuildContext context) {
    final ranked = rank != null && rank! > 0;
    final rankText = ranked ? '#$rank' : '-';
    final caption = ranked ? 'Leaderboard Rank' : 'Unranked';
    final digits = ranked ? rank!.toString().length : 1;

    // Compact badge so the member XP column keeps enough width.
    // Box is slightly taller than the asset aspect so text fits; BoxFit.cover
    // crops the wide capsule edges a little without stretching the art.
    final width = narrow ? 92.0 : (compact ? 98.0 : 104.0);
    final height = narrow ? 50.0 : (compact ? 54.0 : 56.0);
    final rankSize = narrow
        ? (digits >= 3 ? 14.0 : (digits == 2 ? 16.0 : 17.5))
        : compact
            ? (digits >= 3 ? 14.5 : (digits == 2 ? 16.5 : 18.5))
            : (digits >= 3 ? 15.5 : (digits == 2 ? 17.5 : 19.5));
    final captionSize = narrow ? 6.0 : (compact ? 6.5 : 7.0);
    // Rounded rectangle (not pill) to match the approved badge silhouette.
    final radius = BorderRadius.circular(narrow ? 14.0 : 16.0);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF103E56).withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
              // Live rank + caption centered between the image laurels.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  width * 0.20,
                  height * 0.12,
                  width * 0.20,
                  height * 0.10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rankText,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ranked
                            ? _rankBlue
                            : _kRankingsNavy.withValues(alpha: 0.55),
                        fontSize: rankSize,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      caption,
                      maxLines: 2,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kRankingsNavy.withValues(
                          alpha: ranked ? 0.80 : 0.62,
                        ),
                        fontSize: captionSize,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared avatar widget (initials fallback on missing / failed image)
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

  Widget _initialsGlyph() {
    return Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.46,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final hasImage = url.isNotEmpty;
    final size = radius * 2;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? kBorder,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ColoredBox(
            color: backgroundColor,
            child: hasImage
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, __, ___) => Center(child: _initialsGlyph()),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(child: _initialsGlyph());
                    },
                  )
                : Center(child: _initialsGlyph()),
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
    required this.onSelected,
  });

  final _LeaderboardPeriod selected;
  final ValueChanged<_LeaderboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 6, padding, compact ? 6 : 8),
      child: _LeaderboardPeriodTabs(selected: selected, onSelected: onSelected),
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
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(999),
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
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? kAccent : Colors.transparent,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _kRankingsNavy.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact empty board (no eligible ranked members for period)
// ─────────────────────────────────────────────────────────────────────────────

class _RankingsEmptyBoardCard extends StatelessWidget {
  const _RankingsEmptyBoardCard({
    required this.monthly,
    required this.onRetry,
  });

  final bool monthly;
  final VoidCallback onRetry;

  static const _cardBorder = Color(0xFFD7E3EF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kRankingsCardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF103E56).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 28,
            color: kCyan.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 10),
          Text(
            monthly ? 'No XP earned this month yet' : 'No rankings yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kRankingsNavy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            monthly
                ? 'Upload and get evaluated to appear on the monthly board.'
                : 'Member rankings appear after evaluations are recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kRankingsNavy.withValues(alpha: 0.65),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: kAccent,
              minimumSize: const Size(0, kMobileMinTouch),
            ),
            child: const Text(
              'Refresh',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Top 3 podium (Top Members card) — PNG platform + live members
// ─────────────────────────────────────────────────────────────────────────────

class _RankingsPodium extends StatelessWidget {
  const _RankingsPodium({
    required this.top3,
    required this.memberCount,
    required this.monthly,
  });

  final List<Member> top3;
  final int memberCount;
  final bool monthly;

  static const _podiumAsset = 'assets/images/rankings/rankings_podium.png';
  static const _podiumAspect = 2172 / 724;
  // Opaque platform band inside the PNG (measured; large transparent pads above/below).
  static const _podiumContentTop = 172 / 724;
  static const _podiumContentBottom = 532 / 724;
  static const _gold = Color(0xFFE6A700);
  static const _silver = Color(0xFF8FA0B3);
  static const _bronze = Color(0xFFC67A3A);
  static const _cardBorder = Color(0xFFD7E3EF);

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

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();
    final compact = MediaQuery.sizeOf(context).width < 360;

    final first = top3[0];
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kRankingsCardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF103E56).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 0 : 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Top Members',
                  style: TextStyle(
                    color: _kRankingsNavy,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              Text(
                '$memberCount member${memberCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : _PodiumMemberColumn(
                        member: second,
                        accent: _silver,
                        avatarRadius: compact ? 20 : 22,
                        monthly: monthly,
                        fmtXp: _fmtXp,
                      ),
              ),
              Expanded(
                // Raise #1 so XP clears the taller gold platform top.
                child: Transform.translate(
                  offset: Offset(0, compact ? -10 : -12),
                  child: _PodiumMemberColumn(
                    member: first,
                    accent: _gold,
                    avatarRadius: compact ? 26 : 28,
                    monthly: monthly,
                    fmtXp: _fmtXp,
                    prominent: true,
                  ),
                ),
              ),
              Expanded(
                child: third == null
                    ? const SizedBox.shrink()
                    : _PodiumMemberColumn(
                        member: third,
                        accent: _bronze,
                        avatarRadius: compact ? 18 : 20,
                        monthly: monthly,
                        fmtXp: _fmtXp,
                      ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          // Full-width PNG (exact aspect box) so platforms align with member
          // columns. Layout height uses only the opaque platform band, lifted
          // toward XP; transparent pads are not given empty card space.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final podiumH = width / _podiumAspect;
              final contentTopPx = podiumH * _podiumContentTop;
              final contentBottomPx = podiumH * _podiumContentBottom;
              final contentH = contentBottomPx - contentTopPx;
              // Minimal lift — gap above keeps XP (esp. #1) fully readable.
              final lift = (compact ? 2.0 : 4.0).clamp(0.0, contentH * 0.08);
              final layoutH = (contentH - lift).clamp(contentH * 0.88, contentH);

              return SizedBox(
                height: layoutH,
                width: width,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      width: width,
                      // Keep intrinsic PNG size so BoxFit does not letterbox.
                      height: podiumH,
                      // Shift up: hide transparent top pad + close XP gap.
                      top: -(contentTopPx + lift),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            _podiumAsset,
                            width: width,
                            height: podiumH,
                            fit: BoxFit.fill,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.medium,
                            excludeFromSemantics: true,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _PodiumRankLabel(
                                  place: second == null ? null : 2,
                                  color: _silver,
                                  alignment: const Alignment(0, 0.18),
                                  fontSize: compact ? 15 : 16,
                                ),
                              ),
                              Expanded(
                                child: _PodiumRankLabel(
                                  place: 1,
                                  color: _gold,
                                  alignment: const Alignment(0, 0.08),
                                  fontSize: compact ? 17 : 18,
                                ),
                              ),
                              Expanded(
                                child: _PodiumRankLabel(
                                  place: third == null ? null : 3,
                                  color: _bronze,
                                  alignment: const Alignment(0, 0.22),
                                  fontSize: compact ? 14 : 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PodiumRankLabel extends StatelessWidget {
  const _PodiumRankLabel({
    required this.place,
    required this.color,
    required this.alignment,
    required this.fontSize,
  });

  final int? place;
  final Color color;
  final Alignment alignment;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (place == null) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Text(
        '#$place',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.withValues(alpha: 0.92),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.55),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name + role + XP above a podium column (no drawn platform).
class _PodiumMemberColumn extends StatelessWidget {
  const _PodiumMemberColumn({
    required this.member,
    required this.accent,
    required this.avatarRadius,
    required this.monthly,
    required this.fmtXp,
    this.prominent = false,
  });

  final Member member;
  final Color accent;
  final double avatarRadius;
  final bool monthly;
  final String Function(int) fmtXp;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final xp = member.xpForPeriod(monthly: monthly);
    final medalIcon =
        prominent ? Icons.workspace_premium_rounded : Icons.emoji_events_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: prominent ? 24 : 20,
          height: prominent ? 24 : 20,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Icon(medalIcon, size: prominent ? 14 : 11, color: accent),
        ),
        const SizedBox(height: 3),
        _RankingsMemberAvatar(
          name: member.name,
          initials: member.initials,
          imageUrl: member.profileImageUrl,
          radius: avatarRadius,
          backgroundColor: member.avatarColor,
          borderColor: accent.withValues(alpha: 0.55),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kRankingsNavy,
              fontSize: prominent ? 12 : 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            member.skillTierLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kAccent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '${fmtXp(xp)} XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full leaderboard card (ranks after podium)
// ─────────────────────────────────────────────────────────────────────────────

class _FullLeaderboardCard extends StatelessWidget {
  const _FullLeaderboardCard({
    required this.members,
    required this.startRank,
    required this.monthly,
    required this.isCurrentMember,
  });

  final List<Member> members;
  final int startRank;
  final bool monthly;
  final bool Function(Member) isCurrentMember;

  static const _cardBorder = Color(0xFFD7E3EF);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kRankingsCardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF103E56).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 14,
              compact ? 12 : 14,
              compact ? 12 : 14,
              8,
            ),
            child: Text(
              'Leaderboard',
              style: TextStyle(
                color: _kRankingsNavy,
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: kBorder.withValues(alpha: 0.7),
                indent: 14,
                endIndent: 14,
              ),
            _LeaderboardRow(
              rank: startRank + i,
              member: members[i],
              monthly: monthly,
              isCurrentMember: isCurrentMember(members[i]),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.member,
    required this.monthly,
    required this.isCurrentMember,
  });

  final int rank;
  final Member member;
  final bool monthly;
  final bool isCurrentMember;

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

  @override
  Widget build(BuildContext context) {
    final xp = member.xpForPeriod(monthly: monthly);
    final imageUrl =
        (member.profileImageUrl != null && member.profileImageUrl!.trim().isNotEmpty)
            ? member.profileImageUrl
            : (isCurrentMember ? appState.profileImageUrl : null);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return ColoredBox(
      color: isCurrentMember ? kAccent.withValues(alpha: 0.04) : Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 9 : 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: isCurrentMember ? kAccent : _kRankingsNavy.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _RankingsMemberAvatar(
              name: member.name,
              initials: member.initials,
              imageUrl: imageUrl,
              radius: compact ? 15 : 16,
              backgroundColor: member.avatarColor,
              borderColor: isCurrentMember
                  ? kAccent.withValues(alpha: 0.35)
                  : const Color(0xFFD7E3EF),
            ),
            SizedBox(width: compact ? 8 : 10),
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
                          style: TextStyle(
                            color: _kRankingsNavy,
                            fontSize: compact ? 12.5 : 13,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
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
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: kAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.skillTierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtXp(xp),
                  style: TextStyle(
                    color: _kRankingsNavy,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  'XP',
                  style: TextStyle(
                    color: _kRankingsNavy.withValues(alpha: 0.5),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skill Tier Progress (track only — rules live in How Rankings Work)
// ─────────────────────────────────────────────────────────────────────────────

class _SkillTierProgressCard extends StatelessWidget {
  const _SkillTierProgressCard({required this.snapshot});

  final MemberCompetencySnapshot snapshot;

  static const _cardBorder = Color(0xFFD7E3EF);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final track = snapshot.skillTrackStates;
    final milestone =
        MemberProfileSkillProgressSection.friendlyMotivationLine(snapshot);

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kRankingsCardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF103E56).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCyan.withValues(alpha: 0.28)),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: kCyan,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill Tier Progress',
                      style: TextStyle(
                        color: _kRankingsNavy,
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current tier: ${snapshot.levelName}',
                      style: TextStyle(
                        color: _kRankingsNavy.withValues(alpha: 0.68),
                        fontSize: compact ? 11.5 : 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          Row(
            children: [
              for (var i = 0; i < track.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: track[i - 1].state == SkillTierTrackState.upcoming
                          ? const Color(0xFFE2E8F0)
                          : kCyan.withValues(alpha: 0.55),
                    ),
                  ),
                _SkillTrackNode(
                  label: track[i].name,
                  state: track[i].state,
                  compact: compact || textScale > 1.15,
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                snapshot.isMaxLevel
                    ? Icons.check_circle_rounded
                    : Icons.trending_up_rounded,
                size: 16,
                color: snapshot.isMaxLevel ? kAccent : kCyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  milestone,
                  style: TextStyle(
                    color: _kRankingsNavy.withValues(alpha: 0.82),
                    fontSize: compact ? 12 : 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How Rankings Work (compact explanation + expandable details)
// ─────────────────────────────────────────────────────────────────────────────

class _HowRankingsWorkCard extends StatelessWidget {
  const _HowRankingsWorkCard({
    required this.policyVersion,
    required this.expanded,
    required this.onToggle,
  });

  final String policyVersion;
  final bool expanded;
  final VoidCallback onToggle;

  static const _cardBorder = Color(0xFFD7E3EF);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final tileGap = compact ? 8.0 : 10.0;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kRankingsCardRadius),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF103E56).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 8 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: kCyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Rankings Work',
                      style: TextStyle(
                        color: _kRankingsNavy,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MemberXpConfig.howRankingsSummary,
                      style: TextStyle(
                        color: _kRankingsNavy.withValues(alpha: 0.78),
                        fontSize: compact ? 11.5 : 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HowRankingsInfoTile(
                  title: 'XP Rank',
                  body: MemberXpConfig.howRankingsXpTile,
                  compact: compact,
                ),
              ),
              SizedBox(width: tileGap),
              Expanded(
                child: _HowRankingsInfoTile(
                  title: 'Skill Tier',
                  body: MemberXpConfig.howRankingsSkillTile,
                  compact: compact,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMobileMinTouch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          expanded ? 'Hide detailed rules' : 'View detailed rules',
                          style: TextStyle(
                            color: kAccent,
                            fontSize: compact ? 12.5 : 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: kAccent.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _HowRankingsDetailsBody(
              compact: compact,
              policyVersion: policyVersion,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _HowRankingsInfoTile extends StatelessWidget {
  const _HowRankingsInfoTile({
    required this.title,
    required this.body,
    required this.compact,
  });

  final String title;
  final String body;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 11,
        compact ? 10 : 12,
        compact ? 10 : 11,
      ),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _kRankingsNavy,
              fontSize: compact ? 12 : 12.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: _kRankingsNavy.withValues(alpha: 0.72),
              fontSize: compact ? 11 : 11.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
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
    final size = isCurrent ? 22.0 : 18.0;

    late final Widget indicator;
    if (isCompleted) {
      indicator = Icon(Icons.check_circle_rounded, size: size, color: kCyan);
    } else if (isCurrent) {
      indicator = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kAccent.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.circle, size: 8, color: Colors.white),
      );
    } else {
      indicator = Container(
        width: size - 2,
        height: size - 2,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
      );
    }

    return SizedBox(
      width: compact ? 58 : 66,
      child: Column(
        children: [
          SizedBox(height: size, width: size, child: Center(child: indicator)),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent
                  ? kAccent
                  : isCompleted
                      ? _kRankingsNavy
                      : _kRankingsNavy.withValues(alpha: 0.45),
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowRankingsDetailsBody extends StatelessWidget {
  const _HowRankingsDetailsBody({
    required this.compact,
    required this.policyVersion,
  });

  final bool compact;
  final String policyVersion;

  @override
  Widget build(BuildContext context) {
    final rules = MemberXpConfig.howRankingsDetailedRules(policyVersion);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 9),
                    decoration: const BoxDecoration(
                      color: kCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.title,
                          style: TextStyle(
                            color: _kRankingsNavy,
                            fontSize: compact ? 12 : 12.5,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rule.body,
                          style: TextStyle(
                            color: _kRankingsNavy.withValues(alpha: 0.78),
                            fontSize: compact ? 11.5 : 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
