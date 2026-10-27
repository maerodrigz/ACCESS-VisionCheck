import 'dart:async';

import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/screens/replacement_upload_screen.dart';
import 'package:access_mobile/mobile_app/widgets/submission_chain_history_panel.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/submission_chain_history.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_detailed_analysis_screen.dart';
import 'package:access_mobile/mobile_app/utils/evaluation_report_utils.dart';
import 'package:access_mobile/mobile_app/utils/practice_storage_removal.dart';
import 'package:access_mobile/mobile_app/widgets/additional_quality_insights_panel.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_report_integrity_compact.dart';
import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/mobile_app/widgets/media_evaluation_ui.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' hide AiDetectionResult;
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
String _reportAdminRemarks(Evaluation evaluation) {
  final r = evaluation.adminRemarks?.trim() ?? '';
  if (r.isNotEmpty) return r;
  final s = (evaluation.reviewStatus ?? '').toLowerCase();
  if (s.contains('reupload')) {
    return 'An administrator requested a new upload. Use Re-upload below.';
  }
  return '';
}

/// Full saved evaluation report — opened from Recent Evaluations.
class EvaluationReportScreen extends StatefulWidget {
  const EvaluationReportScreen({
    super.key,
    required this.evaluation,
    this.comparisonEvaluations = const [],
  });

  final Evaluation evaluation;
  final List<PhotoEvaluationResult> comparisonEvaluations;

  @override
  State<EvaluationReportScreen> createState() => _EvaluationReportScreenState();
}

class _EvaluationReportScreenState extends State<EvaluationReportScreen> {
  SubmissionChainHistory? _chain;
  bool _loadingChain = false;

  Evaluation get evaluation => widget.evaluation;

  PhotoEvaluationResult? get _result => evaluationToPhotoResult(evaluation);

  bool get _adminRequestedReupload => MemberReviewStatus.isReuploadRequested(evaluation.reviewStatus);

