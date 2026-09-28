import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

String _extensionFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot >= name.length - 1) return 'mp4';
  return name.substring(dot + 1).toLowerCase();
}

Future<VideoPlayerController> createEvalVideoController({
  required Uint8List bytes,
  String? filePath,
  String? fileName,
}) async {
  if (filePath != null && filePath.isNotEmpty) {
    final file = File(filePath);
    if (await file.exists()) {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      return controller;
    }
  }

  final dir = await getTemporaryDirectory();
  final ext = _extensionFromName(fileName ?? 'video.mp4');
  final tempFile = File(
    '${dir.path}/eval_preview_${DateTime.now().millisecondsSinceEpoch}.$ext',
  );
  await tempFile.writeAsBytes(bytes, flush: true);
  final controller = VideoPlayerController.file(tempFile);
  await controller.initialize();
  return controller;
}
