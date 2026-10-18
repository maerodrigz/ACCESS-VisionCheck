import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Photo network image or first-frame JPEG for evaluation videos.
class EvaluationMediaThumbnail extends StatefulWidget {
  const EvaluationMediaThumbnail({
    super.key,
    this.imageUrl,
    this.mediaType,
    this.memoryBytes,
    required this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIconColor,
    this.fallbackIconSize = 36,
    this.storageRemoved = false,
  });

  final String? imageUrl;
  final bool storageRemoved;
  final String? mediaType;
  final Uint8List? memoryBytes;
  final double height;
  final double width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? fallbackIconColor;
  final double fallbackIconSize;

  static bool isVideoMedia({String? mediaType, String? url}) {
    if (mediaType == 'video') return true;
    final lower = (url ?? '').split('?').first.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  @override
  State<EvaluationMediaThumbnail> createState() => _EvaluationMediaThumbnailState();
}

class _EvaluationMediaThumbnailState extends State<EvaluationMediaThumbnail> {
  static final _videoFrameCache = <String, Uint8List>{};

  Uint8List? _videoFrame;
  bool _loadingVideo = false;

  bool get _isVideo =>
      EvaluationMediaThumbnail.isVideoMedia(mediaType: widget.mediaType, url: widget.imageUrl);

  @override
  void initState() {
    super.initState();
    if (_isVideo && !kIsWeb) {
      _loadVideoFrame();
    }
  }

  @override
  void didUpdateWidget(covariant EvaluationMediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.mediaType != widget.mediaType) {
      _videoFrame = null;
      if (_isVideo && !kIsWeb) {
        _loadVideoFrame();
      }
    }
  }

  Future<void> _loadVideoFrame() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;

    final cached = _videoFrameCache[url];
    if (cached != null) {
      if (mounted) setState(() => _videoFrame = cached);
      return;
    }

    setState(() => _loadingVideo = true);
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 80,
        timeMs: 400,
      );
      if (bytes != null && bytes.isNotEmpty) {
        _videoFrameCache[url] = bytes;
        if (mounted) {
          setState(() {
            _videoFrame = bytes;
            _loadingVideo = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingVideo = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.fallbackIconColor ?? kAccent;
    final radius = widget.borderRadius;

    if (widget.storageRemoved) {
      var removed = _storageRemovedPlaceholder(accent);
      removed = SizedBox(width: widget.width, height: widget.height, child: removed);
      if (radius != null) {
        removed = ClipRRect(borderRadius: radius, child: removed);
      }
      return removed;
    }

    Widget child;
    if (_isVideo) {
      if (_videoFrame != null) {
        child = Image.memory(_videoFrame!, width: widget.width, height: widget.height, fit: widget.fit);
      } else if (_loadingVideo) {
        child = ColoredBox(
          color: kSurfaceAlt,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent.withValues(alpha: 0.75)),
            ),
          ),
        );
      } else {
        child = _fallback(accent);
      }
    } else if (widget.memoryBytes != null && widget.memoryBytes!.isNotEmpty) {
      child = Image.memory(
        widget.memoryBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      child = Image.network(
        widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, image, progress) {
          if (progress == null) return image;
          return ColoredBox(
            color: kSurfaceAlt,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent.withValues(alpha: 0.75),
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _fallback(accent),
      );
    } else {
      child = _fallback(accent);
    }

    child = SizedBox(width: widget.width, height: widget.height, child: child);
    if (radius != null) {
      child = ClipRRect(borderRadius: radius, child: child);
    }
    return child;
  }

  Widget _fallback(Color accent) {
    return ColoredBox(
      color: kSurfaceAlt,
      child: Center(
        child: Icon(
          _isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
          color: accent,
          size: widget.fallbackIconSize,
        ),
      ),
    );
  }

  Widget _storageRemovedPlaceholder(Color accent) {
    return ColoredBox(
      color: kSurfaceAlt,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, color: kTextSecondary, size: widget.fallbackIconSize * 0.85),
              const SizedBox(height: 4),
              Text(
                'File removed',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
