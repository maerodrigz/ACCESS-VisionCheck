import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/quality_skill_classification.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Educational guide for quality Skill Classification titles (not certifications).
class AboutSkillLevelsScreen extends StatefulWidget {
  const AboutSkillLevelsScreen({super.key});

  @override
  State<AboutSkillLevelsScreen> createState() => _AboutSkillLevelsScreenState();
}

class _AboutSkillLevelsScreenState extends State<AboutSkillLevelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      memberDataController.refreshQualitySkillClassification();
    });
  }

  IconData _iconFor(String title) {
    return switch (title) {
      'Beginner' => Icons.spa_outlined,
      'Developing' => Icons.trending_up_rounded,
      'Proficient' => Icons.verified_outlined,
      'Advanced' => Icons.military_tech_outlined,
      'Expert' => Icons.emoji_events_outlined,
      _ => Icons.workspace_premium_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About Skill Levels',
          style: dashText(TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          )),
        ),
      ),
      body: ListenableBuilder(
        listenable: memberDataController,
        builder: (context, _) {
          final snap = memberDataController.qualitySkillClassification;
          final guide = snap?.guide ?? const <QualitySkillGuideTier>[];
          final loading = memberDataController.qualitySkillClassificationLoading &&
              guide.isEmpty;
          final error = memberDataController.qualitySkillClassificationError;

          if (loading) {
            return const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }

          if (error != null && guide.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: memberDashboardMetaStyle,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => memberDataController
                          .refreshQualitySkillClassification(force: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tiers = guide.isNotEmpty
              ? guide
              : _fallbackGuide();

          return ListView(
            padding: mobileScrollPadding(context, top: 12),
            children: [
              MemberDashboardCard(
                showAccentStrip: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How classifications work',
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snap?.disclaimer ??
                          'Classifications are automated media-quality assessments from ACCESS VisionCheck practice evaluations. Photo and Video are separate. XP and achievements are separate. Older incompatible scoring versions are excluded. These titles are not professional certifications.',
                      style: memberDashboardBodyStyle.copyWith(
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Photo and Video use the latest 10 qualifying comparable evaluations. A single excellent evaluation does not automatically grant Expert. You need both the average score and the minimum evaluation count.',
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final tier in tiers) ...[
                MemberDashboardCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(tier.title), size: 18, color: kCyan),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.title,
                              style: memberDashboardCardTitleStyle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tier.meaning,
                              style: memberDashboardBodyStyle.copyWith(
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Score range: ${tier.scoreRange}',
                              style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
                            ),
                            Text(
                              'Minimum evaluations: ${tier.minimumEvaluations}',
                              style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Focus: ${tier.focus}',
                              style: memberDashboardBodyStyle.copyWith(
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            if (tier.nextTitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Next: ${tier.nextTitle} (avg ≥ ${tier.nextMinimumAverage?.toStringAsFixed(2) ?? 'N/A'} / 5, ${tier.nextMinimumEvaluations ?? '-'} evals)',
                                style: dashText(TextStyle(
                                  color: kAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                )),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  List<QualitySkillGuideTier> _fallbackGuide() {
    return const [
      QualitySkillGuideTier(
        title: 'Beginner',
        meaning: 'Learning the fundamentals of media quality.',
        scoreRange: '0.00–1.99 / 5',
        minimumEvaluations: 3,
        focus: 'Steady framing, basic focus, and even lighting.',
        nextTitle: 'Developing',
        nextMinimumAverage: 2.0,
        nextMinimumEvaluations: 3,
      ),
      QualitySkillGuideTier(
        title: 'Developing',
        meaning: 'Building basic technical skills and improving consistency.',
        scoreRange: '2.00–2.99 / 5',
        minimumEvaluations: 3,
        focus: 'Reduce blur, improve exposure, and keep composition intentional.',
        nextTitle: 'Proficient',
        nextMinimumAverage: 3.0,
        nextMinimumEvaluations: 5,
      ),
      QualitySkillGuideTier(
        title: 'Proficient',
        meaning: 'Producing generally good-quality photos or videos.',
        scoreRange: '3.00–3.99 / 5',
        minimumEvaluations: 5,
        focus: 'Consistent sharpness, balanced color, and clearer storytelling frames.',
        nextTitle: 'Advanced',
        nextMinimumAverage: 4.0,
        nextMinimumEvaluations: 8,
      ),
      QualitySkillGuideTier(
        title: 'Advanced',
        meaning: 'Consistently producing high-quality evaluated media.',
        scoreRange: '4.00–4.49 / 5',
        minimumEvaluations: 8,
        focus: 'Refine detail, stability (for video), and repeatable quality.',
        nextTitle: 'Expert',
        nextMinimumAverage: 4.5,
        nextMinimumEvaluations: 10,
      ),
      QualitySkillGuideTier(
        title: 'Expert',
        meaning: 'Demonstrating consistently excellent measured media quality.',
        scoreRange: '4.50–5.00 / 5',
        minimumEvaluations: 10,
        focus: 'Maintain excellence across sessions; one strong upload alone does not grant Expert.',
      ),
    ];
  }
}
