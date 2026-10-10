import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/screens/evaluation_detailed_analysis_screen.dart';
import 'package:access_mobile/mobile_app/widgets/ai_detection_banner.dart';
import 'package:access_mobile/mobile_app/widgets/integrity_evaluation_notice.dart';
import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/eval_result_action_bar.dart';
import 'package:access_mobile/mobile_app/widgets/media_evaluation_ui.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';

String _adminRemarksForPanel(String? reviewStatus, String? adminRemarks) {
  final r = adminRemarks?.trim() ?? '';
  if (r.isNotEmpty) return r;
  if (MemberReviewStatus.isReuploadRequested(reviewStatus)) {
    return 'An administrator requested a new upload. Submit a replacement from Evaluations.';
  }
  return '';
}

class EvaluationResultMedia {
  const EvaluationResultMedia({
    required this.name,
    required this.bytes,
    required this.isVideo,
    this.previewBytes,
    this.filePath,
  });

  final String name;
  final Uint8List bytes;
  final bool isVideo;
  final Uint8List? previewBytes;
  final String? filePath;
}

class EvaluationResultScreen extends StatefulWidget {
  const EvaluationResultScreen({
    super.key,
    required this.media,
    required this.result,
    this.geminiFeedback,
    this.qualityWarnings = const [],
    required this.evaluatedAt,
    required this.onSave,
    required this.onEvaluateAgain,
    this.atLimit = false,
    this.submissionTitle,
    this.evaluationAlreadySaved = false,
    this.adminReviewStatus,
    this.adminRemarks,
  });

  final EvaluationResultMedia media;
  final PhotoEvaluationResult result;
  final MediaEvaluationFeedback? geminiFeedback;
  final List<String> qualityWarnings;
  final DateTime evaluatedAt;
  final Future<void> Function() onSave;
  final VoidCallback onEvaluateAgain;
  final bool atLimit;
  final String? submissionTitle;
  final bool evaluationAlreadySaved;
  final String? adminReviewStatus;
  final String? adminRemarks;

  @override
  State<EvaluationResultScreen> createState() => _EvaluationResultScreenState();
}

