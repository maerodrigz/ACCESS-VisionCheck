import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_achievements.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Full achievements / milestones list opened from the member Profile tab.
class MemberAchievementsScreen extends StatelessWidget {
  const MemberAchievementsScreen({
    super.key,
    this.onViewEvaluations,
  });

  final VoidCallback? onViewEvaluations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMemberDashboardBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kDashTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Achievements',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final achievements = MemberAchievementsResolver.resolve(
            serverMilestones: memberDataController.memberMilestones,
          ).where((a) {
            final title = a.title.trim().toLowerCase();
            return !title.startsWith('skill tier');
          }).toList();

          return ListView(
            padding: mobileScrollPadding(context, top: 12),
            children: [
              Text(
                'Milestone badges and titles earned from practice and coverage.',
                style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (achievements.isEmpty)
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
                            color: kAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No badges yet. Complete quality evaluations to unlock milestones.',
                              style: memberDashboardMetaStyle.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      if (onViewEvaluations != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onViewEvaluations?.call();
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 18),
                            label: const Text('Open Evaluations'),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                ...achievements.map(
                  (achievement) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MemberDashboardCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: achievement.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              achievement.icon,
                              color: achievement.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  achievement.title,
                                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                                ),
                                if (achievement.description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    achievement.description,
                                    style: memberDashboardMetaStyle.copyWith(
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                if (achievement.date.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    achievement.date,
                                    style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
