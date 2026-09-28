import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Full-screen media inspector with pinch/zoom for admin integrity review.
Future<void> showAdminMediaLightbox(
  BuildContext context, {
  required String url,
  String? title,
  bool isVideo = false,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => _AdminMediaLightboxDialog(
      url: url,
      title: title,
      isVideo: isVideo,
    ),
  );
}

class _AdminMediaLightboxDialog extends StatelessWidget {
  const _AdminMediaLightboxDialog({
    required this.url,
    this.title,
    required this.isVideo,
  });

  final String url;
  final String? title;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Media preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isVideo
                              ? 'Use video controls for playback'
                              : 'Pinch or scroll to zoom · Drag to pan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(
              child: isVideo
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _NetworkVideoPlayer(url: url),
                        ),
                      ),
                    )
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 6,
                      panEnabled: true,
                      scaleEnabled: true,
                      clipBehavior: Clip.none,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkVideoPlayer extends StatelessWidget {
  const _NetworkVideoPlayer({required this.url});

  final String url;

  Future<void> _openVideo() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: AdminTheme.contentBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, size: 48, color: AdminTheme.textSecondary),
              const SizedBox(height: 8),
              const Text(
                'Open the video in a new tab for full playback controls.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openVideo,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
