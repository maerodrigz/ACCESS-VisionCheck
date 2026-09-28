import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

/// Milestone definitions aligned with [memberBadge] in app_state.dart.
class _BadgeMilestone {
  const _BadgeMilestone({
    required this.goodEvalCount,
    required this.title,
    required this.description,
    required this.icon,
  });

  final int goodEvalCount;
  final String title;
  final String description;
  final IconData icon;
}

/// Resolves earned achievements from evaluation history and the badge system.
class MemberAchievementsResolver {
  MemberAchievementsResolver._();

  static const _badgeMilestones = [
    _BadgeMilestone(
      goodEvalCount: 1,
      title: 'Beginner Badge',
      description: 'Earned Beginner status with your first quality evaluation.',
      icon: Icons.military_tech_outlined,
    ),
    _BadgeMilestone(
      goodEvalCount: 3,
      title: 'Intermediate Badge',
      description: 'Reached Intermediate with 3 quality evaluations.',
      icon: Icons.workspace_premium_outlined,
    ),
    _BadgeMilestone(
      goodEvalCount: 6,
      title: 'Advanced Badge',
      description: 'Advanced badge unlocked with 6 quality evaluations.',
      icon: Icons.emoji_events_outlined,
    ),
    _BadgeMilestone(
      goodEvalCount: 10,
      title: 'Expert Badge',
      description: 'Expert badge unlocked with 10 quality evaluations.',
      icon: Icons.stars_rounded,
    ),
    _BadgeMilestone(
      goodEvalCount: 15,
      title: 'Master Badge',
      description: 'Master badge unlocked with 15 quality evaluations.',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  static List<Achievement> resolve() {
    final scoredNewestFirst =
        appState.evaluations.where((e) => e.score > 0).toList();
    final goodNewestFirst =
        appState.evaluations.where((e) => e.score >= 0.70).toList();

    if (scoredNewestFirst.isEmpty && appState.profileEvaluationsCount <= 0) {
      return const [];
    }

    final chronologicalScored = scoredNewestFirst.reversed.toList();
    final chronologicalGood = goodNewestFirst.reversed.toList();
    final earned = <_EarnedAchievement>[];

    if (chronologicalScored.isNotEmpty) {
      final first = chronologicalScored.first;
      if (first.date.isNotEmpty) {
        earned.add(_EarnedAchievement(
          sortOrder: 0,
          achievement: Achievement(
            title: 'First Evaluation',
            description: 'Completed your first media evaluation.',
            icon: Icons.fact_check_outlined,
            color: kMemberDashboardAccent,
            date: first.date,
          ),
        ));
      }
    }

    for (final milestone in _badgeMilestones) {
      if (chronologicalGood.length < milestone.goodEvalCount) continue;
      final eval = chronologicalGood[milestone.goodEvalCount - 1];
      if (eval.date.isEmpty) continue;
      earned.add(_EarnedAchievement(
        sortOrder: milestone.goodEvalCount,
        achievement: Achievement(
          title: milestone.title,
          description: milestone.description,
          icon: milestone.icon,
          color: memberBadge(milestone.goodEvalCount).color,
          date: eval.date,
        ),
      ));
    }

    final title = appState.profileTitle;
    if (title != null && chronologicalScored.length >= 3) {
      final third = chronologicalScored[2];
      if (third.date.isNotEmpty) {
        earned.add(_EarnedAchievement(
          sortOrder: 100 + chronologicalScored.length,
          achievement: Achievement(
            title: title,
            description: 'Earned your photographer title based on evaluation quality.',
            icon: Icons.camera_enhance_outlined,
            color: kMemberDashboardAccent,
            date: third.date,
          ),
        ));
      }
    }

    final improvement = _improvingCreatorMilestone(scoredNewestFirst);
    if (improvement != null) earned.add(improvement);

    if (earned.isEmpty) return const [];

    earned.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    return earned.map((e) => e.achievement).toList();
  }

  static _EarnedAchievement? _improvingCreatorMilestone(
    List<Evaluation> scoredNewestFirst,
  ) {
    if (scoredNewestFirst.length < 6) return null;

    double avg(Iterable<Evaluation> items) =>
        items.fold<double>(0, (sum, e) => sum + e.displayScore) / items.length;

    final recent = scoredNewestFirst.take(3);
    final prior = scoredNewestFirst.skip(3).take(3);
    final recentAvg = avg(recent);
    final priorAvg = avg(prior);
    final delta = recentAvg - priorAvg;
    if (delta < 0.05) return null;

    final date = scoredNewestFirst.first.date;
    if (date.isEmpty) return null;

    return _EarnedAchievement(
      sortOrder: 200 + scoredNewestFirst.length,
      achievement: Achievement(
        title: 'Improving Creator',
        description: 'Demonstrated improvement in evaluation performance.',
        icon: Icons.trending_up_rounded,
        color: kMemberDashboardAccent,
        date: date,
      ),
    );
  }
}

class _EarnedAchievement {
  const _EarnedAchievement({
    required this.sortOrder,
    required this.achievement,
  });

  final int sortOrder;
  final Achievement achievement;
}

/// Achievements on the member Profile tab — badge strip plus recent milestones.
class MemberProfileAchievementsSection extends StatelessWidget {
  const MemberProfileAchievementsSection({
    super.key,
    this.onViewRankings,
    this.onViewEvaluations,
  });

  final VoidCallback? onViewRankings;
  final VoidCallback? onViewEvaluations;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final achievements = MemberAchievementsResolver.resolve();

        if (achievements.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AccessSectionHeader(title: 'Achievements'),
              const SizedBox(height: 12),
              MemberDashboardCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MemberDashboardIconTile(
                          icon: Icons.emoji_events_outlined,
                          size: 42,
                          iconSize: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No badges yet',
                                style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Complete quality evaluations to unlock milestones and badges.',
                                style: memberDashboardMetaStyle.copyWith(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: kMobileMinTouch,
                      child: OutlinedButton.icon(
                        onPressed: onViewEvaluations,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMemberPrimary,
                          side: BorderSide(
                            color: kMemberPrimary.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(kMemberDashboardButtonRadius),
                          ),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text('Start Evaluating'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final preview = achievements.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AccessSectionHeader(
              title: 'Achievements',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kBlueDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${achievements.length}',
                  style: dashText(const TextStyle(
                    color: kMemberPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _AchievementBadgeTile(achievement: achievements[i]),
              ),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...preview.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AchievementCard(achievement: achievement),
                ),
              ),
            ],
            if (onViewRankings != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onViewRankings,
                  style: TextButton.styleFrom(
                    foregroundColor: kMemberPrimary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: Text(
                    'View full leaderboard',
                    style: memberDashboardMetaStyle.copyWith(
                      color: kMemberPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _AchievementBadgeTile extends StatelessWidget {
  const _AchievementBadgeTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: memberDashboardCardDecoration(
        shadows: memberDashboardCardShadows(tint: achievement.color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: achievement.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: achievement.color.withValues(alpha: 0.25)),
            ),
            child: Icon(achievement.icon, size: 20, color: achievement.color),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberDashboardIconTile(
            icon: achievement.icon,
            size: 42,
            iconSize: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          if (achievement.date.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                achievement.date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: memberDashboardMetaStyle.copyWith(fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
