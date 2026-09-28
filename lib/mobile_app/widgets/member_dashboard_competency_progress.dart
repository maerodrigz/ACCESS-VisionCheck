import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';
import 'package:access_mobile/mobile_app/widgets/member_skill_level_guide_sheet.dart';

class MemberCompetencyTier {
  const MemberCompetencyTier(this.name, this.minPoints, this.nextMinPoints);

  final String name;
  final int minPoints;
  final int? nextMinPoints;

  static const tiers = [
    MemberCompetencyTier('Novice', 0, 100),
    MemberCompetencyTier('Beginner', 100, 250),
    MemberCompetencyTier('Intermediate', 250, 500),
    MemberCompetencyTier('Advanced', 500, 800),
    MemberCompetencyTier('Expert', 800, 1200),
    MemberCompetencyTier('Master', 1200, null),
  ];

  static const skillTrackLevels = ['Beginner', 'Intermediate', 'Advanced'];

  static MemberCompetencyTier forPoints(int points) {
    var current = tiers.first;
    for (final tier in tiers) {
      if (points >= tier.minPoints) current = tier;
    }
    return current;
  }
}

/// Compact skill progress summary for the member Profile tab.
class MemberProfileSkillProgressSection extends StatelessWidget {
  const MemberProfileSkillProgressSection({
    super.key,
    this.onViewRankings,
  });

  final VoidCallback? onViewRankings;

  static const _trackLevels = MemberCompetencyTier.skillTrackLevels;

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

