import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/submission_chain_history_panel.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/practice_evaluation_save_outcome.dart';
import 'package:access_mobile/shared/models/submission_chain_history.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class ReplacementUploadScreen extends StatefulWidget {
  const ReplacementUploadScreen({super.key, required this.evaluation});

  final Evaluation evaluation;

  @override
  State<ReplacementUploadScreen> createState() => _ReplacementUploadScreenState();
}

class _PickedMedia {
  _PickedMedia({required this.name, required this.bytes, required this.isVideo, this.filePath});

  final String name;
  final Uint8List bytes;
  final bool isVideo;
  final String? filePath;
}

class _ReplacementUploadScreenState extends State<ReplacementUploadScreen> {
  final _picker = ImagePicker();
  _PickedMedia? _media;
  bool _uploading = false;
  String? _error;
  SubmissionChainHistory? _chain;
  bool _loadingChain = true;

  int? get _targetMediaId => widget.evaluation.replacementTargetMediaId;

  bool get _isVideoOriginal =>
      (widget.evaluation.mediaType ?? '').toLowerCase().contains('video');

  @override
  void initState() {
    super.initState();
    unawaited(_loadChain());
  }

  Future<void> _loadChain() async {
    final rootId = widget.evaluation.chainHistoryRootMediaId;
    if (rootId == null) {
      if (mounted) setState(() => _loadingChain = false);
      return;
    }
    final chain = await memberDataController.fetchSubmissionChainHistory(rootId);
    if (mounted) {
      setState(() {
        _chain = chain;
        _loadingChain = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _applyPicked(name: picked.name, bytes: await picked.readAsBytes(), isVideo: false, path: picked.path);
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await _applyPicked(name: picked.name, bytes: await picked.readAsBytes(), isVideo: true, path: picked.path);
  }

  Future<void> _applyPicked({
    required String name,
    required Uint8List bytes,
    required bool isVideo,
    String? path,
  }) async {
    if (isVideo) {
      final duration = await detectEvalVideoDuration(bytes: bytes, filePath: path, fileName: name);
      if (duration != null && duration.inSeconds > 60) {
        if (mounted) {
          setState(() => _error = 'Practice videos must be 60 seconds or less.');
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _media = _PickedMedia(name: name, bytes: bytes, isVideo: isVideo, filePath: path);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_uploading) return;
    final targetId = _targetMediaId;
    if (targetId == null) {
      setState(() => _error = 'This submission is not eligible for replacement upload.');
      return;
    }
    final media = _media;
    if (media == null) {
      showMobileToast(context, 'Select a replacement file first.', success: false);
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    final outcome = await memberDataController.submitReplacementEvaluation(
      replacesMediaId: targetId,
      bytes: media.bytes,
      fileName: media.name,
      title: widget.evaluation.title,
      isVideo: media.isVideo,
      shouldContinuePolling: () => mounted,
    );

    if (!mounted) return;

    if (outcome.phase == PracticeEvaluationSavePhase.uploadFailed) {
      setState(() {
        _uploading = false;
        _error = outcome.errorMessage ?? 'Upload failed.';
      });
      showMobileToast(context, _error!, success: false);
      return;
    }

    await _loadChain();
    if (!mounted) return;

    setState(() => _uploading = false);

    if (outcome.evaluationSettledOnServer) {
      showMobileToast(context, 'Replacement uploaded. Analysis and review will continue on the server.', success: true);
      Navigator.of(context).pop(true);
      return;
    }

    showMobileToast(
      context,
      'Replacement uploaded. AI analysis is still running. Check Evaluations for updates.',
      success: true,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final remarks = widget.evaluation.adminRemarks?.trim() ?? '';
    final canUpload = widget.evaluation.canSubmitLinkedReplacement && !_uploading;

    return Scaffold(
      backgroundColor: kEvalBg,
      appBar: AppBar(
        backgroundColor: kEvalBg,
        foregroundColor: kDashTextPrimary,
        elevation: 0,
        title: Text(
          'Re-upload Media',
          style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ),
      ),
      body: SingleChildScrollView(
        padding: mobileScrollPadding(context, top: 8, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Re-upload Required',
                    style: dashText(TextStyle(color: kAccent, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your replacement will link to the same evaluation history as "${widget.evaluation.title}". '
                    'XP is only shown when the server confirms it after review.',
                    style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              AdminReviewRemarksPanel(remarks: remarks),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: evalCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Original submission', style: evalSectionTitleStyle.copyWith(fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(widget.evaluation.title, style: evalBodyStyle.copyWith(fontWeight: FontWeight.w700)),
                  if (widget.evaluation.date.isNotEmpty)
                    Text(widget.evaluation.date, style: evalSectionSubtitleStyle.copyWith(fontSize: 11)),
                ],
              ),
            ),
            if (_loadingChain)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: kAccent)),
              )
            else if (_chain != null) ...[
              const SizedBox(height: 12),
              SubmissionChainHistoryPanel(history: _chain!),
            ],
            if (widget.evaluation.hasActiveReplacementInChain) ...[
              const SizedBox(height: 12),
              Text(
                'A replacement is already being reviewed. Wait for an administrator decision before uploading again.',
                style: TextStyle(color: kYellow.withValues(alpha: 0.95), fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
            Text('Replacement file', style: evalSectionTitleStyle.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            if (_media != null)
              Text(
                _media!.name,
                style: evalBodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading
                  ? null
                  : () {
                      if (_isVideoOriginal) {
                        unawaited(_pickVideo());
                      } else {
                        unawaited(_pickPhoto());
                      }
                    },
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_isVideoOriginal ? 'Choose replacement video' : 'Choose replacement photo'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: kRed, fontSize: 12, height: 1.35)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: canUpload ? () => unawaited(_submit()) : null,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_uploading ? 'Uploading…' : 'Submit replacement'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openReplacementUpload(BuildContext context, {required Evaluation evaluation}) {
  if (!MemberReviewStatus.isReuploadRequested(evaluation.reviewStatus)) return;
  Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ReplacementUploadScreen(evaluation: evaluation),
    ),
  );
}
