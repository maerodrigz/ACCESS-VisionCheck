import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_skill_level_guide_sheet.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';

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

  /// Backend skill tiers (`skill_scoring.effective_skill_level`).
  static const skillTrackLevels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  static MemberCompetencyTier forPoints(int points) {
    var current = tiers.first;
    for (final tier in tiers) {
      if (points >= tier.minPoints) current = tier;
    }
    return current;
  }
}

/// Profile tab density tokens (logical sp / dp).
const _kProfileSectionTitle = 18.0;
const _kProfileCardRadius = 18.0;
const _kProfileCardPad = 14.0;
const _kProfileBtnHeight = 46.0;

TextStyle _profileSectionTitle() =>
    memberDashboardSectionTitleStyle.copyWith(fontSize: _kProfileSectionTitle, fontWeight: FontWeight.w700);

TextStyle _profileBody({Color? color, FontWeight? weight}) =>
    memberDashboardMetaStyle.copyWith(fontSize: 13, height: 1.35, color: color, fontWeight: weight);

TextStyle _profileCaption({Color? color}) =>
    memberDashboardMetaStyle.copyWith(fontSize: 11.5, height: 1.3, color: color ?? kTextSecondary);

/// Compact skill progress summary for the member Profile tab.
class MemberProfileSkillProgressSection extends StatelessWidget {
  const MemberProfileSkillProgressSection({super.key});

