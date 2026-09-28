import 'dart:typed_data';

import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/services/image_quality_analyzer.dart';

/// Basic file checks only — does not block normal event photos for blur/lighting.
class ImageValidationService {
  ImageValidationService._();

  static const _maxBytes = 25 * 1024 * 1024;

  static Future<ImageValidationResult> validate({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      return ImageValidationResult.hardReject(['Empty file']);
    }

    if (bytes.length > _maxBytes) {
      return ImageValidationResult.hardReject(['File is too large to read']);
    }

    if (isBlankOrCorrupt(bytes)) {
      return ImageValidationResult.hardReject([
        'File is corrupted, blank, or not a readable image',
      ]);
    }

    final metrics = analyzeImageBytes(bytes);
    if (metrics == null) {
      return ImageValidationResult.hardReject(['Unsupported or corrupted image format']);
    }

    final warnings = _advisoryWarnings(metrics);
    return ImageValidationResult.accepted(qualityWarnings: warnings);
  }

  static List<String> _advisoryWarnings(ImageQualityMetrics m) {
    final warnings = <String>[];
    if (m.width < 320 || m.height < 240) {
      warnings.add('Low resolution. A higher-resolution photo may score better.');
    }
    if (m.blurScore < 0.22) {
      warnings.add('Some blur detected. Try holding the camera steadier.');
    }
    if (m.brightness < 0.18) {
      warnings.add('Photo is quite dark. More light would improve detail.');
    }
    if (m.brightness > 0.88) {
      warnings.add('Photo may be overexposed. Highlights could be washed out.');
    }
    if (m.contrast < 0.12) {
      warnings.add('Low contrast. Subject may look flat.');
    }
    return warnings;
  }
}
