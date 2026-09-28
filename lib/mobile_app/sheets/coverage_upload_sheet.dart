import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/screens/legal_document_screen.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';

/// Opens the event coverage upload sheet for an assigned documentation request.
Future<void> showCoverageUploadSheet(
  BuildContext context, {
  required int requestId,
  required String eventTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CoverageUploadSheet(
      requestId: requestId,
      eventTitle: eventTitle,
    ),
  );
}

bool memberCanUploadCoverage(Challenge task) {
  if (task.requestId == null) return false;
  final s = task.status.toLowerCase();
  if (s == 'declined' || s == 'cancelled' || s == 'canceled') return false;
  if (s == 'pending_acceptance' || s == 'assigned') return false;
  return s == 'accepted' ||
      s == 'in_progress' ||
      s == 'completed' ||
      s == 'done';
}

bool memberCanUploadCoverageForEvent(CalendarEvent event) {
  if (event.requestId == null) return false;
  if (!memberIsAssignedToEvent(event)) return false;
  final assignment = memberAssignmentForEvent(event);
  if (assignment != null) return memberCanUploadCoverage(assignment);
  return true;
}

class _CoverageUploadSheet extends StatefulWidget {
  const _CoverageUploadSheet({
    required this.requestId,
    required this.eventTitle,
  });

  final int requestId;
  final String eventTitle;

  @override
  State<_CoverageUploadSheet> createState() => _CoverageUploadSheetState();
}

class _CoverageUploadSheetState extends State<_CoverageUploadSheet> {
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();

  bool _isVideo = false;
  bool _uploading = false;
  bool _standardsAccepted = false;
  Uint8List? _bytes;
  String? _fileName;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    if (_isVideo) {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _bytes = bytes;
        _fileName = picked.name;
      });
    } else {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _bytes = bytes;
        _fileName = picked.name;
      });
    }
  }

  Future<void> _pickCamera() async {
    if (kIsWeb || _isVideo) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _bytes = bytes;
      _fileName = picked.name;
    });
  }

  Future<void> _submit() async {
    final bytes = _bytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null || fileName.isEmpty) {
      _toast('Choose a photo or video first.', success: false);
      return;
    }
    if (!_standardsAccepted) {
      _toast('Please confirm this upload meets ACCESS content standards.', success: false);
      return;
    }

    setState(() => _uploading = true);
    try {
      await memberDataController.uploadEventCoverage(
        bytes: bytes,
        fileName: fileName,
        requestId: widget.requestId,
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coverage uploaded for ${widget.eventTitle}'),
          backgroundColor: kGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast(
        e.toString().replaceFirst('ApiException: ', '').trim(),
        success: false,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? kGreen : kRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final hasFile = _bytes != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload event coverage',
              style: memberDashboardSectionTitleStyle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.eventTitle,
              style: memberDashboardMetaStyle.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.photo_outlined, size: 18),
                  label: Text('Photo'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.videocam_outlined, size: 18),
                  label: Text('Video'),
                ),
              ],
              selected: {_isVideo},
              onSelectionChanged: _uploading
                  ? null
                  : (selection) {
                      setState(() {
                        _isVideo = selection.first;
                        _bytes = null;
                        _fileName = null;
                      });
                    },
            ),
            const SizedBox(height: 16),
            if (hasFile)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kGreenDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGreen.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                      color: kGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fileName ?? 'Selected file',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      onPressed: _uploading
                          ? null
                          : () => setState(() {
                                _bytes = null;
                                _fileName = null;
                              }),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: kTextSecondary,
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (!_isVideo && !kIsWeb) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickCamera,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              enabled: !_uploading,
              decoration: InputDecoration(
                labelText: 'Caption (optional)',
                hintText: 'e.g. Opening ceremony highlights',
                filled: true,
                fillColor: kSurfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorder),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _standardsAccepted,
              onChanged: _uploading
                  ? null
                  : (v) => setState(() => _standardsAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: kAccent,
              title: Text(
                'I confirm this file meets ACCESS content standards and is appropriate event coverage.',
                style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
              ),
              subtitle: TextButton(
                onPressed: () => openAccessLegalDocument(
                  context,
                  AccessLegalDocument.contentStandards,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  MemberXpConfig.contentStandardsTitle,
                  style: memberDashboardMetaStyle.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _uploading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                minimumSize: const Size.fromHeight(kMobileMinTouch),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Upload coverage',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
