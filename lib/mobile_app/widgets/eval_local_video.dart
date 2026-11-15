import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:access_mobile/mobile_app/widgets/eval_video_playback_chrome.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_playback_diagnostics.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_playback_stub.dart'
    if (dart.library.io) 'package:access_mobile/mobile_app/widgets/eval_video_playback_io.dart'
    if (dart.library.html) 'package:access_mobile/mobile_app/widgets/eval_video_playback_web.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_preview_gate.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_media_display_url.dart';

/// Shared preview frame for upload confirmation and evaluation result.
const kEvalPreviewAspectRatio = 16 / 8.8;

String _formatEvalMediaDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds <= 0) return '';
  final minutes = duration.inMinutes;
  final seconds = totalSeconds % 60;
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
  if (minutes > 0) {
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  return '0:${seconds.toString().padLeft(2, '0')}';
}

/// Reads duration from a locally picked evaluation video.
Future<Duration?> detectEvalVideoDuration({
  required Uint8List bytes,
  String? filePath,
  String? fileName,
}) async {
  VideoPlayerController? controller;
  try {
    controller = await createEvalVideoController(
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
    );
    if (!controller.value.isInitialized) return null;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return null;
    return duration;
  } catch (_) {
    return null;
  } finally {
    await controller?.dispose();
  }
}

/// Reads width, height, and duration from a locally picked evaluation video.
Future<String?> detectEvalVideoResolution({
  required Uint8List bytes,
  String? filePath,
  String? fileName,
}) async {
  VideoPlayerController? controller;
  try {
    controller = await createEvalVideoController(
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
    );
    if (!controller.value.isInitialized) return null;

    final size = controller.value.size;
    final parts = <String>[];
    if (size.width > 0 && size.height > 0) {
      parts.add('${size.width.round()} × ${size.height.round()} px');
    }
    final durationLabel = _formatEvalMediaDuration(controller.value.duration);
    if (durationLabel.isNotEmpty) {
      parts.add(durationLabel);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  } catch (_) {
    return null;
  } finally {
    await controller?.dispose();
  }
}

void openEvalPhotoPreviewViewer(
  BuildContext context, {
  required Uint8List bytes,
  required String title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, style: const TextStyle(fontSize: 14)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

/// Photo preview with tap-to-zoom before evaluation.
class EvalPhotoPreviewTile extends StatelessWidget {
  const EvalPhotoPreviewTile({
    super.key,
    required this.bytes,
    required this.fileName,
    this.aspectRatio = 16 / 10,
    this.showFullImage = false,
    this.showTapHint = true,
    this.onTap,
  });

  final Uint8List bytes;
  final String fileName;
  final double aspectRatio;
  /// When true, the entire image is shown inside the frame (letterboxed, no crop).
  final bool showFullImage;
  /// Bottom-left chip (e.g. "Tap to zoom"). Hide when the screen has its own action button.
  final bool showTapHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageFit = showFullImage ? BoxFit.contain : BoxFit.cover;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        color: showFullImage ? kBg : Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () => openEvalPhotoPreviewViewer(
                    context,
                    bytes: bytes,
                    title: fileName,
                  ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showFullImage)
                Center(child: Image.memory(bytes, fit: imageFit))
              else
                Image.memory(bytes, fit: imageFit),
              if (!showFullImage)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.35],
                    ),
                  ),
                ),
              if (showTapHint)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to zoom',
                          style: dashText(const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail with a play badge; tap opens full-screen local video playback.
class EvalVideoPreviewTile extends StatelessWidget {
  const EvalVideoPreviewTile({
    super.key,
    required this.bytes,
    required this.fileName,
    this.filePath,
    this.previewBytes,
    this.aspectRatio = 16 / 10,
    this.showFullThumbnail = false,
    this.onTap,
  });

  final Uint8List bytes;
  final String fileName;
  final String? filePath;
  final Uint8List? previewBytes;
  final double aspectRatio;
  /// Letterbox thumbnail frame (matches photo [showFullImage] on result screens).
  final bool showFullThumbnail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = previewBytes != null
        ? (showFullThumbnail
            ? ColoredBox(
                color: kBg,
                child: Center(child: Image.memory(previewBytes!, fit: BoxFit.contain)),
              )
            : Image.memory(previewBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
        : Container(
            color: kEvalSecondaryLight,
            child: const Center(
              child: Icon(Icons.videocam_rounded, color: kEvalSecondary, size: 56),
            ),
          );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => openEvalLocalVideoViewer(
                context,
                bytes: bytes,
                fileName: fileName,
                filePath: filePath,
              ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumbnail,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
              const Center(child: EvalVideoPlayBadge(onDarkBackground: true)),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to preview',
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EvalVideoPlayBadge extends StatelessWidget {
  const EvalVideoPlayBadge({super.key, this.onDarkBackground = false});

  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: onDarkBackground
            ? Colors.black.withValues(alpha: 0.45)
            : kEvalSecondary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: onDarkBackground ? Colors.white.withValues(alpha: 0.85) : kEvalSecondary.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: onDarkBackground ? 0.35 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: 36,
        color: onDarkBackground ? Colors.white : kEvalSecondary,
      ),
    );
  }
}

void openEvalLocalVideoViewer(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  String? filePath,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EvalLocalVideoViewerScreen(
        bytes: bytes,
        fileName: fileName,
        filePath: filePath,
      ),
    ),
  );
}

