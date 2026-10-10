import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';

/// Full explainer: skill score weights, tier thresholds, and daily upload guidance.
void showMemberSkillLevelGuideSheet(BuildContext context) {
  final snapshot = MemberCompetencySnapshot.fromAppState();
  final dailyLimit = appState.dailyEvaluationLimit;
  final usedToday = appState.evaluationsTodayCount;
  final remainingToday = appState.evaluationsRemainingToday;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kDashCardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kDashBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'How your level is calculated',
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
                  children: [
                    _SummaryChip(
                      label: 'Current level',
                      value: snapshot.levelName,
                    ),
                    const SizedBox(height: 8),
                    _SummaryChip(
                      label: 'Total XP',
                      value: '${snapshot.points}',
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle('Skill level (Beginner → Expert)'),
                    const SizedBox(height: 8),
                    Text(
                      MemberXpConfig.skillLevelIntro,
                      style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ...MemberXpConfig.skillScoreWeights.map(
                      (row) => _BulletRow(
                        title: row.label,
                        body: '${row.weight} of your skill score',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Score ranges',
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MemberXpConfig.skillLevelTiers.map((tier) {
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
                            '${tier.name} · ${tier.range}',
                            style: dashText(const TextStyle(
                              color: kMemberDashboardAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle('Daily uploads: how many per day?'),
                    const SizedBox(height: 8),
                    Text(
                      MemberXpConfig.uploadGuidanceIntro,
                      style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Practice evaluations (AI scoring)',
                      body: MemberXpConfig.evaluationDailyLimitBody(dailyLimit),
                      footer:
                          'Today: $usedToday of $dailyLimit used · $remainingToday remaining',
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      icon: Icons.event_outlined,
                      title: 'Event documentation (assignments)',
                      body: MemberXpConfig.eventUploadGuidanceBody,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      MemberXpConfig.uploadQualityTip,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle('Leaderboard XP'),
                    const SizedBox(height: 8),
                    Text(
                      MemberXpConfig.howXpIntro,
                      style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      snapshot.progressSubtitle,
                      style: memberDashboardBodyStyle.copyWith(
                        fontSize: 13,
                        color: kMemberPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...MemberXpConfig.earningRules.map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BulletRow(title: rule.title, body: rule.body),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kMemberDashboardAccentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMemberDashboardAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: memberDashboardMetaStyle),
          Text(
            value,
            style: dashText(const TextStyle(
              color: kMemberDashboardAccent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: const BoxDecoration(
              color: kMemberDashboardAccent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: kMemberPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              body,
              style: memberDashboardBodyStyle.copyWith(fontSize: 12),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                footer!,
                style: memberDashboardMetaStyle.copyWith(
                  fontSize: 11,
                  color: kMemberPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
