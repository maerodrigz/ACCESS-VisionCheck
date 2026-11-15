import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_playback_diagnostics.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_preview_gate.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_media_display_url.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Photo network image or first-frame preview for evaluation videos.
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
  VideoPlayerController? _previewController;
  bool _loadingVideo = false;
  bool _previewFailed = false;
  bool _usedLivePreviewController = false;
  int _loadGeneration = 0;

  bool get _isVideo =>
      EvaluationMediaThumbnail.isVideoMedia(mediaType: widget.mediaType, url: widget.imageUrl);

  @override
  void initState() {
    super.initState();
    EvalVideoPreviewGate.instance.addListener(_onPreviewGateChanged);
    if (_isVideo && !kIsWeb) {
      _loadVideoPreview();
    }
  }

  @override
  void didUpdateWidget(covariant EvaluationMediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.mediaType != widget.mediaType) {
      _disposePreviewController();
      _videoFrame = null;
      _previewFailed = false;
      _usedLivePreviewController = false;
      if (_isVideo && !kIsWeb) {
        _loadVideoPreview();
      }
    }
  }

  void _onPreviewGateChanged() {
    if (!_isVideo || kIsWeb) return;
    if (EvalVideoPreviewGate.instance.previewsSuspended) {
      // Release bandwidth while full-screen playback is active. Keep JPEG frame.
      if (_previewController != null) {
        evalVideoDiag('preview_suspend', fields: {'had_live_controller': true});
        _disposePreviewController();
        if (mounted) setState(() {});
      }
      return;
    }
    // Restore only when we previously needed a live controller and have no JPEG.
    if (_usedLivePreviewController &&
        _videoFrame == null &&
        _previewController == null &&
        !_loadingVideo) {
      evalVideoDiag('preview_restore');
      _loadVideoPreview();
    }
  }

  void _disposePreviewController() {
    final c = _previewController;
    _previewController = null;
    c?.dispose();
  }

  Future<void> _loadVideoPreview() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;
    if (EvalVideoPreviewGate.instance.previewsSuspended) {
      // Full-screen player owns bandwidth; show cache or placeholder only.
      final cached = _videoFrameCache[url];
      if (cached != null && mounted) {
        setState(() {
          _videoFrame = cached;
          _loadingVideo = false;
          _previewFailed = false;
        });
      }
      return;
    }

    final cached = _videoFrameCache[url];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _videoFrame = cached;
          _loadingVideo = false;
          _previewFailed = false;
        });
      }
      return;
    }

    final generation = ++_loadGeneration;
    setState(() {
      _loadingVideo = true;
      _previewFailed = false;
    });

    try {
      final playable = await resolveMemberMediaPlayableUri(
        url,
        bearerToken: authController.user?.token,
      );
      if (!mounted || generation != _loadGeneration) return;
      if (EvalVideoPreviewGate.instance.previewsSuspended) {
        setState(() => _loadingVideo = false);
        return;
      }

      // Public / signed HTTPS: VideoThumbnail can fetch without JWT.
      if (!playable.usesAuthHeaders) {
        final bytes = await VideoThumbnail.thumbnailData(
          video: playable.uri.toString(),
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          quality: 80,
          timeMs: 400,
        );
        if (!mounted || generation != _loadGeneration) return;
        if (bytes != null && bytes.isNotEmpty) {
          _videoFrameCache[url] = bytes;
          _usedLivePreviewController = false;
          setState(() {
            _videoFrame = bytes;
            _loadingVideo = false;
            _previewFailed = false;
          });
          return;
        }
      }

      if (EvalVideoPreviewGate.instance.previewsSuspended) {
        setState(() => _loadingVideo = false);
        return;
      }

      // Authenticated API stream (or thumbnail failure): real first frame via video_player.
      _usedLivePreviewController = true;
      final controller = VideoPlayerController.networkUrl(
        playable.uri,
        httpHeaders: playable.httpHeaders,
      );
      await controller.initialize();
      if (!mounted || generation != _loadGeneration || EvalVideoPreviewGate.instance.previewsSuspended) {
        await controller.dispose();
        if (mounted && generation == _loadGeneration) {
          setState(() => _loadingVideo = false);
        }
        return;
      }
      await controller.setVolume(0);
      await controller.pause();
      await controller.seekTo(Duration.zero);
      _disposePreviewController();
      setState(() {
        _previewController = controller;
        _loadingVideo = false;
        _previewFailed = false;
      });
    } catch (_) {
      _disposePreviewController();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loadingVideo = false;
          _previewFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    EvalVideoPreviewGate.instance.removeListener(_onPreviewGateChanged);
    _disposePreviewController();
    super.dispose();
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
      final preview = _previewController;
      if (_videoFrame != null) {
        child = Image.memory(_videoFrame!, width: widget.width, height: widget.height, fit: widget.fit);
      } else if (preview != null && preview.value.isInitialized) {
        child = ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: preview.value.size.width,
              height: preview.value.size.height,
              child: VideoPlayer(preview),
            ),
          ),
        );
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
        child = _fallback(accent, failed: _previewFailed);
      }
    } else if (widget.memoryBytes != null && widget.memoryBytes!.isNotEmpty) {
      child = Image.memory(
        widget.memoryBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      final headers = memberMediaImageHeaders(
        widget.imageUrl!,
        bearerToken: authController.user?.token,
      );
      child = Image.network(
        widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: headers,
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

  Widget _fallback(Color accent, {bool failed = false}) {
    return ColoredBox(
      color: kSurfaceAlt,
      child: Center(
        child: Icon(
          failed
              ? Icons.videocam_off_outlined
              : (_isVideo ? Icons.videocam_rounded : Icons.photo_rounded),
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