/// Thumbnail for a saved/server-hosted evaluation video with play affordance.
class EvalNetworkVideoPreviewTile extends StatelessWidget {
  const EvalNetworkVideoPreviewTile({
    super.key,
    required this.videoUrl,
    required this.title,
    this.mediaType,
    this.onTap,
    this.interactive = true,
  });

  final String videoUrl;
  final String title;
  final String? mediaType;
  final VoidCallback? onTap;
  /// When false, shows play chrome only (use explicit action buttons for playback).
  final bool interactive;

  Widget _previewStack(BoxConstraints constraints) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EvaluationMediaThumbnail(
          imageUrl: videoUrl,
          mediaType: mediaType ?? 'video',
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          fallbackIconColor: kEvalSecondary,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.32),
              ],
            ),
          ),
        ),
        const Center(child: EvalVideoPlayBadge(onDarkBackground: true)),
        if (interactive)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Tap to play',
                    style: dashText(const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preview = _previewStack(constraints);
        if (!interactive) {
          return Material(color: Colors.transparent, child: preview);
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ??
                () => openEvalNetworkVideoViewer(
                      context,
                      videoUrl: videoUrl,
                      title: title,
                    ),
            child: preview,
          ),
        );
      },
    );
  }
}

Future<void> openEvalNetworkVideoViewer(
  BuildContext context, {
  required String videoUrl,
  required String title,
  String? integrityReviewNotice,
}) async {
  if (videoUrl.trim().isEmpty) return;
  // Suspend report/list preview controllers so only one player uses bandwidth.
  EvalVideoPreviewGate.instance.beginFullscreenPlayback();
  evalVideoDiag('viewer_open');
  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EvalNetworkVideoViewerScreen(
          videoUrl: videoUrl,
          title: title,
          integrityReviewNotice: integrityReviewNotice,
        ),
      ),
    );
  } finally {
    EvalVideoPreviewGate.instance.endFullscreenPlayback();
    evalVideoDiag('viewer_close');
  }
}

/// Full-screen player for saved evaluation videos hosted on the API.
class EvalNetworkVideoViewerScreen extends StatefulWidget {
  const EvalNetworkVideoViewerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.integrityReviewNotice,
  });

  final String videoUrl;
  final String title;
  final String? integrityReviewNotice;

  @override
  State<EvalNetworkVideoViewerScreen> createState() => _EvalNetworkVideoViewerScreenState();
}

