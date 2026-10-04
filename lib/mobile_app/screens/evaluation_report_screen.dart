import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/screens/evaluation_detailed_analysis_screen.dart';
import 'package:access_mobile/mobile_app/utils/evaluation_report_utils.dart';
import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/mobile_app/widgets/ai_detection_banner.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/mobile_app/widgets/media_evaluation_ui.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// Full saved evaluation report — opened from Recent Evaluations.
class EvaluationReportScreen extends StatelessWidget {
  const EvaluationReportScreen({
    super.key,
    required this.evaluation,
    this.comparisonEvaluations = const [],
  });

  final Evaluation evaluation;
  final List<PhotoEvaluationResult> comparisonEvaluations;

  PhotoEvaluationResult? get _result => evaluationToPhotoResult(evaluation);

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: kEvalBg,
      appBar: AppBar(
        backgroundColor: kEvalBg,
        foregroundColor: kDashTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Evaluation Report', style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      ),
      body: SingleChildScrollView(
        padding: mobileScrollPadding(context, top: 8, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReportMediaHeader(evaluation: evaluation),
            const SizedBox(height: 14),
            if (result != null) ...[
              if (result.showQualityFeedbackEffective) ...[
                Text(
                  'Media quality',
                  style: evalSectionTitleStyle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Technical score and improvement feedback from your upload.',
                  style: evalSectionSubtitleStyle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 10),
                MediaEvaluationResultsPanel(
                  result: result,
                  gemini: evaluation.geminiFeedback,
                  compact: true,
                  dense: true,
                  useBreakdownCard: true,
                  showOverallHeader: false,
                  feedbackIsLocalFallback: result.geminiFeedbackIsLocal,
                ),
                const SizedBox(height: 16),
              ] else ...[
                IntegrityOnlyMessageCard(result: result),
                const SizedBox(height: 16),
              ],
              AiDetectionBanner(
                aiDetection: result.aiDetection,
                adminReviewStatus: evaluation.reviewStatus,
                compact: true,
              ),
              if (evaluation.adminRemarks != null && evaluation.adminRemarks!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                AdminReviewRemarksPanel(remarks: evaluation.adminRemarks!),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: evalCardDecoration(),
                child: Text(
                  evaluation.feedback.isEmpty ? 'No detailed scores stored for this submission.' : evaluation.feedback,
                  style: evalBodyStyle,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (result != null)
              _EvalReportActionButton(
                label: 'View Detailed Analysis',
                icon: Icons.analytics_outlined,
                outlined: true,
                onPressed: () => openEvaluationDetailedAnalysis(
                  context,
                  result: result,
                  geminiFeedback: evaluation.geminiFeedback,
                  title: evaluation.title,
                  comparisonEvaluations: comparisonEvaluations,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportMediaHeader extends StatelessWidget {
  const _ReportMediaHeader({required this.evaluation});

  final Evaluation evaluation;

  bool get _isVideo => EvaluationMediaThumbnail.isVideoMedia(
        mediaType: evaluation.mediaType,
        url: evaluation.imageUrl,
      );

  bool get _hasNetworkMedia =>
      evaluation.imageUrl != null && evaluation.imageUrl!.trim().isNotEmpty;

  void _openMedia(BuildContext context) {
    if (_isVideo && _hasNetworkMedia) {
      openEvalNetworkVideoViewer(
        context,
        videoUrl: evaluation.imageUrl!,
        title: evaluation.title,
      );
      return;
    }

    if (!_hasNetworkMedia && evaluation.images.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(evaluation.title, style: const TextStyle(fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: _hasNetworkMedia
                  ? Image.network(evaluation.imageUrl!, fit: BoxFit.contain)
                  : Image.memory(evaluation.images.first, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOpenMedia = (_isVideo && _hasNetworkMedia) ||
        _hasNetworkMedia ||
        evaluation.images.isNotEmpty;

    return Container(
      decoration: evalCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 10, child: _mediaPreview(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evaluation.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: evalCardTitleStyle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: kDashTextSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        evaluation.date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                      ),
                    ),
                    if (evaluation.mediaType != null) ...[
                      const SizedBox(width: 8),
                      MediaTypeBadge(mediaType: evaluation.mediaType),
                    ],
                  ],
                ),
                if (canOpenMedia) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openMedia(context),
                      icon: Icon(
                        _isVideo ? Icons.play_circle_outline_rounded : Icons.open_in_full_rounded,
                        size: 18,
                      ),
                      label: Text(_isVideo ? 'Play Video' : 'View Original'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kEvalSecondary,
                        side: BorderSide(color: kEvalSecondary.withValues(alpha: 0.35)),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaPreview(BuildContext context) {
    if (_isVideo && _hasNetworkMedia) {
      return EvalNetworkVideoPreviewTile(
        videoUrl: evaluation.imageUrl!,
        title: evaluation.title,
        mediaType: evaluation.mediaType,
      );
    }

    if (_hasNetworkMedia) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMedia(context),
          child: Image.network(
            evaluation.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        ),
      );
    }

    if (evaluation.images.isNotEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMedia(context),
          child: Image.memory(
            evaluation.images.first,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: kEvalSecondaryLight,
      child: Center(
        child: Icon(
          evaluation.mediaType == 'video' ? Icons.videocam_rounded : Icons.photo_rounded,
          color: kEvalSecondary,
          size: 48,
        ),
      ),
    );
  }
}

class _EvalReportActionButton extends StatelessWidget {
  const _EvalReportActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: kEvalSecondary,
            side: BorderSide(color: kEvalSecondary.withValues(alpha: 0.45)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

void openEvaluationReport(
  BuildContext context,
  Evaluation evaluation, {
  List<Evaluation>? allEvaluations,
}) {
  final comparisons = allEvaluations != null
      ? comparisonResultsFromHistory(allEvaluations, excludeId: evaluation.id)
      : comparisonResultsFromHistory(appState.evaluations, excludeId: evaluation.id);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EvaluationReportScreen(
        evaluation: evaluation,
        comparisonEvaluations: comparisons,
      ),
    ),
  );
}