  bool get _isVideo => EvaluationMediaThumbnail.isVideoMedia(
        mediaType: evaluation.mediaType,
        url: evaluation.imageUrl,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_refreshChain());
  }

  Future<void> _refreshChain() async {
    final rootId = evaluation.chainHistoryRootMediaId;
    if (rootId == null) return;
    setState(() => _loadingChain = true);
    final chain = await memberDataController.fetchSubmissionChainHistory(rootId);
    if (mounted) {
      setState(() {
        _chain = chain;
        _loadingChain = false;
      });
    }
  }

  Future<void> _openReuploadFlow(BuildContext context) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReplacementUploadScreen(evaluation: evaluation),
      ),
    );
    if (refreshed == true) {
      await memberDataController.refreshAfterEvaluationSave();
      if (mounted) await _refreshChain();
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _result;
    final adminRemarks = _reportAdminRemarks(widget.evaluation);
    final reviewPending = (parsed != null &&
            !MemberReviewStatus.isFinalAdminDecision(evaluation.reviewStatus) &&
            (parsed.aiDetection.requiresReview ||
                MemberReviewStatus.isReviewPending(evaluation.reviewStatus) ||
                !parsed.showQualityFeedbackEffective)) ||
        (parsed == null &&
            (evaluation.isUnderAdminReview ||
                memberIntegrityReviewReasonFromEvaluation(evaluation).isNotEmpty));

    final integrityReason = parsed != null
        ? memberIntegrityReviewReason(parsed)
        : memberIntegrityReviewReasonFromEvaluation(evaluation);

    return Scaffold(
      backgroundColor: kEvalBg,
      appBar: AppBar(
        backgroundColor: kEvalBg,
        foregroundColor: kDashTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Evaluation Report', style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        actions: [
          if (evaluation.canRemovePracticeStorage)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: kDashTextPrimary),
              onSelected: (value) {
                if (value == 'remove') {
                  unawaited(
                    confirmAndRemovePracticeStorage(
                      context,
                      evaluation: evaluation,
                      popAfterSuccess: true,
                    ),
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove file (keep score)'),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: mobileScrollPadding(context, top: 8, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReportMediaHeader(
              evaluation: evaluation,
              integrityReviewReason: reviewPending && integrityReason.isNotEmpty ? integrityReason : null,
            ),
            const SizedBox(height: 14),
            if (reviewPending && parsed == null && integrityReason.isNotEmpty) ...[
              IntegrityOnlyMessageCard(
                result: parsed ??
                    PhotoEvaluationResult(
                      criteria: const [],
                      overallScore: 0,
                      qualityLevel: evaluation.qualityLevel ?? 'Fair',
                      feedback: integrityReason,
                      improvementSuggestions: '',
                      recommendation: evaluation.recommendation ?? 'For Officer Review',
                      aiDetection: const AiDetectionResult(
                        verdict: 'authentic',
                        confidence: 0.85,
                        detail: '',
                      ),
                      mediaType: evaluation.mediaType ?? 'photo',
                      scoringModel: evaluation.scoringModel ?? 'efficientnet_b0',
                      showQualityFeedback: false,
                      memberIntegrityMessage: integrityReason,
                    ),
                reviewStatus: evaluation.reviewStatus,
                adminRemarks: evaluation.adminRemarks,
              ),
              const SizedBox(height: 14),
            ],
            if (adminRemarks.isNotEmpty) ...[
              AdminReviewRemarksPanel(remarks: adminRemarks),
              const SizedBox(height: 14),
            ],
            if (parsed != null) ...[
              if (parsed.showQualityFeedbackEffective) ...[
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
                  result: parsed,
                  gemini: evaluation.geminiFeedback,
                  compact: true,
                  dense: true,
                  useBreakdownCard: true,
                  showOverallHeader: false,
                  feedbackIsLocalFallback: parsed.geminiFeedbackIsLocal,
                ),
                if (parsed.hasAdditionalQualityInsights) ...[
                  const SizedBox(height: 10),
                  AdditionalQualityInsightsPanel(
                    insights: parsed.additionalQualityInsights!,
                  ),
                ],
                const SizedBox(height: 12),
              ] else if (parsed.aiDetection.isAiGenerated &&
                  !parsed.showQualityFeedbackEffective) ...[
                IntegrityOnlyMessageCard(
                  result: parsed,
                  layout: IntegrityOnlyCardLayout.resultCompact,
                  reviewStatus: evaluation.reviewStatus,
                  adminRemarks: evaluation.adminRemarks,
                ),
                const SizedBox(height: 10),
              ],
              EvaluationReportIntegrityCompact(
                result: parsed,
                adminReviewStatus: evaluation.reviewStatus,
              ),
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
            const SizedBox(height: 12),
            if (_adminRequestedReupload) ...[
              if (_loadingChain)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
                    ),
                  ),
                )
              else if (_chain != null) ...[
                SubmissionChainHistoryPanel(history: _chain!),
                const SizedBox(height: 10),
              ],
              if (evaluation.hasActiveReplacementInChain)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Your replacement is in AI or admin review. Original remarks and history stay visible below.',
                    style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.35),
                  ),
                ),
              _EvalReportActionButton(
                label: evaluation.canSubmitLinkedReplacement
                    ? (_isVideo ? 'Re-upload Media (video)' : 'Re-upload Media')
                    : 'Replacement in review',
                icon: Icons.upload_rounded,
                outlined: false,
                onPressed: evaluation.canSubmitLinkedReplacement
                    ? () => unawaited(_openReuploadFlow(context))
                    : null,
              ),
              const SizedBox(height: 10),
            ],
            if (parsed != null)
              _EvalReportActionButton(
                label: 'View Detailed Analysis',
                icon: Icons.analytics_outlined,
                outlined: true,
                onPressed: () => openEvaluationDetailedAnalysis(
                  context,
                  result: parsed,
                  geminiFeedback: evaluation.geminiFeedback,
                  title: evaluation.title,
                  comparisonEvaluations: widget.comparisonEvaluations,
                  adminReviewStatus: evaluation.reviewStatus,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportMediaHeader extends StatelessWidget {
  const _ReportMediaHeader({
    required this.evaluation,
    this.integrityReviewReason,
  });

  final Evaluation evaluation;
  final String? integrityReviewReason;

  bool get _isVideo => EvaluationMediaThumbnail.isVideoMedia(
        mediaType: evaluation.mediaType,
        url: evaluation.imageUrl,
      );

  bool get _hasNetworkMedia =>
      !evaluation.storageRemoved &&
      evaluation.imageUrl != null &&
      evaluation.imageUrl!.trim().isNotEmpty;

  void _openMedia(BuildContext context) {
    final notice = integrityReviewReason?.trim();
    if (_isVideo && _hasNetworkMedia) {
      openEvalNetworkVideoViewer(
        context,
        videoUrl: evaluation.imageUrl!,
        title: evaluation.title,
        integrityReviewNotice: notice,
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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null && notice.isNotEmpty)
                EvalViewerIntegrityNotice(text: notice),
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    child: _hasNetworkMedia
                        ? Image.network(evaluation.imageUrl!, fit: BoxFit.contain)
                        : Image.memory(evaluation.images.first, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
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
                if (evaluation.storageRemoved) ...[
                  const SizedBox(height: 10),
                  Text(
                    'The original file was removed to save storage. Scores and feedback below are unchanged.',
                    style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.4),
                  ),
                ] else if (canOpenMedia) ...[
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
    if (evaluation.storageRemoved) {
      return EvaluationMediaThumbnail(
        imageUrl: null,
        mediaType: evaluation.mediaType,
        height: 200,
        storageRemoved: true,
        fallbackIconColor: kEvalSecondary,
      );
    }
    if (_isVideo && _hasNetworkMedia) {
      return EvalNetworkVideoPreviewTile(
        videoUrl: evaluation.imageUrl!,
        title: evaluation.title,
        mediaType: evaluation.mediaType,
        onTap: () => _openMedia(context),
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
  final VoidCallback? onPressed;
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
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: kMemberPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ),
    );
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
