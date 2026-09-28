import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/notification_navigation.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/mobile_app/widgets/eval_local_video.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Thumbnail for gallery tiles — loads video first frames when possible.
class GalleryMediaThumbnail extends StatelessWidget {
  const GalleryMediaThumbnail({
    super.key,
    this.url,
    required this.isVideo,
    this.memoryBytes,
    this.fallbackIconColor,
    this.fallbackIconSize = 36,
  });

  final String? url;
  final bool isVideo;
  final Uint8List? memoryBytes;
  final Color? fallbackIconColor;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return EvaluationMediaThumbnail(
          imageUrl: url,
          mediaType: isVideo ? 'video' : 'photo',
          memoryBytes: memoryBytes,
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          fallbackIconColor: fallbackIconColor ?? kAccent,
          fallbackIconSize: fallbackIconSize,
        );
      },
    );
  }
}

/// Opens the evaluation report when available, otherwise the raw media viewer.
Future<void> openPortfolioGalleryItem(
  BuildContext context,
  GalleryItem item, {
  VoidCallback? onViewPortfolio,
}) async {
  Evaluation? match;
  if (item.mediaId != null) {
    match = evaluationForMediaId(item.mediaId!);
  }
  if (match == null && item.mediaId != null) {
    await memberDataController.refreshEvaluationsTab();
    if (!context.mounted) return;
    match = evaluationForMediaId(item.mediaId!);
  }
  if (!context.mounted) return;

  if (match != null) {
    openEvaluationReport(context, match, allEvaluations: appState.evaluations);
    return;
  }

  if (item.networkUrl != null && item.networkUrl!.trim().isNotEmpty) {
    openGalleryItemMedia(context, item);
    return;
  }

  onViewPortfolio?.call();
}

/// Opens a saved portfolio item (photo or video) in a full-screen viewer.
void openGalleryItemMedia(BuildContext context, GalleryItem item) {
  final url = item.networkUrl?.trim();
  if (item.isVideo && url != null && url.isNotEmpty) {
    openEvalNetworkVideoViewer(context, videoUrl: url, title: item.title);
    return;
  }

  if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(item.title, style: const TextStyle(fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(item.imageBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
    return;
  }

  if (url != null && url.isNotEmpty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(item.title, style: const TextStyle(fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
