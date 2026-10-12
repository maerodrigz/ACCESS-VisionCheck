import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:access_mobile/mobile_app/screens/evaluation_result_screen.dart';
import 'package:access_mobile/mobile_app/widgets/eval_practice_analyzing_view.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/eval_upload_illustration.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_content_standards_notice.dart';
import 'package:access_mobile/mobile_app/widgets/eval_web_drop_binding.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/gemini_service.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/models/practice_evaluation_save_outcome.dart';
import 'package:access_mobile/shared/services/practice_evaluation_result_parser.dart';
import 'package:access_mobile/web_admin/services/file_picker_service.dart';

enum AiMediaEvaluationMode { photo, video }

enum _EvalPhase { idle, analyzing, gemini }

class AiMediaEvaluationScreen extends StatefulWidget {
  const AiMediaEvaluationScreen({super.key, required this.mode});

  final AiMediaEvaluationMode mode;

  bool get isVideo => mode == AiMediaEvaluationMode.video;

  @override
  State<AiMediaEvaluationScreen> createState() => _AiMediaEvaluationScreenState();
}

class _PickedMedia {
  _PickedMedia({
    required this.name,
    required this.bytes,
    required this.isVideo,
    this.filePath,
    this.resolution,
    this.previewBytes,
  });

  final String name;
  final Uint8List bytes;
  final bool isVideo;
  final String? filePath;
  final String? resolution;
  final Uint8List? previewBytes;
}

class _AiMediaEvaluationScreenState extends State<AiMediaEvaluationScreen> {
  static const _photoMaxBytes = 25 * 1024 * 1024;

  final _picker = ImagePicker();
  final _labelController = TextEditingController();

  _PickedMedia? _media;
  _EvalPhase _phase = _EvalPhase.idle;
  String? _error;
  bool _webDragging = false;
  bool _contentStandardsAccepted = false;

  bool get _isVideo => widget.isVideo;
  int get _videoMaxBytes => appState.evaluationMaxUploadMb * 1024 * 1024;
  int get _maxBytes => _isVideo ? _videoMaxBytes : _photoMaxBytes;
  String get _supportedFormats => _isVideo ? 'MP4, MOV, AVI, MKV' : 'JPG, JPEG, PNG, WEBP';
  String get _maxSizeLabel => _isVideo ? '${appState.evaluationMaxUploadMb} MB' : '25 MB';
  Duration get _maxVideoDuration => Duration(seconds: appState.evaluationMaxVideoSeconds);

