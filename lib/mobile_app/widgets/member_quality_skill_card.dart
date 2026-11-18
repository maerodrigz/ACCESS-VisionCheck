import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/about_skill_levels_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/quality_skill_classification.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Compact Profile "My Skill Level" — Quality Skill Classification only (no legacy Skill Tier).
class MemberQualitySkillCard extends StatefulWidget {
  const MemberQualitySkillCard({super.key});

  @override
  State<MemberQualitySkillCard> createState() => _MemberQualitySkillCardState();
}

class _MemberQualitySkillCardState extends State<MemberQualitySkillCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      memberDataController.refreshQualitySkillClassification();
    });
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AboutSkillLevelsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        final colors = AccessColors.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final snap = memberDataController.qualitySkillClassification;
        final loading = memberDataController.qualitySkillClassificationLoading &&
            snap == null;
        final error = memberDataController.qualitySkillClassificationError;

        return Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colors.surface,
                        Color.lerp(colors.surface, kAccent, 0.08)!,
                      ]
                    : [
                        colors.surface,
                        kAccent.withValues(alpha: 0.05),
                      ],
              ),
              border: Border.all(
                color: isDark ? colors.border : kAccent.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: isDark ? 0.08 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_outlined,
                          size: 15,
                          color: kAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'My Skill Level',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          )),
                        ),
                      ),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: _openAbout,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'About Skill Levels',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: dashText(const TextStyle(
                                        color: kAccent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      )),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: kAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    )
                  else if (error != null && snap == null)
                    _ErrorBody(
                      message: error,
                      onRetry: () => memberDataController
                          .refreshQualitySkillClassification(force: true),
                    )
                  else if (snap != null)
                    _ClassificationBody(snap: snap, colors: colors)
                  else
                    Text(
                      'Complete at least 3 qualifying evaluations using the current scoring system to unlock your first skill classification.',
                      style: dashText(TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      )),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClassificationBody extends StatelessWidget {
  const _ClassificationBody({
    required this.snap,
    required this.colors,
  });

  final QualitySkillClassificationSnapshot snap;
  final AccessColors colors;

  @override
  Widget build(BuildContext context) {
    final photo = snap.photo;
    final video = snap.video;
    final bothUnset = !photo.classified && !video.classified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _KindTile(
                label: 'Photo Skill',
                title: photo.title,
                average: photo.averageLabel,
                evals: photo.qualifyingEvaluations,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KindTile(
                label: 'Video Skill',
                title: video.title,
                average: video.averageLabel,
                evals: video.qualifyingEvaluations,
              ),
            ),
          ],
        ),
        if (bothUnset) ...[
          const SizedBox(height: 8),
          Text(
            'Not Yet Classified. Complete at least 3 qualifying evaluations using the current scoring system to unlock your first skill classification. Older incompatible scores are excluded.',
            style: dashText(TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            )),
          ),
        ] else ...[
          if (photo.nextTitle != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next Photo Level: ${photo.nextTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
            ),
            if (photo.progressSummary.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  photo.progressSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  )),
                ),
              ),
          ],
          if (video.nextTitle != null) ...[
            const SizedBox(height: 6),
            Text(
              'Next Video Level: ${video.nextTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
            ),
            if (video.progressSummary.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  video.progressSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  )),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.label,
    required this.title,
    required this.average,
    required this.evals,
  });

  final String label;
  final String title;
  final String average;
  final int evals;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceAlt.withValues(alpha: 0.55) : kCyanDim.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: dashText(TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            )),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: dashText(TextStyle(
              color: colors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
            )),
          ),
          const SizedBox(height: 4),
          Text(
            '$average · $evals evals',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: dashText(TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
          )),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: kAccent,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
