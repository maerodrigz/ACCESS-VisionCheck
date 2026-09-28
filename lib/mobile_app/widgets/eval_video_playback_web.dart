import 'dart:html' as html;
import 'dart:typed_data';

import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createEvalVideoController({
  required Uint8List bytes,
  String? filePath,
  String? fileName,
}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final controller = VideoPlayerController.networkUrl(Uri.parse(url));
  await controller.initialize();
  return controller;
}