class _EvalNetworkVideoViewerScreenState extends State<EvalNetworkVideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _error = false;
  String? _errorDetail;
  bool _showControls = true;
  int _initGeneration = 0;
  bool _wasBuffering = false;
  DateTime? _initStartedAt;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  EvalVideoChromeKind get _chromeKind {
    final v = _controller?.value;
    return evalVideoChromeKind(
      loading: _loading,
      error: _error,
      initialized: v?.isInitialized ?? false,
      isPlaying: v?.isPlaying ?? false,
      isBuffering: v?.isBuffering ?? false,
    );
  }

  void _onControllerTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final buffering = c.value.isBuffering;
    if (buffering != _wasBuffering) {
      evalVideoDiag(
        buffering ? 'buffering_start' : 'buffering_end',
        fields: {
          'position_ms': c.value.position.inMilliseconds,
          'playing': c.value.isPlaying,
        },
      );
      _wasBuffering = buffering;
    }
    setState(() {});
  }

  Future<void> _initPlayer() async {
    final generation = ++_initGeneration;
    _initStartedAt = DateTime.now();
    evalVideoDiag('init_start');
    setState(() {
      _loading = true;
      _error = false;
      _errorDetail = null;
      _wasBuffering = false;
    });
    final previous = _controller;
    if (previous != null) {
      previous.removeListener(_onControllerTick);
      _controller = null;
      await previous.dispose();
    }

    try {
      // Follow 307 signed-URL redirects without forwarding JWT; keep JWT only
      // when the stream serves local FileResponse (200/206).
      final playable = await resolveMemberMediaPlayableUri(
        widget.videoUrl,
        bearerToken: authController.user?.token,
      );
      if (!mounted || generation != _initGeneration) return;

      final controller = VideoPlayerController.networkUrl(
        playable.uri,
        httpHeaders: playable.httpHeaders,
      );
      await controller.initialize();
      if (!mounted || generation != _initGeneration) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      controller.addListener(_onControllerTick);
      final initMs = _initStartedAt == null
          ? null
          : DateTime.now().difference(_initStartedAt!).inMilliseconds;
      evalVideoDiag(
        'init_ok',
        fields: {
          'init_ms': initMs,
          'duration_ms': controller.value.duration.inMilliseconds,
        },
      );
      setState(() {
        _controller = controller;
        _loading = false;
        _error = false;
        _errorDetail = null;
      });
      // Single play() after init. Do not re-call while buffering.
      await controller.play();
      evalVideoDiag('play_issued', fields: {'position_ms': 0});
    } catch (e) {
      evalVideoDiag('init_error', fields: {'type': e.runtimeType.toString()});
      if (mounted && generation == _initGeneration) {
        setState(() {
          _loading = false;
          _error = true;
          _errorDetail = 'Unable to play this video. Check your connection and try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _initGeneration++;
    final c = _controller;
    _controller = null;
    c?.removeListener(_onControllerTick);
    c?.dispose();
    evalVideoDiag('viewer_dispose');
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final playing = c.value.isPlaying;
    final buffering = c.value.isBuffering;
    if (playing) {
      if (!evalVideoShouldIssuePause(isPlaying: true, userWantsPause: true)) return;
      evalVideoDiag(
        'pause',
        fields: {'position_ms': c.value.position.inMilliseconds, 'buffering': buffering},
      );
      c.pause();
      setState(() {});
      return;
    }
    // Do not spam play() while already playing+buffering.
    if (!evalVideoShouldIssuePlay(
      isPlaying: playing,
      isBuffering: buffering,
      userWantsPlay: true,
    )) {
      return;
    }
    evalVideoDiag(
      'play',
      fields: {'position_ms': c.value.position.inMilliseconds, 'buffering': buffering},
    );
    c.play();
    setState(() {});
  }

  String _positionLabel(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.integrityReviewNotice?.trim();
    final chrome = _chromeKind;
    final showSpinner = evalVideoShowBufferingSpinner(chrome);
    final showPlayBadge = _showControls && evalVideoShowPlayBadge(chrome);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null && notice.isNotEmpty) EvalViewerIntegrityNotice(text: notice),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_error)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            _errorDetail ??
                                'Unable to load this video. Check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: dashText(const TextStyle(color: Colors.white70, fontSize: 14)),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _loading ? null : _initPlayer,
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            label: const Text('Retry', style: TextStyle(color: Colors.white)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_controller != null && _controller!.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  if (showSpinner && !_error)
                    const Center(child: CircularProgressIndicator(color: Colors.white70)),
                  if (!_loading && !_error && _controller != null && _showControls)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _VideoControlsBar(
                        controller: _controller!,
                        onTogglePlay: _togglePlay,
                        positionLabel: _positionLabel,
                        chromeKind: chrome,
                      ),
                    ),
                  if (showPlayBadge) const EvalVideoPlayBadge(onDarkBackground: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown above full-screen evaluation media when integrity review is pending.
class EvalViewerIntegrityNotice extends StatelessWidget {
  const EvalViewerIntegrityNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF422006),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFFFBBF24), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why admin review is required',
                    style: dashText(const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: dashText(const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen player for a locally picked evaluation video (bytes or file path).
class EvalLocalVideoViewerScreen extends StatefulWidget {
  const EvalLocalVideoViewerScreen({
    super.key,
    required this.bytes,
    required this.fileName,
    this.filePath,
  });

  final Uint8List bytes;
  final String fileName;
  final String? filePath;

  @override
  State<EvalLocalVideoViewerScreen> createState() => _EvalLocalVideoViewerScreenState();
}

class _EvalLocalVideoViewerScreenState extends State<EvalLocalVideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = await createEvalVideoController(
        bytes: widget.bytes,
        filePath: widget.filePath,
        fileName: widget.fileName,
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      setState(() {
        _controller = controller;
        _loading = false;
        _error = false;
      });
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  String _positionLabel(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.fileName, style: const TextStyle(fontSize: 14)),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              )
            else if (_error)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to play this video on device.',
                      textAlign: TextAlign.center,
                      style: dashText(const TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                  ],
                ),
              )
            else if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            if (!_loading && !_error && _controller != null && _showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _VideoControlsBar(
                  controller: _controller!,
                  onTogglePlay: _togglePlay,
                  positionLabel: _positionLabel,
                ),
              ),
            if (!_loading && !_error && _controller != null && _showControls && !_controller!.value.isPlaying)
              const EvalVideoPlayBadge(onDarkBackground: true),
          ],
        ),
      ),
    );
  }
}

