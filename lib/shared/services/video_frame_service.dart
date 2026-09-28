import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

/// Extracts representative frames from a video for EfficientNet-B0 analysis.
abstract final class VideoFrameService {
  static const _sampleTimesMs = [0, 800, 1600, 2400, 3200, 4000];

  static Future<List<Uint8List>> extractFrames(String videoPath, {int maxFrames = 6}) async {
    final frames = <Uint8List>[];
    final times = _sampleTimesMs.take(maxFrames);

    for (final timeMs in times) {
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 960,
          quality: 85,
          timeMs: timeMs,
        );
        if (bytes != null && bytes.isNotEmpty) {
          frames.add(bytes);
        }
      } catch (_) {
        // Skip unreadable timestamps; continue with other frames.
      }
    }
    return frames;
  }
}
