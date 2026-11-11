import 'dart:async';

import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/screens/replacement_upload_screen.dart';
import 'package:access_mobile/mobile_app/widgets/submission_chain_history_panel.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/submission_chain_history.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_detailed_analysis_screen.dart';
import 'package:access_mobile/mobile_app/utils/evaluation_report_utils.dart';
import 'package:access_mobile/shared/utils/skill_evaluation_eligibility.dart';
import 'package:access_mobile/mobile_app/utils/practice_storage_removal.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_criterion_meta.dart';
import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_network_image.dart';
import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/mobile_app/widgets/media_evaluation_ui.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_separated_integrity_status.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' hide AiDetectionResult;
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
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
  Evaluation? _liveEvaluation;

  Evaluation get evaluation => _liveEvaluation ?? widget.evaluation;

  PhotoEvaluationResult? get _result => evaluationToPhotoResult(evaluation);

  bool get _isVideo => EvaluationMediaThumbnail.isVideoMedia(
        mediaType: evaluation.mediaType,
        url: evaluation.imageUrl,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_refreshReportState());
  }

  Future<void> _refreshReportState() async {
    final mediaId = widget.evaluation.practiceMediaId;
    if (mediaId != null) {
      final synced = await memberDataController.syncEvaluationFromServer(mediaId);
      if (mounted && synced != null) {
        setState(() => _liveEvaluation = synced);
      }
    }
    await _refreshChain();
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
      if (mounted) await _refreshReportState();
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
        foregroundColor: kTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Evaluation Report',
          style: dashText(const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.2,
            color: kTextPrimary,
          )),
        ),
        actions: [
          if (evaluation.canRemovePracticeStorage)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: kTextPrimary),
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
            const SizedBox(height: 12),
            _ReportScoreAndAdminSummary(
              evaluation: evaluation,
              parsed: parsed,
            ),
            if (parsed != null) ...[
              const SizedBox(height: 12),
              MemberSeparatedIntegrityStatusStrip(
                automated: parsed.aiDetection,
                adminReviewStatus: evaluation.reviewStatus,
                dense: true,
              ),
            ],
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
            if (parsed == null && adminRemarks.isNotEmpty) ...[
              AdminReviewRemarksPanel(remarks: adminRemarks),
              const SizedBox(height: 14),
            ],
            if (parsed != null) ...[
              if (parsed.showQualityFeedbackEffective) ...[
                MediaEvaluationResultsPanel(
                  result: parsed,
                  gemini: evaluation.geminiFeedback,
                  compact: true,
                  dense: true,
                  useBreakdownCard: true,
                  showOverallHeader: false,
                  showBreakdownOverallScore: false,
                  mergeSupplementaryInsights: true,
                  feedbackIsLocalFallback: parsed.geminiFeedbackIsLocal,
                ),
                const SizedBox(height: 12),
              ],
              _ReportAdminRemarksExpandable(
                result: parsed,
                adminReviewStatus: evaluation.reviewStatus,
                adminRemarks: evaluation.adminRemarks,
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
            if (evaluation.showReuploadWorkflowSection) ...[
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
              if (evaluation.replacementVerified) ...[
                const AdminReviewStatusBadge(reviewStatus: 'verified_human', compact: true),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Replacement verified by admin. Re-upload is locked unless an administrator requests a new upload.',
                    style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.35),
                  ),
                ),
              ] else if (evaluation.hasActiveReplacementInChain)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Your replacement is in AI or admin review. Re-upload stays locked until review finishes.',
                    style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.35),
                  ),
                ),
              if (evaluation.canSubmitLinkedReplacement)
                _EvalReportActionButton(
                  label: _isVideo ? 'Re-upload Media (video)' : 'Re-upload Media',
                  icon: Icons.upload_rounded,
                  outlined: false,
                  onPressed: () => unawaited(_openReuploadFlow(context)),
                )
              else if (!evaluation.replacementVerified &&
                  MemberReviewStatus.isReuploadRequested(evaluation.reviewStatus))
                _EvalReportActionButton(
                  label: 'Replacement in review',
                  icon: Icons.upload_rounded,
                  outlined: false,
                  onPressed: null,
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

String _reportSummaryStatusLabel(String statusTitle) {
  switch (statusTitle) {
    case 'Pending Administrator Review':
      return 'Pending Verification';
    case 'Submission Rejected':
      return 'Rejected';
    case 'Approved':
      return 'Verified';
    case 'Approved with Warning':
      return 'Approved with Warning';
    default:
      return statusTitle;
  }
}

Color _reportSummaryStatusColor(MemberIntegrityColorKind kind) {
  return memberIntegrityColorKindToColor(kind);
}

String _qualityClassificationLabel(Evaluation evaluation, PhotoEvaluationResult? parsed) {
  final raw = (parsed?.qualityLevel ?? evaluation.qualityLevel ?? '').trim();
  if (raw.isEmpty) return 'N/A';
  return raw;
}

/// Compact Phase 1 header verification chip from backend [reviewStatus].
({String label, Color color}) _reportHeaderVerificationChip(Evaluation evaluation) {
  final raw = evaluation.reviewStatus;
  if (MemberReviewStatus.isAdminRejected(raw) ||
      MemberReviewStatus.isAdminConfirmedAi(raw)) {
    return (label: 'Rejected', color: kRed);
  }
  if (MemberReviewStatus.isAdminVerified(raw)) {
    return (label: 'Verified', color: kGreen);
  }
  if (MemberReviewStatus.isReuploadRequested(raw)) {
    return (label: 'Re-upload Required', color: kAccent);
  }
  if (MemberReviewStatus.isReviewPending(raw) ||
      evaluation.isUnderAdminReview ||
      evaluation.isPending) {
    return (label: 'Pending Verification', color: kYellow);
  }
  if (MemberReviewStatus.isAutomatedLowAiRisk(raw)) {
    return (label: 'Verified', color: kGreen);
  }
  if ((raw ?? '').trim().isEmpty) {
    return (label: 'Pending Verification', color: kYellow);
  }
  return (
    label: raw!.trim().replaceAll('_', ' '),
    color: kTextSecondary,
  );
}

/// Shows unique administrator remarks only (status/XP live in the summary card).
class _ReportAdminRemarksExpandable extends StatelessWidget {
  const _ReportAdminRemarksExpandable({
    required this.result,
    this.adminReviewStatus,
    this.adminRemarks,
  });

  final PhotoEvaluationResult result;
  final String? adminReviewStatus;
  final String? adminRemarks;

  @override
  Widget build(BuildContext context) {
    final decision = memberEvaluationReportReviewDecision(
      result: result,
      adminReviewStatus: adminReviewStatus,
      adminRemarks: adminRemarks,
    );
    final remarks = decision.administratorRemarks?.trim() ?? '';
    if (remarks.isEmpty) return const SizedBox.shrink();

    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            'Administrator remarks',
            style: evalCardTitleStyle.copyWith(fontSize: 14),
          ),
          subtitle: Text(
            'Additional notes from the verification decision.',
            style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                remarks,
                style: evalBodyStyle.copyWith(fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportScoreAndAdminSummary extends StatelessWidget {
  const _ReportScoreAndAdminSummary({
    required this.evaluation,
    required this.parsed,
  });

  final Evaluation evaluation;
  final PhotoEvaluationResult? parsed;

  static const double _sideBySideBreakpoint = 400;

  @override
  Widget build(BuildContext context) {
    final scoresVisible = parsed?.showQualityFeedbackEffective == true &&
        !evaluation.isPending &&
        !evaluation.isAnalysisInProgress;
    final percent = scoresVisible ? evaluation.displayPercent : null;
    final qualityLabel = scoresVisible
        ? _qualityClassificationLabel(evaluation, parsed)
        : null;

    MemberReportReviewDecision? decision;
    if (parsed != null) {
      decision = memberEvaluationReportReviewDecision(
        result: parsed!,
        adminReviewStatus: evaluation.reviewStatus,
        adminRemarks: evaluation.adminRemarks,
      );
    }

    final scoreCard = _OverallQualityScoreCard(
      percent: percent,
      qualityLabel: qualityLabel,
      scoresHeld: !scoresVisible,
    );
    final adminCard = _AdminReviewSummaryCard(
      decision: decision,
      evaluation: evaluation,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _sideBySideBreakpoint;
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: scoreCard),
              const SizedBox(width: 10),
              Expanded(child: adminCard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            scoreCard,
            const SizedBox(height: 10),
            adminCard,
          ],
        );
      },
    );
  }
}

class _OverallQualityScoreCard extends StatelessWidget {
  const _OverallQualityScoreCard({
    required this.percent,
    required this.qualityLabel,
    required this.scoresHeld,
  });

  final int? percent;
  final String? qualityLabel;
  final bool scoresHeld;

  @override
  Widget build(BuildContext context) {
    final scoreColor = percent == null
        ? kTextSecondary
        : qualityPercentBandColor(percent!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: kAccent.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Overall Quality Score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(const TextStyle(
                    color: kTextPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (scoresHeld) ...[
            Text(
              'N/A',
              style: dashText(TextStyle(
                color: kTextSecondary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
              )),
            ),
            const SizedBox(height: 4),
            Text(
              'Score pending review',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: memberDashboardMetaStyle.copyWith(fontSize: 11.5, height: 1.3),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$percent',
                  style: dashText(TextStyle(
                    color: scoreColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.6,
                  )),
                ),
                Text(
                  '/100',
                  style: dashText(TextStyle(
                    color: kTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scoreColor.withValues(alpha: 0.28)),
              ),
              child: Text(
                qualityLabel ?? 'N/A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: scoreColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminReviewSummaryCard extends StatelessWidget {
  const _AdminReviewSummaryCard({
    required this.decision,
    required this.evaluation,
  });

  final MemberReportReviewDecision? decision;
  final Evaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final chip = _reportHeaderVerificationChip(evaluation);
    final label = decision != null
        ? _reportSummaryStatusLabel(decision!.statusTitle)
        : chip.label;
    final color = decision != null
        ? _reportSummaryStatusColor(decision!.colorKind)
        : chip.color;
    final explanation = decision?.reason ??
        (evaluation.isUnderAdminReview || evaluation.isPending
            ? 'An administrator must complete review before this submission is finalized.'
            : 'Verification status is based on the latest administrator decision.');
    final xpLine = decision?.xpOutcomeLine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Review',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            )),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              )),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 11.5,
              height: 1.35,
              color: kTextSecondary,
            ),
          ),
          if (xpLine != null && xpLine.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              xpLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              )),
            ),
          ],
        ],
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

  static const Color _skyBorder = Color(0xFFB8DCF0);

  bool get _isVideo => EvaluationMediaThumbnail.isVideoMedia(
        mediaType: evaluation.mediaType,
        url: evaluation.imageUrl,
      );

  bool get _hasNetworkMedia =>
      !evaluation.storageRemoved &&
      evaluation.imageUrl != null &&
      evaluation.imageUrl!.trim().isNotEmpty;

  bool get _canOpenMedia =>
      (_isVideo && _hasNetworkMedia) ||
      _hasNetworkMedia ||
      evaluation.images.isNotEmpty;

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
                        ? MemberNetworkImage(
                            url: evaluation.imageUrl!,
                            fit: BoxFit.contain,
                          )
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
    final verification = _reportHeaderVerificationChip(evaluation);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final canOpen = _canOpenMedia && !evaluation.storageRemoved;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _skyBorder.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: kCyan.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: narrow ? 16 / 11 : 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _MediaPreviewPane(
                evaluation: evaluation,
                isVideo: _isVideo,
                hasNetworkMedia: _hasNetworkMedia,
                canOpen: canOpen,
                onOpen: () => _openMedia(context),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _ReportMediaTypeChip(
                isVideo: _isVideo || (evaluation.mediaType ?? '') == 'video',
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ReportMediaGlassOverlay(
                evaluation: evaluation,
                verificationLabel: verification.label,
                verificationColor: verification.color,
                canOpenMedia: canOpen,
                isVideo: _isVideo,
                onOpenMedia: () => _openMedia(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewPane extends StatelessWidget {
  const _MediaPreviewPane({
    required this.evaluation,
    required this.isVideo,
    required this.hasNetworkMedia,
    required this.canOpen,
    required this.onOpen,
  });

  final Evaluation evaluation;
  final bool isVideo;
  final bool hasNetworkMedia;
  final bool canOpen;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (evaluation.storageRemoved) {
      preview = LayoutBuilder(
        builder: (context, constraints) {
          return EvaluationMediaThumbnail(
            imageUrl: null,
            mediaType: evaluation.mediaType,
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            storageRemoved: true,
            fallbackIconColor: kEvalSecondary,
          );
        },
      );
    } else if (isVideo && hasNetworkMedia) {
      preview = EvalNetworkVideoPreviewTile(
        videoUrl: evaluation.imageUrl!,
        title: evaluation.title,
        mediaType: evaluation.mediaType,
        interactive: false,
      );
    } else if (hasNetworkMedia) {
      preview = LayoutBuilder(
        builder: (context, constraints) {
          return EvaluationMediaThumbnail(
            imageUrl: evaluation.imageUrl,
            mediaType: evaluation.mediaType ?? 'photo',
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            fit: BoxFit.cover,
            fallbackIconColor: kEvalSecondary,
          );
        },
      );
    } else if (evaluation.images.isNotEmpty) {
      preview = Image.memory(
        evaluation.images.first,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      preview = ColoredBox(
        color: kCyanDim,
        child: Center(
          child: Icon(
            isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
            color: kEvalSecondary,
            size: 40,
          ),
        ),
      );
    }

    return Material(
      color: kCyanDim.withValues(alpha: 0.55),
      child: InkWell(
        onTap: canOpen ? onOpen : null,
        child: preview,
      ),
    );
  }
}

/// Bottom info strip matching Recent Evaluations: dark gradient + compact meta.
class _ReportMediaGlassOverlay extends StatelessWidget {
  const _ReportMediaGlassOverlay({
    required this.evaluation,
    required this.verificationLabel,
    required this.verificationColor,
    required this.canOpenMedia,
    required this.isVideo,
    required this.onOpenMedia,
  });

  final Evaluation evaluation;
  final String verificationLabel;
  final Color verificationColor;
  final bool canOpenMedia;
  final bool isVideo;
  final VoidCallback onOpenMedia;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.42),
            Colors.black.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 22, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evaluation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.15,
                shadows: [
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    evaluation.date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _HeaderVerificationChip(
                        label: verificationLabel,
                        color: verificationColor,
                        onDark: true,
                      ),
                      if (canOpenMedia)
                        _ReportMediaActionChip(
                          label: isVideo ? 'Play Video' : 'View Original',
                          icon: isVideo
                              ? Icons.play_circle_outline_rounded
                              : Icons.open_in_full_rounded,
                          onTap: onOpenMedia,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (evaluation.storageRemoved) ...[
              const SizedBox(height: 6),
              Text(
                'Original file removed. Scores below are unchanged.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 10.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportMediaTypeChip extends StatelessWidget {
  const _ReportMediaTypeChip({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kCyan.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 3),
          Text(
            isVideo ? 'Video' : 'Photo',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMediaActionChip extends StatelessWidget {
  const _ReportMediaActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: dashText(const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderVerificationChip extends StatelessWidget {
  const _HeaderVerificationChip({
    required this.label,
    required this.color,
    this.onDark = false,
  });

  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final bg = onDark
        ? color.withValues(alpha: 0.28)
        : color.withValues(alpha: 0.12);
    final border = onDark
        ? Colors.white.withValues(alpha: 0.35)
        : color.withValues(alpha: 0.32);
    final textColor = onDark ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: dashText(TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        )),
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
  final pool = allEvaluations ?? appState.evaluations;
  final currentIsVideo = isVideoPracticeEvaluation(evaluation);
  final comparisons = comparisonResultsFromHistory(
    pool,
    excludeId: evaluation.id,
    sameMediaTypeAsVideo: currentIsVideo,
  );

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EvaluationReportScreen(
        evaluation: evaluation,
        comparisonEvaluations: comparisons,
      ),
    ),
  );
}