class _VideoControlsBar extends StatelessWidget {
  const _VideoControlsBar({
    required this.controller,
    required this.onTogglePlay,
    required this.positionLabel,
    this.chromeKind,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlay;
  final String Function(Duration) positionLabel;
  final EvalVideoChromeKind? chromeKind;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final value = controller.value;
        if (!value.isInitialized) return const SizedBox.shrink();

        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds.clamp(0, durationMs > 0 ? durationMs : 0);
        final progress = durationMs > 0 ? positionMs / durationMs : 0.0;
        final kind = chromeKind ??
            evalVideoChromeKind(
              loading: false,
              error: false,
              initialized: true,
              isPlaying: value.isPlaying,
              isBuffering: value.isBuffering,
            );
        final showPauseIcon =
            kind == EvalVideoChromeKind.playing || kind == EvalVideoChromeKind.buffering;

        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: kEvalPrimary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: durationMs > 0
                      ? (v) {
                          controller.seekTo(Duration(milliseconds: (v * durationMs).round()));
                        }
                      : null,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onTogglePlay,
                    icon: Icon(
                      showPauseIcon ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (kind == EvalVideoChromeKind.buffering) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buffering',
                      style: dashText(const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    '${positionLabel(value.position)} / ${positionLabel(value.duration)}',
                    style: dashText(const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
