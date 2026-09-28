import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:access_mobile/mobile_app/screens/evaluation_result_screen.dart';
import 'package:access_mobile/mobile_app/widgets/eval_ai_processing_view.dart';
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
  Duration get _maxVideoDuration => Duration(minutes: appState.evaluationMaxVideoMinutes);

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
        evaluationAlreadySaved: true,
        atLimit: appState.evaluationsTodayCount >= appState.dailyEvaluationLimit,
        onSave: () async {},
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
      backgroundColor: kEvalBg,
      appBar: _busy
          ? null
          : AppBar(
              backgroundColor: kEvalBg,
              foregroundColor: kDashTextPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                _isVideo ? 'Upload Video' : 'Upload Photo',
                style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
      body: _busy
          ? (_phase == _EvalPhase.analyzing
              ? EvalPracticeAnalyzingView(isVideo: _isVideo)
              : EvalAiProcessingView(
                  isVideo: _isVideo,
                  phase: EvalProcessingPhase.gemini,
                ))
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
                const SizedBox(height: 16),
                EvaluationContentStandardsCheckbox(
                  value: _contentStandardsAccepted,
                  onChanged: (v) => setState(() => _contentStandardsAccepted = v),
                  onDarkBackground: true,
                ),
                const SizedBox(height: 8),
                const LegalUploadFootnote(onDarkBackground: true),
                const SizedBox(height: 16),
                _StartEvaluationButton(
                  atLimit: atLimit,
                  enabled: _contentStandardsAccepted,
                  onPressed: _runEvaluation,
                ),
              ] else
                _UploadPageBody(
                  isVideo: _isVideo,
                  supportedFormats: _supportedFormats,
                  maxSizeLabel: _maxSizeLabel,
                  maxVideoLengthLabel: '${appState.evaluationMaxVideoMinutes} minutes',
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

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.circular(kEvalCardRadius),
        border: Border.all(color: kEvalGuideDarkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          children: [
            EvalUploadIllustration(isVideo: isVideo, size: 148),
            const SizedBox(height: 20),
            Text(
              isVideo ? 'Upload your video' : 'Upload your photo',
              style: evalGuideDarkTitleStyle.copyWith(fontSize: 22, letterSpacing: -0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Our AI will analyze technical quality and generate personalized feedback.',
              textAlign: TextAlign.center,
              style: evalGuideDarkSubtitleStyle,
            ),
            const SizedBox(height: 14),
            const EvaluationContentStandardsNotice(compact: true, onDarkBackground: true),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _InfoChip(icon: Icons.folder_open_rounded, label: 'Formats', value: supportedFormats)),
                const SizedBox(width: 10),
                Expanded(child: _InfoChip(icon: Icons.sd_storage_rounded, label: 'Max size', value: maxSizeLabel)),
              ],
            ),
            if (isVideo) ...[
              const SizedBox(height: 10),
              _InfoChip(icon: Icons.timer_outlined, label: 'Max length', value: maxVideoLengthLabel),
            ],
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: BoxDecoration(
                color: webDragging ? kMemberCyan.withValues(alpha: 0.12) : kEvalGuideDarkPanel,
                borderRadius: BorderRadius.circular(kEvalHeroRadius),
                border: Border.all(
                  color: webDragging ? kMemberCyan : kMemberCyan.withValues(alpha: 0.28),
                  width: webDragging ? 2 : 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    kIsWeb ? Icons.file_download_outlined : Icons.touch_app_outlined,
                    size: 36,
                    color: kMemberCyan,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kIsWeb ? 'Drag & Drop your file here' : 'Select a file to upload',
                    style: evalGuideDarkTitleStyle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb ? 'or use the buttons below' : 'Choose from gallery or camera',
                    style: evalGuideDarkSubtitleStyle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _UploadActionButton(
              icon: Icons.upload_file_rounded,
              label: 'Choose File',
              onTap: onChooseFile,
            ),
            const SizedBox(height: 10),
            _UploadActionButton(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              onTap: onGallery,
            ),
            if (!kIsWeb && !isVideo) ...[
              const SizedBox(height: 10),
              _UploadActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                outlined: true,
                onTap: onCamera,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kEvalGuideDarkPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kEvalGuideDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: kMemberCyan),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: evalGuideDarkSubtitleStyle.copyWith(fontSize: 10, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: dashText(const TextStyle(
              color: kEvalGuideDarkTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }
}

class _UploadActionButton extends StatelessWidget {
  const _UploadActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: kMemberCyan,
            side: BorderSide(color: kMemberCyan.withValues(alpha: 0.45)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: kMemberPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }
}

// ── Preview before evaluation ────────────────────────────────────────────────

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
          )
        : EvalPhotoPreviewTile(
            bytes: media.bytes,
            fileName: media.name,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.circular(kEvalCardRadius),
        border: Border.all(color: kEvalGuideDarkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              preview,
              if (onRemove != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: onRemove,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: evalGuideDarkTitleStyle.copyWith(fontSize: 16)),
                const SizedBox(height: 14),
                Text(
                  'Title (optional)',
                  style: evalGuideDarkSubtitleStyle.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  style: dashText(const TextStyle(
                    color: kEvalGuideDarkTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
                  decoration: InputDecoration(
                    hintText: media.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                    hintStyle: evalGuideDarkSubtitleStyle.copyWith(fontSize: 14),
                    filled: true,
                    fillColor: kEvalGuideDarkPanel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kEvalGuideDarkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kEvalGuideDarkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kMemberCyan.withValues(alpha: 0.65)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _MetaRow(icon: Icons.insert_drive_file_outlined, label: 'File name', value: media.name),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: Icons.aspect_ratio_rounded,
                  label: media.isVideo ? 'Video details' : 'Resolution',
                  value: media.resolution ?? 'N/A',
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: Icons.sd_storage_outlined,
                  label: 'File size',
                  value: formatEvalFileSize(media.bytes.length),
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: media.isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                  label: 'Media type',
                  value: media.isVideo ? 'Video' : 'Photo',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kMemberCyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kMemberCyan.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 17, color: kMemberCyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: evalGuideDarkSubtitleStyle.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                value,
                style: dashText(const TextStyle(
                  color: kEvalGuideDarkTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
        color: _canTap ? null : kDashBorder,
        boxShadow: _canTap
            ? [
                BoxShadow(
                  color: kEvalSecondary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  atLimit
                      ? Icons.block_rounded
                      : !enabled
                          ? Icons.check_box_outlined
                          : Icons.auto_awesome_rounded,
                  color: _canTap ? Colors.white : kDashTextSecondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  atLimit ? 'Daily limit reached' : 'Start AI Evaluation',
                  style: dashText(TextStyle(
                    color: _canTap ? Colors.white : kDashTextSecondary,
                    fontSize: 17,
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
