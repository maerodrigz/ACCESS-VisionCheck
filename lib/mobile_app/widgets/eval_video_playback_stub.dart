import 'dart:typed_data';

import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createEvalVideoController({
  required Uint8List bytes,
  String? filePath,
  String? fileName,
}) {
  throw UnsupportedError('Video playback is not supported on this platform.');
}
