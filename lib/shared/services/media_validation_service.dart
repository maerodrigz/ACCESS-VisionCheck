import 'dart:typed_data';

import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/services/image_quality_analyzer.dart';
import 'package:access_mobile/shared/services/video_frame_service.dart';

/// Validates photo and video files before AI evaluation.
abstract final class MediaValidationService {
  static const _maxPhotoBytes = 25 * 1024 * 1024;
  static const _maxVideoBytes = 120 * 1024 * 1024;

  static const _videoExtensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp', '.m4v'};

  static bool isVideoFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return _videoExtensions.any(lower.endsWith);
  }

  static Future<MediaValidationResult> validatePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      return MediaValidationResult.hardReject('Empty file', mediaType: 'photo');
    }
    if (bytes.length > _maxPhotoBytes) {
      return MediaValidationResult.hardReject('Photo is too large (max 25 MB)', mediaType: 'photo');
    }
    if (isBlankOrCorrupt(bytes)) {
      return MediaValidationResult.hardReject(
        'File is corrupted, blank, or not a readable image',
        mediaType: 'photo',
      );
    }
    final metrics = analyzeImageBytes(bytes);
    if (metrics == null) {
      return MediaValidationResult.hardReject('Unsupported or corrupted image format', mediaType: 'photo');
    }
    return MediaValidationResult.accepted(
      mediaType: 'photo',
      qualityWarnings: _photoWarnings(metrics),
    );
  }

  static Future<MediaValidationResult> validateVideo({
    required String filePath,
    required String fileName,
    required int byteLength,
  }) async {
    if (byteLength == 0) {
      return MediaValidationResult.hardReject('Empty video file', mediaType: 'video');
    }
    if (byteLength > _maxVideoBytes) {
      return MediaValidationResult.hardReject('Video is too large (max 120 MB)', mediaType: 'video');
    }
    if (!isVideoFileName(fileName)) {
      return MediaValidationResult.hardReject('Unsupported video format', mediaType: 'video');
    }

    final frames = await VideoFrameService.extractFrames(filePath, maxFrames: 2);
    if (frames.isEmpty) {
      return MediaValidationResult.hardReject(
        'Could not read frames from this video. Try a shorter MP4 or MOV clip.',
        mediaType: 'video',
      );
    }

    final warnings = <String>[];
    for (final frame in frames) {
      warnings.addAll(_photoWarnings(analyzeImageBytes(frame)));
    }
    return MediaValidationResult.accepted(
      mediaType: 'video',
      qualityWarnings: warnings.toSet().toList(),
    );
  }

  static List<String> _photoWarnings(ImageQualityMetrics? m) {
    if (m == null) return const [];
    final warnings = <String>[];
    if (m.width < 320 || m.height < 240) {
      warnings.add('Low resolution. Higher resolution may score better.');
    }
    if (m.blurScore < 0.22) {
      warnings.add('Some blur detected. Hold the camera steadier.');
    }
    if (m.brightness < 0.18) {
      warnings.add('Media is quite dark. More light would improve detail.');
    }
    if (m.brightness > 0.88) {
      warnings.add('Media may be overexposed. Highlights could be washed out.');
    }
    if (m.contrast < 0.12) {
      warnings.add('Low contrast. Subject may look flat.');
    }
    return warnings;
  }
}

class MediaValidationResult {
  const MediaValidationResult({
    required this.isValid,
    required this.message,
    required this.mediaType,
    this.qualityWarnings = const [],
    this.hardReject = false,
  });

  final bool isValid;
  final String message;
  final String mediaType;
  final List<String> qualityWarnings;
  final bool hardReject;

  factory MediaValidationResult.accepted({
    required String mediaType,
    List<String> qualityWarnings = const [],
  }) =>
      MediaValidationResult(
        isValid: true,
        mediaType: mediaType,
        message: qualityWarnings.isEmpty
            ? 'Media ready for evaluation.'
            : ImageValidationResult.acceptedWithIssuesMessage,
        qualityWarnings: qualityWarnings,
      );

  factory MediaValidationResult.hardReject(String message, {required String mediaType}) =>
      MediaValidationResult(
        isValid: false,
        hardReject: true,
        mediaType: mediaType,
        message: message,
      );
}
