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
          SizedBox(height: dense ? 14 : 18),
          if (feedbackIsLocalFallback) ...[
            const LocalFeedbackNotice(),
            const SizedBox(height: 10),
          ],
          AiFeedbackCard(feedback: gf),
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
  const AiFeedbackCard({super.key, required this.feedback});

  final MediaEvaluationFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: evalCardDecoration(borderColor: kEvalSecondary.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: kEvalSoftGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: kEvalSecondary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Feedback',
                      style: evalCardTitleStyle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Personalized guidance from your evaluation scores',
                      style: evalBodyStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MediaEvaluationFeedbackPanel(feedback: feedback, showTitle: false),
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
  });

  final MediaEvaluationFeedback feedback;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
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
        Text(
          energeticFeedbackText(feedback.explanation),
          style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.55, fontWeight: FontWeight.w500),
        ),
        if (feedback.strengths.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'What you\'re doing well',
            style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...feedback.strengths.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: kGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45))),
                ],
              ),
            ),
          ),
        ],
        if (feedback.improvements.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Room to grow',
            style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...feedback.improvements.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trending_up_rounded, color: kOrange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45))),
                ],
              ),
            ),
          ),
        ],
        if (feedback.tips.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Practical tips',
            style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...feedback.tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: kAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45))),
                ],
              ),
            ),
          ),
        ],
        if (feedback.closingMessage.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kEvalPrimaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kEvalPrimary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_outline_rounded, size: 16, color: kEvalSecondary.withValues(alpha: 0.85)),
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
}