  bool _levelMatches(String current, String trackLabel) {
    final c = current.toLowerCase();
    final t = trackLabel.toLowerCase();
    if (c.contains(t)) return true;
    if (t == 'beginner' && (c.contains('novice') || c.contains('beginner'))) {
      return true;
    }
    if (t == 'advanced' &&
        (c.contains('advanced') || c.contains('expert') || c.contains('master'))) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final snapshot = MemberCompetencySnapshot.fromAppState();
        final hasSkillLevel = appState.profileSkillLevel?.trim().isNotEmpty == true;
        final displayLevel = hasSkillLevel
            ? appState.profileSkillLevel!.trim()
            : snapshot.levelName;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccessSectionHeader(title: 'Skill Progress'),
            const SizedBox(height: 12),
            MemberDashboardCard(
              showAccentStrip: true,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayLevel,
                        style: memberDashboardSectionTitleStyle.copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: _trackLevels.map((label) {
                      final active = _levelMatches(displayLevel, label);
                      return Expanded(
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: active ? 12 : 10,
                              height: active ? 12 : 10,
                              decoration: BoxDecoration(
                                color: active ? kMemberPrimary : kDashBorder,
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
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('profile-skill-${snapshot.points}-${snapshot.progress}'),
                    tween: Tween(begin: 0, end: snapshot.progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: kSurfaceAlt),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value.clamp(0.0, 1.0),
                                child: const ColoredBox(color: kMemberPrimary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_formatXp(snapshot.points)} XP',
                    style: memberDashboardCardTitleStyle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    snapshot.isMaxLevel
                        ? 'You have reached the highest skill tier'
                        : '${_formatXp(snapshot.remainingPoints)} XP to ${snapshot.nextLevelName}',
                    style: memberDashboardMetaStyle.copyWith(
                      color: snapshot.isMaxLevel
                          ? kTextSecondary
                          : kMemberPrimary,
                      fontWeight:
                          snapshot.isMaxLevel ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: kMobileMinTouch,
                    child: OutlinedButton.icon(
                      onPressed: onViewRankings,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kMemberPrimary,
                        side: BorderSide(
                          color: kMemberPrimary.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                        ),
                        textStyle: dashText(const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                      ),
                      icon: const Icon(Icons.emoji_events_outlined, size: 18),
                      label: const Text('View Rankings'),
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

class MemberCompetencySnapshot {
  const MemberCompetencySnapshot({
    required this.levelName,
    required this.points,
    required this.progress,
    required this.remainingPoints,
    required this.nextLevelName,
    required this.isMaxLevel,
  });

  final String levelName;
  final int points;
  final double progress;
  final int remainingPoints;
  final String? nextLevelName;
  final bool isMaxLevel;

  factory MemberCompetencySnapshot.fromAppState() {
    final points = appState.profilePoints;
    final tier = MemberCompetencyTier.forPoints(points);
    final levelName = appState.profileSkillLevel?.trim().isNotEmpty == true
        ? appState.profileSkillLevel!.trim()
        : tier.name;

    if (tier.nextMinPoints == null) {
      return MemberCompetencySnapshot(
        levelName: tier.name,
        points: points,
        progress: 1,
        remainingPoints: 0,
        nextLevelName: null,
        isMaxLevel: true,
      );
    }

    final span = tier.nextMinPoints! - tier.minPoints;
    final earned = (points - tier.minPoints).clamp(0, span);
    final progress = span > 0 ? earned / span : 0.0;
    final remaining = (tier.nextMinPoints! - points).clamp(0, span);
    final nextIndex = MemberCompetencyTier.tiers.indexOf(tier) + 1;
    final nextName = nextIndex < MemberCompetencyTier.tiers.length
        ? MemberCompetencyTier.tiers[nextIndex].name
        : null;

    return MemberCompetencySnapshot(
      levelName: levelName,
      points: points,
      progress: progress.clamp(0.0, 1.0),
      remainingPoints: remaining,
      nextLevelName: nextName,
      isMaxLevel: false,
    );
  }
}

void showMemberCompetencySheet(BuildContext context) {
  showMemberSkillLevelGuideSheet(context);
}

class MemberDashboardCompetencyProgress extends StatelessWidget {
  const MemberDashboardCompetencyProgress({super.key});

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
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final snapshot = MemberCompetencySnapshot.fromAppState();

        return MemberDashboardSection(
          title: 'Competency Progress',
          subtitle: 'Earn XP from practice evaluations. Your skill label reflects evaluation quality and integrity.',
          child: Container(
            padding: const EdgeInsets.all(kMemberDashboardCardPadding),
            decoration: memberDashboardCardDecoration(
              backgroundColor: kDashAccentCompetency,
              borderColor: kDashAccentCompetencyIcon.withValues(alpha: 0.15),
              shadows: memberDashboardCardShadows(tint: kDashAccentCompetencyIcon),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: kMemberPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kMemberPrimary.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: kMemberPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Level', style: memberDashboardMetaStyle),
                          Text(
                            snapshot.levelName,
                            style: dashText(const TextStyle(
                              color: kMemberPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TweenAnimationBuilder<double>(
                  key: ValueKey('${snapshot.points}-${snapshot.progress}'),
                  tween: Tween(begin: 0, end: snapshot.progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 12,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(color: kDashCardBg),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value.clamp(0.0, 1.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: snapshot.isMaxLevel
                                          ? LinearGradient(
                                              colors: [
                                                kMemberCyan,
                                                kMemberPrimary,
                                              ],
                                            )
                                          : kMemberDashboardAccentGradient,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (snapshot.isMaxLevel)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: kYellowDim,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: kYellow.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      size: 14,
                                      color: kYellow.withValues(alpha: 0.95),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Maximum tier reached',
                                      style: dashText(const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      )),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                '${(value * 100).round()}% to ${snapshot.nextLevelName}',
                                style: memberDashboardMetaStyle,
                              ),
                            if (!snapshot.isMaxLevel)
                              Text(
                                '${snapshot.remainingPoints} XP left',
                                style: dashText(const TextStyle(
                                  color: kMemberPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _XpTile(
                        label: 'Current XP',
                        value: _formatXp(snapshot.points),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _XpTile(
                        label: snapshot.isMaxLevel ? 'Status' : 'XP to Next Level',
                        value: snapshot.isMaxLevel
                            ? 'Max tier'
                            : _formatXp(snapshot.remainingPoints),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MemberDashboardPrimaryButton(
                  label: 'View Competency',
                  icon: Icons.arrow_forward_rounded,
                  color: kMemberPrimary,
                  onPressed: () => showMemberCompetencySheet(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _XpTile extends StatelessWidget {
  const _XpTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kDashCardBg,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: dashText(const TextStyle(
              color: kDashTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            )),
          ),
          const SizedBox(height: 2),
          Text(label, style: memberDashboardMetaStyle),
        ],
      ),
    );
  }
}