class _EvaluationResultScreenState extends State<EvaluationResultScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      memberDataController.celebratePendingMilestones(context);
    });
  }

  String get _formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[widget.evaluatedAt.month - 1]} ${widget.evaluatedAt.day}, ${widget.evaluatedAt.year}';
  }

  Future<void> _handleSave() async {
    if (_isSaving || widget.atLimit) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleDone() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final showQuality = widget.result.showQualityFeedbackEffective;
    final heldForReview =
        widget.result.scoresHeldForReview && !widget.result.aiDetection.isAiGenerated;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Evaluation Result', style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      ),
      body: SingleChildScrollView(
        padding: mobileScrollPadding(context, top: 8, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultTopCard(
              media: widget.media,
              displayTitle: widget.submissionTitle ?? widget.media.name,
              fileName: widget.media.name,
              date: _formattedDate,
              onViewOriginal: () => _openOriginal(context),
            ),
            const SizedBox(height: 10),
            if (widget.qualityWarnings.isNotEmpty) ...[
              _QualityWarningsBanner(warnings: widget.qualityWarnings),
              const SizedBox(height: 8),
            ],
            if (showQuality) ...[
              Text('Media quality', style: evalSectionTitleStyle.copyWith(fontSize: 15)),
              const SizedBox(height: 8),
              MediaEvaluationResultsPanel(
                result: widget.result,
                gemini: widget.geminiFeedback,
                compact: true,
                dense: true,
                useBreakdownCard: true,
                showOverallHeader: false,
                feedbackIsLocalFallback: widget.result.geminiFeedbackIsLocal,
              ),
              const SizedBox(height: 10),
            ] else ...[
              IntegrityOnlyMessageCard(
                result: widget.result,
                layout: IntegrityOnlyCardLayout.resultCompact,
                reviewStatus: widget.adminReviewStatus,
                adminRemarks: widget.adminRemarks,
              ),
              const SizedBox(height: 8),
            ],
            if (showQuality &&
                (MemberReviewStatus.isReuploadRequested(widget.adminReviewStatus) ||
                    (widget.adminRemarks?.trim().isNotEmpty ?? false))) ...[
              AdminReviewRemarksPanel(
                remarks: _adminRemarksForPanel(widget.adminReviewStatus, widget.adminRemarks),
              ),
              const SizedBox(height: 8),
            ],
            AiDetectionBanner(
              aiDetection: widget.result.aiDetection,
              compact: true,
              minimal: !showQuality || heldForReview,
              practiceFinalCopy: widget.evaluationAlreadySaved,
              adminReviewStatus: widget.adminReviewStatus,
            ),
            if (showQuality &&
                !widget.evaluationAlreadySaved &&
                widget.result.qualityProvisionalEffective &&
                !heldForReview) ...[
              const SizedBox(height: 8),
              IntegrityProvisionalBanner(
                message: widget.result.memberIntegrityMessageEffective.isNotEmpty
                    ? widget.result.memberIntegrityMessageEffective
                    : 'Scores may change after integrity review completes.',
              ),
            ],
            const SizedBox(height: 12),
            EvalResultActionBar(
              compact: true,
              isSaving: _isSaving,
              atLimit: widget.atLimit,
              evaluationAlreadySaved: widget.evaluationAlreadySaved,
              evaluateAgainLabel: widget.evaluationAlreadySaved
                  ? (widget.media.isVideo ? 'Choose another video' : 'Choose another photo')
                  : null,
              onSave: widget.evaluationAlreadySaved ? _handleDone : _handleSave,
              onEvaluateAgain: widget.onEvaluateAgain,
              onDetailedAnalysis: showQuality
                  ? () => openEvaluationDetailedAnalysis(
                        context,
                        result: widget.result,
                        geminiFeedback: widget.geminiFeedback,
                        title: widget.media.name,
                        initialTab: 0,
                      )
                  : null,
              adminReviewStatus: widget.adminReviewStatus,
            ),
          ],
        ),
      ),
    );
  }

  void _openOriginal(BuildContext context) {
    final media = widget.media;
    if (media.isVideo) {
      openEvalLocalVideoViewer(
        context,
        bytes: media.bytes,
        fileName: media.name,
        filePath: media.filePath,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(media.name, style: const TextStyle(fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.memory(media.bytes, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }
}

class _ResultTopCard extends StatelessWidget {
  const _ResultTopCard({
    required this.media,
    required this.displayTitle,
    required this.fileName,
    required this.date,
    required this.onViewOriginal,
  });

  final EvaluationResultMedia media;
  final String displayTitle;
  final String fileName;
  final String date;
  final VoidCallback onViewOriginal;

  @override
  Widget build(BuildContext context) {
    final preview = media.isVideo
        ? EvalVideoPreviewTile(
            bytes: media.bytes,
            fileName: media.name,
            filePath: media.filePath,
            previewBytes: media.previewBytes,
            aspectRatio: kEvalPreviewAspectRatio,
            showFullThumbnail: true,
            onTap: onViewOriginal,
          )
        : EvalPhotoPreviewTile(
            bytes: media.bytes,
            fileName: media.name,
            aspectRatio: kEvalPreviewAspectRatio,
            showFullImage: true,
            showTapHint: false,
            onTap: onViewOriginal,
          );

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: evalCardTitleStyle.copyWith(fontSize: 15),
                ),
                if (displayTitle != fileName) ...[
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: kTextSecondary),
                    const SizedBox(width: 5),
                    Text(date, style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
                    const Spacer(),
                    MediaTypeBadge(mediaType: media.isVideo ? 'video' : 'photo'),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onViewOriginal,
                  icon: Icon(
                    media.isVideo ? Icons.play_circle_outline_rounded : Icons.open_in_full_rounded,
                    size: 17,
                  ),
                  label: Text(media.isVideo ? 'Play Video' : 'View Original'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: BorderSide(color: kAccent.withValues(alpha: 0.35)),
                    minimumSize: const Size.fromHeight(40),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityWarningsBanner extends StatelessWidget {
  const _QualityWarningsBanner({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kYellow.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ImageValidationResult.acceptedWithIssuesMessage,
            style: const TextStyle(color: kDashTextPrimary, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $w', style: evalBodyStyle.copyWith(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

void openEvaluationResultScreen(
  BuildContext context, {
  required EvaluationResultMedia media,
  required PhotoEvaluationResult result,
  MediaEvaluationFeedback? geminiFeedback,
  List<String> qualityWarnings = const [],
  required Future<void> Function() onSave,
  required VoidCallback onEvaluateAgain,
  bool atLimit = false,
  String? submissionTitle,
  bool evaluationAlreadySaved = false,
  String? adminReviewStatus,
  String? adminRemarks,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EvaluationResultScreen(
        media: media,
        result: result,
        geminiFeedback: geminiFeedback,
        qualityWarnings: qualityWarnings,
        evaluatedAt: DateTime.now(),
        onSave: onSave,
        onEvaluateAgain: onEvaluateAgain,
        atLimit: atLimit,
        submissionTitle: submissionTitle,
        evaluationAlreadySaved: evaluationAlreadySaved,
        adminReviewStatus: adminReviewStatus,
        adminRemarks: adminRemarks,
      ),
    ),
  );
}