  static String formatParticipationXp(int value) {
    final s = value.abs().toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static IconData levelBadgeIcon(String levelName) {
    final idx = MemberBackendSkillTier.indexForLevel(levelName);
    return switch (idx) {
      0 => Icons.school_rounded,
      1 => Icons.trending_up_rounded,
      2 => Icons.auto_awesome_rounded,
      _ => Icons.workspace_premium_rounded,
    };
  }

  static String friendlyMotivationLine(MemberCompetencySnapshot snapshot) {
    if (snapshot.isMaxLevel) {
      if (snapshot.skillScore != null) {
        return 'Top level unlocked. Your practice quality score is ${snapshot.skillScore!.round()}.';
      }
      return 'You have reached the highest skill level. Keep up the great work.';
    }
    if (!snapshot.progressUsesSkillScore) {
      return 'Open Rankings to load your level from released practice quality.';
    }
    final gate = snapshot.evalGateHint;
    if (gate != null) return gate;
    if (snapshot.nextLevelName == null) {
      return 'Keep practicing to strengthen your quality score.';
    }
    final scoreNote = snapshot.skillScore != null
        ? ' Current quality score: ${snapshot.skillScore!.round()}.'
        : '';
    return '${snapshot.remainingPoints} more quality points to reach ${snapshot.nextLevelName}.$scoreNote';
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
        final track = snapshot.skillTrackStates;
        final motivation = friendlyMotivationLine(snapshot);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skill progress', style: _profileSectionTitle()),
            const SizedBox(height: 4),
            Text(
              'Eligible released practice only. Daily upload cap (${appState.dailyEvaluationLimit}/day) is separate from tier progress.',
              style: _profileCaption(),
              softWrap: true,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final narrowCard = cardConstraints.maxWidth < 300;
                return Container(
              width: double.infinity,
              padding: EdgeInsets.all(narrowCard ? 12 : _kProfileCardPad),
              decoration: BoxDecoration(
                color: kDashAccentCompetency,
                borderRadius: BorderRadius.circular(_kProfileCardRadius),
                boxShadow: memberDashboardCardShadows(tint: kDashAccentCompetencyIcon),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileLevelBadge(
                        icon: levelBadgeIcon(displayLevel),
                        size: narrowCard ? 46 : 52,
                      ),
                      SizedBox(width: narrowCard ? 6 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Your level', style: _profileCaption(color: kTextSecondary)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                        displayLevel,
                              style: dashText(TextStyle(
                                color: kMemberPrimary,
                                fontSize: narrowCard ? 20 : 23,
                                fontWeight: FontWeight.w700,
                                height: 1.12,
                                letterSpacing: -0.3,
                              )),
                            ),
                            ),
                            if (snapshot.skillScore != null &&
                                snapshot.progressUsesSkillScore) ...[
                              const SizedBox(height: 6),
                              _ProfileSoftChip(
                                icon: Icons.insights_rounded,
                                label:
                                    'Quality score ${snapshot.skillScore!.round()}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProfileSkillTrack(states: track),
                  const SizedBox(height: 12),
                  if (snapshot.progressUsesSkillScore) ...[
                    _ProfileTierProgressBar(
                      progress: snapshot.progress,
                      isMaxLevel: snapshot.isMaxLevel,
                    ),
                    const SizedBox(height: 6),
                    if (!snapshot.isMaxLevel &&
                        snapshot.evalGateHint == null &&
                        snapshot.nextLevelName != null)
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          '${(snapshot.progress * 100).round()}% toward ${snapshot.nextLevelName}',
                          textAlign: TextAlign.end,
                          softWrap: true,
                          style: _profileCaption(color: kMemberPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ] else
                    _ProfileUnavailablePanel(),
                  if (snapshot.progressUsesSkillScore) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                      motivation,
                      softWrap: true,
                      style: _profileBody(
                        color: snapshot.evalGateHint != null
                            ? const Color(0xFF92400E)
                            : snapshot.isMaxLevel
                                ? kTextSecondary
                                : kMemberPrimary,
                        weight: FontWeight.w500,
                      ),
                    ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => showMemberSkillLevelGuideSheet(context),
                      style: TextButton.styleFrom(
                        foregroundColor: kMemberPrimary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'How levels work',
                              softWrap: true,
                              style: _profileBody(color: kMemberPrimary, weight: FontWeight.w600),
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
            ),
          ],
        );
      },
    );
  }
}

/// Leaderboard rank and participation XP (separate from quality-based skill tier).
class MemberProfileRankingsXpSection extends StatelessWidget {
  const MemberProfileRankingsXpSection({
    super.key,
    this.onViewRankings,
  });

  final VoidCallback? onViewRankings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final rank = appState.profileRank;
        final xp = appState.profilePoints;
        final rankLabel = rank > 0 ? '#$rank' : 'N/A';
        final rankCaption = appState.profileRankStatLabel;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rankings & XP', style: _profileSectionTitle()),
            const SizedBox(height: 4),
            Text(
              'Leaderboard participation, separate from skill quality',
              style: _profileCaption(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(_kProfileCardPad),
              decoration: BoxDecoration(
                color: kSurfaceAlt,
                borderRadius: BorderRadius.circular(_kProfileCardRadius),
                boxShadow: memberDashboardCardShadows(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _RankingsXpTile(
                            icon: Icons.leaderboard_rounded,
                            label: rankCaption,
                            value: rankLabel,
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: kBorder.withValues(alpha: 0.6),
                        ),
                        Expanded(
                          child: _RankingsXpTile(
                            icon: Icons.bolt_rounded,
                            label: 'Participation XP',
                            value: MemberProfileSkillProgressSection.formatParticipationXp(xp),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  MemberDashboardPrimaryButton(
                    label: 'View Rankings',
                    icon: Icons.emoji_events_rounded,
                    onPressed: onViewRankings,
                    minHeight: _kProfileBtnHeight,
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

class _RankingsXpTile extends StatelessWidget {
  const _RankingsXpTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kMemberPrimary),
          const SizedBox(height: 6),
          Text(
            value,
            style: dashText(const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.05,
            )),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _profileCaption(),
          ),
        ],
      ),
    );
  }
}

class _ProfileLevelBadge extends StatelessWidget {
  const _ProfileLevelBadge({
    required this.icon,
    this.size = 52,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kMemberBrandAccentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kMemberPrimary.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class _ProfileSoftChip extends StatelessWidget {
  const _ProfileSoftChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kMemberPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              softWrap: true,
              style: dashText(const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kMemberPrimary,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkillTrack extends StatelessWidget {
  const _ProfileSkillTrack({required this.states});

  final List<({String name, SkillTierTrackState state})> states;

  static String _compactTrackLabel(String name, {required bool compact}) {
    if (!compact) return name;
    return switch (name.toLowerCase()) {
      'beginner' => 'Beg',
      'intermediate' => 'Int',
      'advanced' => 'Adv',
      'expert' => 'Exp',
      _ => name.length <= 4 ? name : name.substring(0, 3),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 400;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < states.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 6, left: compact ? 0 : 2, right: compact ? 0 : 2),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: states[i - 1].state == SkillTierTrackState.completed
                            ? LinearGradient(
                                colors: [
                                  kMemberCyan.withValues(alpha: 0.5),
                                  kMemberPrimary.withValues(alpha: 0.45),
                                ],
                              )
                            : null,
                        color: states[i - 1].state == SkillTierTrackState.completed
                            ? null
                            : kSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _ProfileTrackNode(
                  label: _compactTrackLabel(states[i].name, compact: compact),
                  semanticsLabel: states[i].name,
                  state: states[i].state,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProfileTrackNode extends StatelessWidget {
  const _ProfileTrackNode({
    required this.label,
    required this.semanticsLabel,
    required this.state,
  });

  final String label;
  final String semanticsLabel;
  final SkillTierTrackState state;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == SkillTierTrackState.current;
    final isDone = state == SkillTierTrackState.completed;
    final dotColor = isCurrent
        ? kMemberPrimary
        : isDone
            ? kMemberCyan
            : kSurfaceAlt;
    final labelColor = isCurrent ? kMemberPrimary : kTextSecondary;
    final dotSize = isCurrent ? 12.0 : 9.0;

    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        width: double.infinity,
                        child: Column(
                          children: [
                            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: dotSize,
              height: dotSize,
                              decoration: BoxDecoration(
                color: isCurrent ? Colors.white : dotColor,
                                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: kMemberPrimary, width: 3)
                    : null,
                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                          color: kMemberPrimary.withValues(alpha: 0.28),
                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                              label,
                              textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                              style: memberDashboardMetaStyle.copyWith(
                  fontSize: isCurrent ? 10 : 9,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  height: 1.05,
                ),
                              ),
                            ),
                          ],
                        ),
      ),
    );
  }
}

class _ProfileTierProgressBar extends StatelessWidget {
  const _ProfileTierProgressBar({
    required this.progress,
    required this.isMaxLevel,
  });

  final double progress;
  final bool isMaxLevel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('profile-tier-bar-$progress-$isMaxLevel'),
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
            height: 8,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                ColoredBox(color: kSurface.withValues(alpha: 0.9)),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: isMaxLevel
                          ? const LinearGradient(
                              colors: [kCyan, kMemberPrimary],
                            )
                          : kMemberDashboardAccentGradient,
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

class _ProfileUnavailablePanel extends StatelessWidget {
  const _ProfileUnavailablePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_rounded, color: kMemberPrimary.withValues(alpha: 0.9), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(
                  'Level details loading',
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                  ),
                const SizedBox(height: 4),
                  Text(
                  'Open Rankings below to refresh your quality-based level and progress bar.',
                  style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}

/// Client fallbacks only when participation has not synced; backend is authoritative.
class MemberSkillEvalGates {
  MemberSkillEvalGates._();

  static bool isV2Policy(String policyVersion) =>
      policyVersion.trim().toLowerCase() == 'v2';

  static const v2MinForIntermediate = 3;
  static const v2MinDaysIntermediate = 2;
  static const v2MinForAdvanced = 12;
  static const v2MinDaysAdvanced = 10;
  static const v2MinForExpert = 24;
  static const v2MinDaysExpert = 24;

  static const v1MinForIntermediate = 3;
  static const v1MinForAdvanced = 6;
  static const v1MinForExpert = 10;

  static int minEvaluationsForTierIndex(int tierIndex, {required String policyVersion}) {
    switch (tierIndex.clamp(0, 3)) {
      case 1:
        return isV2Policy(policyVersion) ? v2MinForIntermediate : v1MinForIntermediate;
      case 2:
        return isV2Policy(policyVersion) ? v2MinForAdvanced : v1MinForAdvanced;
      case 3:
        return isV2Policy(policyVersion) ? v2MinForExpert : v1MinForExpert;
      default:
        return 0;
    }
  }

  static int? minDistinctDaysForTierIndex(int tierIndex, {required String policyVersion}) {
    if (!isV2Policy(policyVersion)) return null;
    switch (tierIndex.clamp(0, 3)) {
      case 1:
        return v2MinDaysIntermediate;
      case 2:
        return v2MinDaysAdvanced;
      case 3:
        return v2MinDaysExpert;
      default:
        return null;
    }
  }
}

/// Authoritative backend skill bands (`skill_level_from_score`).
class MemberBackendSkillTier {
  MemberBackendSkillTier._();

  static const order = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
  static const thresholds = [0, 60, 75, 90];

  static int indexForLevel(String level) {
    final normalized = level.trim().toLowerCase();
    for (var i = order.length - 1; i >= 0; i--) {
      if (normalized.contains(order[i].toLowerCase())) return i;
    }
    if (normalized.contains('novice')) return 0;
    if (normalized.contains('master')) return 3;
    return 0;
  }

  static String nameAt(int index) =>
      order[index.clamp(0, order.length - 1)];

  static int minScoreForIndex(int index) =>
      thresholds[index.clamp(0, thresholds.length - 1)];

  static int? nextMinScoreForIndex(int index) {
    if (index >= order.length - 1) return null;
    return thresholds[index + 1];
  }
}

enum SkillTierTrackState { completed, current, upcoming }

class MemberCompetencySnapshot {
  const MemberCompetencySnapshot({
    required this.levelName,
    required this.points,
    required this.progress,
    required this.remainingPoints,
    required this.nextLevelName,
    required this.isMaxLevel,
    this.skillScore,
    this.progressUsesSkillScore = false,
    this.evaluationsCount,
    this.distinctUploadDays,
    this.remainingEligibleEvaluations,
    this.remainingDistinctUploadDays,
    this.remainingQualityPoints,
    this.progressionPolicyVersion = 'v1',
    this.progressionParticipationSynced = false,
  });

  final String levelName;
  final int points;
  final double progress;
  final int remainingPoints;
  final String? nextLevelName;
  final bool isMaxLevel;
  final double? skillScore;
  final bool progressUsesSkillScore;
  final int? evaluationsCount;
  final int? distinctUploadDays;
  final int? remainingEligibleEvaluations;
  final int? remainingDistinctUploadDays;
  final int? remainingQualityPoints;
  final String progressionPolicyVersion;
  final bool progressionParticipationSynced;

  /// Quality, eligible count, or distinct upload-day gates (backend participation when loaded).
  String? get evalGateHint {
    if (!progressUsesSkillScore || isMaxLevel || nextLevelName == null) {
      return null;
    }
    final remScore = remainingQualityPoints ?? 0;
    if (remScore > 0) {
      return 'Raise your eligible quality average by $remScore points to reach '
          '$nextLevelName. Only released, skill-eligible practice counts.';
    }
    final remEvals = remainingEligibleEvaluations;
    final remDays = remainingDistinctUploadDays;
    if (remEvals != null && remEvals > 0) {
      return 'Complete $remEvals more skill-eligible released '
          '${remEvals == 1 ? 'evaluation' : 'evaluations'} toward $nextLevelName '
          '(pending or withheld uploads do not count).';
    }
    if (MemberSkillEvalGates.isV2Policy(progressionPolicyVersion) &&
        remDays != null &&
        remDays > 0) {
      return 'Practice on $remDays more distinct days with skill-eligible released '
          'evaluations toward $nextLevelName (Manila calendar days).';
    }
    if (progressionParticipationSynced) {
      return null;
    }
    final idx = MemberBackendSkillTier.indexForLevel(levelName);
    if (idx >= MemberBackendSkillTier.order.length - 1) return null;
    final nextIdx = idx + 1;
    final required = MemberSkillEvalGates.minEvaluationsForTierIndex(
      nextIdx,
      policyVersion: progressionPolicyVersion,
    );
    final requiredDays = MemberSkillEvalGates.minDistinctDaysForTierIndex(
      nextIdx,
      policyVersion: progressionPolicyVersion,
    );
    final count = evaluationsCount ?? 0;
    final days = distinctUploadDays ?? 0;
    if (count < required) {
      final need = required - count;
      return 'Complete $need more skill-eligible released '
          '${need == 1 ? 'evaluation' : 'evaluations'} to unlock $nextLevelName '
          '(pending or withheld uploads do not count).';
    }
    if (requiredDays != null &&
        progressionParticipationSynced &&
        days < requiredDays) {
      final needDays = requiredDays - days;
      return 'Spread skill-eligible released practice across $needDays more '
          'distinct upload days toward $nextLevelName.';
    }
    return null;
  }

  String get progressSubtitle {
    if (isMaxLevel) {
      if (skillScore != null) {
        return 'Maximum skill tier reached (${skillScore!.round()} quality score)';
      }
      return 'Maximum skill tier reached';
    }
    if (!progressUsesSkillScore) {
      return 'Visit Rankings to load quality-based skill tier progress';
    }
    final gate = evalGateHint;
    if (gate != null) return gate;
    if (nextLevelName == null) return 'Keep practicing to improve your quality score';
    final scoreNote =
        skillScore != null ? ' · ${skillScore!.round()} quality score now' : '';
    return '$remainingPoints quality pts to $nextLevelName$scoreNote';
  }

  List<({String name, SkillTierTrackState state})> get skillTrackStates {
    final idx = MemberBackendSkillTier.indexForLevel(levelName);
    return [
      for (var i = 0; i < MemberBackendSkillTier.order.length; i++)
        (
          name: MemberBackendSkillTier.order[i],
          state: i < idx
              ? SkillTierTrackState.completed
              : i == idx
                  ? SkillTierTrackState.current
                  : SkillTierTrackState.upcoming,
        ),
    ];
  }

  factory MemberCompetencySnapshot.fromAppState() {
    final points = appState.profilePoints;
    final policyVersion = appState.profileSkillProgressionPolicyVersion;
    final participationSynced = appState.profileSkillProgressionSynced;
    final levelName = appState.profileSkillLevel?.trim().isNotEmpty == true
        ? appState.profileSkillLevel!.trim()
        : 'Beginner';
    final score = appState.profileSkillScore;
    var evalCount = appState.profileSkillEligibleEvaluationsCount;
    if (evalCount <= 0) {
      evalCount = skillEligibleEvaluations(appState.evaluations).length;
    }
    final distinctDays = appState.profileSkillDistinctUploadDays;
    final remEvals = participationSynced
        ? (appState.profileSkillRemainingEligibleEvaluations > 0
            ? appState.profileSkillRemainingEligibleEvaluations
            : 0)
        : _remainingFromApi(
            appState.profileSkillNextTierRequiredEvaluations,
            evalCount,
          );
    final remDays = participationSynced &&
            MemberSkillEvalGates.isV2Policy(policyVersion)
        ? (appState.profileSkillRemainingDistinctUploadDays > 0
            ? appState.profileSkillRemainingDistinctUploadDays
            : 0)
        : (participationSynced
            ? null
            : _remainingFromApi(
                appState.profileSkillNextTierRequiredDays,
                distinctDays,
              ));
    final remScore = participationSynced
        ? (appState.profileSkillRemainingQualityPoints > 0
            ? appState.profileSkillRemainingQualityPoints
            : 0)
        : (appState.profileSkillScore != null
            ? _remainingQualityPoints(
                levelName,
                appState.profileSkillScore!,
              )
            : null);

    if (score != null) {
      final idx = MemberBackendSkillTier.indexForLevel(levelName);
      if (idx >= MemberBackendSkillTier.order.length - 1) {
      return MemberCompetencySnapshot(
          levelName: levelName,
        points: points,
        progress: 1,
        remainingPoints: 0,
        nextLevelName: null,
        isMaxLevel: true,
          skillScore: score,
          progressUsesSkillScore: true,
          evaluationsCount: evalCount,
          distinctUploadDays: distinctDays,
          remainingEligibleEvaluations: remEvals,
          remainingDistinctUploadDays: remDays,
          remainingQualityPoints: remScore,
          progressionPolicyVersion: policyVersion,
          progressionParticipationSynced: participationSynced,
        );
      }

      final currentMin = MemberBackendSkillTier.minScoreForIndex(idx);
      final nextMin = MemberBackendSkillTier.nextMinScoreForIndex(idx)!;
      final span = nextMin - currentMin;
      final earned = (score - currentMin).clamp(0.0, span.toDouble());
    final progress = span > 0 ? earned / span : 0.0;
      final remaining = (nextMin - score).ceil().clamp(0, span);

    return MemberCompetencySnapshot(
      levelName: levelName,
      points: points,
      progress: progress.clamp(0.0, 1.0),
      remainingPoints: remaining,
        nextLevelName: MemberBackendSkillTier.nameAt(idx + 1),
      isMaxLevel: false,
        skillScore: score,
        progressUsesSkillScore: true,
        evaluationsCount: evalCount,
        distinctUploadDays: distinctDays,
        remainingEligibleEvaluations: remEvals,
        remainingDistinctUploadDays: remDays,
        remainingQualityPoints: remScore,
        progressionPolicyVersion: policyVersion,
        progressionParticipationSynced: participationSynced,
      );
    }

    // Fallback when skill score is not loaded yet: XP totals only (no tier progress bar).
    return MemberCompetencySnapshot(
      levelName: levelName,
      points: points,
      progress: 0,
      remainingPoints: 0,
      nextLevelName: null,
      isMaxLevel: false,
      evaluationsCount: evalCount,
      distinctUploadDays: distinctDays,
      progressUsesSkillScore: false,
      progressionPolicyVersion: policyVersion,
      progressionParticipationSynced: participationSynced,
    );
  }

  static int? _remainingFromApi(int? requiredThreshold, int current) {
    if (requiredThreshold == null || requiredThreshold <= 0) return null;
    final rem = requiredThreshold - current;
    return rem > 0 ? rem : 0;
  }

  static int? _remainingQualityPoints(String levelName, double score) {
    final idx = MemberBackendSkillTier.indexForLevel(levelName);
    if (idx >= MemberBackendSkillTier.order.length - 1) return null;
    final nextMin = MemberBackendSkillTier.nextMinScoreForIndex(idx);
    if (nextMin == null) return null;
    final rem = (nextMin - score).ceil();
    return rem > 0 ? rem : 0;
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
          subtitle:
              'XP rank reflects participation. Skill tier reflects average quality on eligible released practice evaluations only.',
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
                if (snapshot.progressUsesSkillScore)
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
                                snapshot.evalGateHint ??
                                    '${(value * 100).round()}% toward ${snapshot.nextLevelName}',
                                style: memberDashboardMetaStyle,
                              ),
                            if (!snapshot.isMaxLevel && snapshot.evalGateHint == null)
                              Text(
                                '${snapshot.remainingPoints} pts left',
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
                )
                else
                  Text(
                    snapshot.progressSubtitle,
                    style: memberDashboardMetaStyle,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _XpTile(
                        label: 'Leaderboard XP',
                        value: _formatXp(snapshot.points),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _XpTile(
                        label: snapshot.isMaxLevel
                            ? 'Status'
                            : snapshot.progressUsesSkillScore
                                ? 'Skill score gap'
                                : 'Skill progress',
                        value: snapshot.isMaxLevel
                            ? 'Max tier'
                            : snapshot.progressUsesSkillScore
                                ? (snapshot.evalGateHint != null
                                    ? 'Evals needed'
                                    : '${snapshot.remainingPoints} pts')
                                : 'See Rankings',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MemberDashboardPrimaryButton(
                  label: 'View Competency',
                  icon: Icons.arrow_forward_rounded,
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