  String get _maxVideoLengthLabel {
    final sec = appState.evaluationMaxVideoSeconds;
    if (sec <= 0) return '60 seconds';
    if (sec == 1) return '1 second';
    return '$sec seconds';
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      EvalWebDropBinding.install(
        isVideo: _isVideo,
        maxBytes: _maxBytes,
        onDrop: (name, bytes) => _applyPickedFile(name: name, bytes: bytes),
        onDragging: (dragging) {
          if (mounted) setState(() => _webDragging = dragging);
        },
        onReject: (message) {
          if (mounted) setState(() => _error = message);
        },
      );
    }
  }

  @override
  void dispose() {
    EvalWebDropBinding.dispose();
    _labelController.dispose();
    super.dispose();
  }

  String get _submissionTitle {
    final label = _labelController.text.trim();
    if (label.isNotEmpty) return label;
    if (_media == null) return 'Practice submission';
    final base = _media!.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return base.isNotEmpty ? base : 'Practice submission';
  }

  bool get _busy => _phase != _EvalPhase.idle;

  String _apiErrorMessage(Object e) {
    if (e is ApiException && e.isUnauthorized) {
      return 'Session expired. Please log out and sign in again.';
    }
    return e.toString().replaceFirst('ApiException: ', '').trim();
  }

  Future<void> _handleUnauthorized(Object e) async {
    if (e is ApiException && e.isUnauthorized) {
      await authController.logout();
    }
  }

  Future<void> _applyPickedFile({
    required String name,
    required Uint8List bytes,
    String? filePath,
  }) async {
    if (bytes.isEmpty) {
      setState(() => _error = 'Empty file selected.');
      return;
    }
    if (bytes.length > _maxBytes) {
      setState(() => _error = 'File exceeds the maximum size of $_maxSizeLabel.');
      return;
    }

    if (_isVideo) {
      final duration = await detectEvalVideoDuration(
        bytes: bytes,
        filePath: filePath,
        fileName: name,
      );
      if (duration != null && duration.inMilliseconds > _maxVideoDuration.inMilliseconds) {
        if (!mounted) return;
        setState(
          () => _error = 'Video exceeds the maximum length of $_maxVideoLengthLabel.',
        );
        return;
      }
    }

    final resolution = await _detectResolution(
      bytes: bytes,
      filePath: filePath,
      isVideo: _isVideo,
      fileName: name,
    );
    Uint8List? previewBytes;
    if (_isVideo && filePath != null) {
      try {
        previewBytes = await VideoThumbnail.thumbnailData(
          video: filePath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          quality: 75,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _media = _PickedMedia(
        name: name,
        bytes: bytes,
        isVideo: _isVideo,
        filePath: filePath,
        resolution: resolution,
        previewBytes: previewBytes,
      );
      _resetResults(keepMedia: true);
    });
  }

  Future<String?> _detectResolution({
    required Uint8List bytes,
    required bool isVideo,
    String? filePath,
    String? fileName,
  }) async {
    if (!isVideo) {
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) return '${decoded.width} × ${decoded.height} px';
      } catch (_) {}
      return null;
    }

    return detectEvalVideoResolution(
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
    );
  }

  Future<void> _pickFromGallery() async {
    if (kIsWeb) {
      final picked = await pickSingleMediaFromWeb(isVideo: _isVideo);
      if (picked == null) return;
      await _applyPickedFile(name: picked.name, bytes: picked.bytes);
      return;
    }
    if (_isVideo) {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: _maxVideoDuration,
      );
      if (picked == null) return;
      await _applyPickedFile(name: picked.name, bytes: await picked.readAsBytes(), filePath: picked.path);
    } else {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      await _applyPickedFile(name: picked.name, bytes: await picked.readAsBytes(), filePath: picked.path);
    }
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb || _isVideo) return;
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    await _applyPickedFile(name: picked.name, bytes: await picked.readAsBytes(), filePath: picked.path);
  }

  Future<void> _pickFromFileChooser() async {
    await _pickFromGallery();
  }

  void _resetResults({bool keepMedia = false}) {
    if (!keepMedia) {
      _media = null;
      _contentStandardsAccepted = false;
    }
    _error = null;
    _phase = _EvalPhase.idle;
  }

  Future<void> _runEvaluation() async {
    final media = _media;
    if (media == null) {
      showMobileToast(context, 'Please select a file first.', success: false);
      return;
    }
    if (!_contentStandardsAccepted) {
      showMobileToast(context, 'Please confirm this upload meets ACCESS content standards.', success: false);
      return;
    }
    if (appState.evaluationsTodayCount >= appState.dailyEvaluationLimit) {
      showMobileToast(
        context,
        'Daily limit reached. You can submit ${appState.dailyEvaluationLimit} evaluations per day.',
        success: false,
      );
      return;
    }

    if (!mounted) return;

    if (_isVideo) {
      final duration = await detectEvalVideoDuration(
        bytes: media.bytes,
        filePath: media.filePath,
        fileName: media.name,
      );
      if (!mounted) return;
      if (duration != null && duration.inMilliseconds > _maxVideoDuration.inMilliseconds) {
        setState(
          () => _error = 'Video exceeds the maximum length of $_maxVideoLengthLabel.',
        );
        showMobileToast(
          context,
          'Video exceeds the maximum length of $_maxVideoLengthLabel.',
          success: false,
        );
        return;
      }
    }

    setState(() {
      _phase = _EvalPhase.analyzing;
      _error = null;
    });

    try {
      final outcome = await memberDataController.submitPracticeEvaluation(
        bytes: media.bytes,
        fileName: media.name,
        title: _submissionTitle,
        isVideo: media.isVideo,
        shouldContinuePolling: () => mounted,
      );
      if (!mounted) return;

      if (outcome.phase == PracticeEvaluationSavePhase.uploadFailed) {
        setState(() {
          _phase = _EvalPhase.idle;
          _error = 'Upload failed. Please try again.';
        });
        return;
      }

      if (!outcome.evaluationSettledOnServer) {
        setState(() => _phase = _EvalPhase.idle);
        showMobileToast(
          context,
          'Your media is still being analyzed. You can check the result again shortly.',
          success: false,
        );
        return;
      }

      final mediaId = outcome.upload?.id ?? 0;
      var evalRow = await memberApiService.getEvaluationRowForMedia(mediaId);
      evalRow ??= await memberApiService.getEvaluationRowForMedia(mediaId);
      if (!mounted) return;

      final scored = evalRow != null ? photoEvaluationResultFromApiRow(evalRow) : null;
      if (scored == null) {
        setState(() {
          _phase = _EvalPhase.idle;
          _error = 'Analysis finished but results could not be loaded. Check your Evaluations list shortly.';
        });
        return;
      }

      final criteriaRaw = evalRow!['criteria_json'] as String?;
      final warnings = qualityWarningsFromCriteriaJson(criteriaRaw);

      PhotoEvaluationResult finalResult;
      MediaEvaluationFeedback? feedback;

      if (!scored.showQualityFeedbackEffective || scored.scoresHeldForReview) {
        setState(() => _phase = _EvalPhase.idle);
        finalResult = scored;
        feedback = null;
      } else {
        setState(() => _phase = _EvalPhase.gemini);
        final gemini = await GeminiService.generateMediaEvaluationFeedback(scoresOnly: scored);
        if (!mounted) return;
        feedback = gemini ?? MediaEvaluationFeedback.fromLocal(scored);
        final usedLocalFallback = gemini == null;
        finalResult = scored.copyWithGemini(feedback, geminiFeedbackIsLocal: usedLocalFallback);
        setState(() => _phase = _EvalPhase.idle);
      }

      if (!mounted) return;

      final remaining = appState.evaluationsRemainingToday;
      if (finalResult.scoresHeldForReview) {
        showMobileToast(
          context,
          'Submission saved. Scores and feedback will be released after admin review.',
          success: true,
        );
      } else if (finalResult.xpPendingEffective) {
        showEvalSaveSuccessToast(
          context,
          xp: finalResult.xpPointsPreviewEffective,
          submissionsRemaining: remaining,
          xpPending: true,
        );
      } else if (finalResult.xpEligibleEffective) {
        showEvalSaveSuccessToast(
          context,
          xp: MemberXpConfig.xpFromEvaluationScore(finalResult.overallScore),
          submissionsRemaining: remaining,
          xpPending: false,
        );
      }

      await memberDataController.refreshMilestones(unacknowledgedOnly: true);

      openEvaluationResultScreen(
        context,
        media: EvaluationResultMedia(
          name: media.name,
          bytes: media.bytes,
          isVideo: media.isVideo,
          previewBytes: media.previewBytes,
          filePath: media.filePath,
        ),
        submissionTitle: _submissionTitle,
        result: finalResult,
        geminiFeedback: feedback,
        qualityWarnings: warnings,
        adminReviewStatus: evalRow['review_status'] as String?,
        adminRemarks: evalRow['admin_remarks'] as String?,
        onEvaluateAgain: () {
          Navigator.of(context).pop();
          if (mounted) {
            setState(_resetResults);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      await _handleUnauthorized(e);
      setState(() {
        _phase = _EvalPhase.idle;
        _error = _apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = appState.evaluationsTodayCount >= appState.dailyEvaluationLimit;

    return Scaffold(
      backgroundColor: kBg,
      appBar: _busy
          ? null
          : AppBar(
              backgroundColor: kBg,
              foregroundColor: kTextPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                _isVideo ? 'Practice Video Evaluation' : 'Practice Photo Evaluation',
                style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
      body: _busy
          ? EvalPracticeAnalyzingView(
              isVideo: _isVideo,
              activeStage: _phase == _EvalPhase.gemini
                  ? EvalAnalysisPipelineStage.generatingFeedback
                  : null,
            )
          : ListenableBuilder(
        listenable: appState,
        builder: (_, __) => SingleChildScrollView(
          padding: mobileScrollPadding(context, top: 8, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_media != null && !_busy) ...[
                _MediaPreviewCard(
                  media: _media!,
                  titleController: _labelController,
                  onRemove: () => setState(_resetResults),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EvaluationContentStandardsCheckbox(
                        value: _contentStandardsAccepted,
                        onChanged: (v) => setState(() => _contentStandardsAccepted = v),
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: LegalUploadFootnote(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StartEvaluationButton(
                  atLimit: atLimit,
                  enabled: _contentStandardsAccepted,
                  onPressed: _runEvaluation,
                ),
                if (!atLimit && _contentStandardsAccepted) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Starting evaluation uploads your file immediately and counts toward today\'s limit.',
                    textAlign: TextAlign.center,
                    style: dashText(TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    )),
                  ),
                ],
              ] else
                _UploadPageBody(
                  isVideo: _isVideo,
                  supportedFormats: _supportedFormats,
                  maxSizeLabel: _maxSizeLabel,
                  maxVideoLengthLabel: _maxVideoLengthLabel,
                  webDragging: _webDragging,
                  onChooseFile: _pickFromFileChooser,
                  onGallery: _pickFromGallery,
                  onCamera: _pickFromCamera,
                ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Upload page (no file selected) ───────────────────────────────────────────

class _UploadPageBody extends StatelessWidget {
  const _UploadPageBody({
    required this.isVideo,
    required this.supportedFormats,
    required this.maxSizeLabel,
    required this.maxVideoLengthLabel,
    required this.webDragging,
    required this.onChooseFile,
    required this.onGallery,
    required this.onCamera,
  });

  final bool isVideo;
  final String supportedFormats;
  final String maxSizeLabel;
  final String maxVideoLengthLabel;
  final bool webDragging;
  final VoidCallback onChooseFile;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  bool get _cameraEnabled => !kIsWeb && !isVideo;

  String get _heroTitle => isVideo ? 'Select a video to upload' : 'Select a photo to upload';

  String get _heroSubtitle {
    if (kIsWeb) {
      return webDragging ? 'Drop your file here' : 'Tap to browse or drag and drop a file';
    }
    return 'Tap to browse files on your device';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _UploadInfoCard(
                icon: Icons.folder_open_rounded,
                label: 'Formats',
                value: supportedFormats,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _UploadInfoCard(
                icon: Icons.sd_storage_rounded,
                label: 'Max size',
                value: maxSizeLabel,
              ),
            ),
          ],
        ),
        if (isVideo) ...[
          const SizedBox(height: 10),
          _UploadInfoCard(
            icon: Icons.timer_outlined,
            label: 'Max length',
            value: maxVideoLengthLabel,
          ),
        ],
        const SizedBox(height: 14),
        Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: webDragging ? kCyan : kAccent.withValues(alpha: 0.14),
              width: webDragging ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: onChooseFile,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: webDragging
                      ? [kCyanDim, const Color(0xFFF8FBFF)]
                      : [
                          const Color(0xFFEAF6FD),
                          const Color(0xFFF4FAFF),
                          kSurface,
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      isVideo ? Icons.videocam_outlined : Icons.cloud_upload_outlined,
                      size: 28,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _heroTitle,
                    textAlign: TextAlign.center,
                    style: dashText(const TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _heroSubtitle,
                    textAlign: TextAlign.center,
                    style: memberDashboardMetaStyle.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompactSourceButton(
                icon: Icons.collections_rounded,
                label: 'Gallery',
                onTap: onGallery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactSourceButton(
                icon: Icons.photo_camera_rounded,
                label: 'Camera',
                onTap: _cameraEnabled ? onCamera : null,
                enabled: _cameraEnabled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UploadInfoCard extends StatelessWidget {
  const _UploadInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kCyanDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kMemberCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: memberDashboardMetaStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: dashText(const TextStyle(
                    color: kTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSourceButton extends StatelessWidget {
  const _CompactSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? kMemberCyan : kTextSecondary.withValues(alpha: 0.55);
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: kSurface,
        side: BorderSide(
          color: enabled ? kAccent.withValues(alpha: 0.22) : kBorder.withValues(alpha: 0.6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: dashText(TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            )),
          ),
        ],
      ),
    );
  }
}

// ── Preview before evaluation ────────────────────────────────────────────────

/// ~12% shorter than 16:10 while keeping aspect ratio (no stretch).
class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard({
    required this.media,
    required this.titleController,
    this.onRemove,
  });

  final _PickedMedia media;
  final TextEditingController titleController;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final preview = media.isVideo
        ? EvalVideoPreviewTile(
            bytes: media.bytes,
            fileName: media.name,
            filePath: media.filePath,
            previewBytes: media.previewBytes,
            aspectRatio: kEvalPreviewAspectRatio,
          )
        : EvalPhotoPreviewTile(
            bytes: media.bytes,
            fileName: media.name,
            aspectRatio: kEvalPreviewAspectRatio,
            showFullImage: true,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              preview,
              if (onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: kSurface.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, color: kTextSecondary, size: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompactMetaLine(
                      label: 'File name',
                      value: media.name,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactMetaLine(
                      label: 'Media type',
                      value: media.isVideo ? 'Video' : 'Photo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CompactMetaLine(
                      label: media.isVideo ? 'Video details' : 'Resolution',
                      value: media.resolution ?? 'N/A',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactMetaLine(
                      label: 'File size',
                      value: formatEvalFileSize(media.bytes.length),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Title (optional)',
                style: memberDashboardMetaStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: titleController,
                maxLines: 1,
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
                decoration: InputDecoration(
                  hintText: media.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                  hintStyle: memberDashboardMetaStyle.copyWith(fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: kBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kAccent.withValues(alpha: 0.55)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactMetaLine extends StatelessWidget {
  const _CompactMetaLine({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: memberDashboardMetaStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.25,
          )),
        ),
      ],
    );
  }
}

class _StartEvaluationButton extends StatelessWidget {
  const _StartEvaluationButton({
    required this.atLimit,
    required this.enabled,
    required this.onPressed,
  });

  final bool atLimit;
  final bool enabled;
  final VoidCallback onPressed;

  bool get _canTap => !atLimit && enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _canTap ? kEvalHeroGradient : null,
        color: _canTap ? null : kBorder,
        boxShadow: _canTap
            ? [
                BoxShadow(
                  color: kEvalSecondary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _canTap ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  atLimit
                      ? Icons.block_rounded
                      : !enabled
                          ? Icons.check_box_outlined
                          : Icons.auto_awesome_rounded,
                  color: _canTap ? Colors.white : kTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  atLimit ? 'Daily limit reached' : 'Start AI Evaluation',
                  style: dashText(TextStyle(
                    color: _canTap ? Colors.white : kTextSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, height: 1.4)),
    );
  }
}

void openAiMediaEvaluation(
  BuildContext context, {
  AiMediaEvaluationMode mode = AiMediaEvaluationMode.photo,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AiMediaEvaluationScreen(mode: mode)),
  );
}
