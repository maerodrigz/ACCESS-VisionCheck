import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/criterion_score_bar.dart';
import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/mobile_app/widgets/quality_breakdown_card.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/score_ring.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';

Color qualityLevelColor(String? level) => switch (level) {
      'Excellent' => kGreen,
      'Good' => kAccent,
      'Fair' => kYellow,
      'Needs Improvement' || 'Poor' => kRed,
      _ => kTextSecondary,
    };

/// Badge for photo vs video evaluations.
class MediaTypeBadge extends StatelessWidget {
  const MediaTypeBadge({super.key, required this.mediaType});

  final String? mediaType;

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
            size: 12,
            color: kAccent,
          ),
          const SizedBox(width: 4),
          Text(
            isVideo ? 'Video' : 'Photo',
            style: const TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Compact quality level pill.
class QualityLevelBadge extends StatelessWidget {
  const QualityLevelBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = qualityLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Mini chip for list cards — criterion name + score/5.
class EvaluationCriterionChip extends StatelessWidget {
  const EvaluationCriterionChip({super.key, required this.criterion});

  final CriterionScore criterion;

  Color get _color {
    if (criterion.score >= 4) return kGreen;
    if (criterion.score == 3) return kAccent;
    if (criterion.score == 2) return kYellow;
    return kRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            criterion.name.toUpperCase(),
            style: TextStyle(color: _color.withValues(alpha: 0.85), fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${criterion.score}/5',
            style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Full results block: overall score, criterion bars, Gemini feedback sections.
class MediaEvaluationResultsPanel extends StatelessWidget {
  const MediaEvaluationResultsPanel({
    super.key,
    required this.result,
    this.gemini,
    this.mediaTypeLabel,
    this.compact = false,
    this.dense = false,
    this.showOverallHeader = true,
    this.showFeedbackCard = true,
    this.useBreakdownCard = false,
    this.feedbackIsLocalFallback = false,
  });

  final PhotoEvaluationResult result;
  final MediaEvaluationFeedback? gemini;
  final String? mediaTypeLabel;
  final bool compact;
  final bool dense;
  final bool showOverallHeader;
  final bool showFeedbackCard;
  final bool useBreakdownCard;
  final bool feedbackIsLocalFallback;

  @override
  Widget build(BuildContext context) {
    final levelColor = qualityLevelColor(result.qualityLevel);
    final showQuality = result.showQualityFeedbackEffective;
    final gf = showQuality
        ? (gemini ?? result.geminiFeedback ?? MediaEvaluationFeedback.fromLocal(result))
        : null;

    if (!showQuality) {
      return IntegrityOnlyMessageCard(result: result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useBreakdownCard) ...[
          QualityBreakdownCard(result: result, dense: dense),
        ] else ...[
          if (showOverallHeader) ...[
            Row(
              children: [
                SizedBox(
                  width: compact ? 72 : 88,
                  height: compact ? 72 : 88,
                  child: ScoreRing(
                    score: result.overallScore / 5,
                    label: '${result.overallScore.toStringAsFixed(1)}/5',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Quality Score',
                        style: TextStyle(color: kTextSecondary, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.qualityLevel,
                        style: TextStyle(color: levelColor, fontSize: compact ? 17 : 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.overallPercent}% · ${result.recommendation}',
                        style: TextStyle(color: kTextPrimary, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600),
                      ),
                      if (mediaTypeLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          mediaTypeLabel!,
                          style: const TextStyle(color: kTextSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'AI SCORES',
            style: TextStyle(
              color: kTextSecondary,
              fontSize: dense ? 9 : 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: dense ? 6 : 10),
          CriterionScoresList(
            criteria: result.displayCriteria(isVideo: result.isVideo),
            isVideo: result.isVideo,
            dense: dense,
            staggerMs: dense ? 50 : 70,
          ),
        ],
        if (showFeedbackCard && gf != null) ...[
          SizedBox(height: dense ? 10 : 14),
          if (feedbackIsLocalFallback) ...[
            const LocalFeedbackNotice(),
            const SizedBox(height: 8),
          ],
          AiFeedbackCard(feedback: gf, dense: dense),
        ],
      ],
    );
  }
}

/// Shown when Gemini narrative is unavailable and rule-based feedback is used.
class LocalFeedbackNotice extends StatelessWidget {
  const LocalFeedbackNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gemini feedback is unavailable right now. Showing an offline summary from your scores.',
              style: evalBodyStyle.copyWith(
                fontSize: 12,
                color: kTextPrimary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card wrapper for Gemini mentor feedback below technical scores.
class AiFeedbackCard extends StatelessWidget {
  const AiFeedbackCard({super.key, required this.feedback, this.dense = false});

  final MediaEvaluationFeedback feedback;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, dense ? 12 : 14, 14, dense ? 12 : 14),
      decoration: evalCardDecoration(borderColor: kEvalSecondary.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: kEvalSoftGradient,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: kEvalSecondary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Feedback',
                  style: evalCardTitleStyle.copyWith(fontSize: dense ? 14 : 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MediaEvaluationFeedbackPanel(feedback: feedback, showTitle: false, collapsibleSections: true),
        ],
      ),
    );
  }
}

/// Gemini narrative sections — strengths, improvements, tips, closing.
class MediaEvaluationFeedbackPanel extends StatelessWidget {
  const MediaEvaluationFeedbackPanel({
    super.key,
    required this.feedback,
    this.showTitle = true,
    this.collapsibleSections = false,
  });

  final MediaEvaluationFeedback feedback;
  final bool showTitle;
  final bool collapsibleSections;

  @override
  Widget build(BuildContext context) {
    final summary = energeticFeedbackText(feedback.explanation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text(
            'AI Feedback',
            style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        if (summary.isNotEmpty)
          Text(
            summary,
            style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
          ),
        if (collapsibleSections) ...[
          if (feedback.strengths.isNotEmpty) ...[
            const SizedBox(height: 10),
            _FeedbackCollapsibleSection(
              title: 'What You Did Well',
              icon: Icons.check_circle_outline_rounded,
              iconColor: kGreen,
              items: feedback.strengths,
            ),
          ],
          if (feedback.improvements.isNotEmpty)
            _FeedbackCollapsibleSection(
              title: 'Areas for Improvement',
              icon: Icons.trending_up_rounded,
              iconColor: kOrange,
              items: feedback.improvements,
            ),
          if (feedback.tips.isNotEmpty)
            _FeedbackCollapsibleSection(
              title: 'Practical Tips',
              icon: Icons.lightbulb_outline_rounded,
              iconColor: kAccent,
              items: feedback.tips,
            ),
        ] else ...[
          ..._flatSections(feedback),
        ],
        if (feedback.closingMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kEvalPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kEvalPrimary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_outline_rounded, size: 15, color: kEvalSecondary.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback.closingMessage.trim().endsWith('!')
                        ? feedback.closingMessage
                        : '${feedback.closingMessage.trim()}!',
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _flatSections(MediaEvaluationFeedback feedback) {
    return [
      if (feedback.strengths.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text(
          'What You Did Well',
          style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...feedback.strengths.map((s) => _feedbackBullet(s, Icons.check_circle_outline, kGreen)),
      ],
      if (feedback.improvements.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text(
          'Areas for Improvement',
          style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...feedback.improvements.map((s) => _feedbackBullet(s, Icons.trending_up_rounded, kOrange)),
      ],
      if (feedback.tips.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text(
          'Practical Tips',
          style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...feedback.tips.map((t) => _feedbackBullet(t, Icons.lightbulb_outline_rounded, kAccent)),
      ],
    ];
  }

  Widget _feedbackBullet(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45))),
        ],
      ),
    );
  }
}

class _FeedbackCollapsibleSection extends StatefulWidget {
  const _FeedbackCollapsibleSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;

  @override
  State<_FeedbackCollapsibleSection> createState() => _FeedbackCollapsibleSectionState();
}

class _FeedbackCollapsibleSectionState extends State<_FeedbackCollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: kBg,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 17, color: widget.iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.items.length}',
                      style: TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20,
                      color: kEvalSecondary,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  ...widget.items.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: widget.iconColor, fontWeight: FontWeight.w700)),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
