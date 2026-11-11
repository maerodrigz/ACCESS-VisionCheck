import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Result of an in-app practice video recording (Phase 0, no session binding).
class PracticeVideoCaptureResult {
  const PracticeVideoCaptureResult({
    required this.filePath,
    required this.fileName,
  });

  final String filePath;
  final String fileName;
}

/// In-app mute video recorder for Practice Video Evaluation.
///
/// Does not claim authenticity or capture-session validation.
class PracticeVideoCaptureScreen extends StatefulWidget {
  const PracticeVideoCaptureScreen({
    super.key,
    required this.maxDuration,
  });

  final Duration maxDuration;

  @override
  State<PracticeVideoCaptureScreen> createState() =>
      _PracticeVideoCaptureScreenState();
}

enum _CapturePhase { loading, ready, recording, preview, error }

class _PracticeVideoCaptureScreenState extends State<PracticeVideoCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  VideoPlayerController? _previewPlayer;
  _CapturePhase _phase = _CapturePhase.loading;
  String? _error;
  String? _recordedPath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _busy = false;

  Duration get _maxDuration => widget.maxDuration.inSeconds < 1
      ? const Duration(seconds: 1)
      : widget.maxDuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_disposeCamera());
    unawaited(_disposePreviewPlayer());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_phase == _CapturePhase.recording) {
        unawaited(_stopRecording(interrupted: true));
      }
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _phase = _CapturePhase.loading;
      _error = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _phase = _CapturePhase.error;
        _error = status.isPermanentlyDenied
            ? 'Camera permission is blocked. Enable it in system settings to record.'
            : 'Camera permission is required to record a practice video.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _phase = _CapturePhase.error;
          _error = 'No camera is available on this device.';
        });
        return;
      }

      final rear = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      final description = rear.isNotEmpty ? rear.first : cameras.first;

      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _disposeCamera();
      setState(() {
        _camera = controller;
        _phase = _CapturePhase.ready;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.error;
        _error = e.description?.trim().isNotEmpty == true
            ? e.description!
            : 'Could not start the camera (${e.code}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.error;
        _error = 'Could not initialize the camera. Please try again.';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final c = _camera;
    _camera = null;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _disposePreviewPlayer() async {
    final p = _previewPlayer;
    _previewPlayer = null;
    if (p != null) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  Future<void> _deleteRecordedFile() async {
    final path = _recordedPath;
    _recordedPath = null;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 9999);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    if (camera.value.isRecordingVideo) return;

    setState(() => _busy = true);
    try {
      await camera.startVideoRecording();
      if (!mounted) return;
      _elapsed = Duration.zero;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        final next = _elapsed + const Duration(milliseconds: 200);
        if (next >= _maxDuration) {
          unawaited(_stopRecording(autoStop: true));
          return;
        }
        setState(() => _elapsed = next);
      });
      setState(() {
        _phase = _CapturePhase.recording;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.description?.trim().isNotEmpty == true
            ? e.description!
            : 'Could not start recording.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording({
    bool autoStop = false,
    bool interrupted = false,
  }) async {
    final camera = _camera;
    _timer?.cancel();
    _timer = null;
    if (_busy) return;
    if (camera == null || !camera.value.isRecordingVideo) {
      if (mounted && _phase == _CapturePhase.recording) {
        setState(() => _phase = _CapturePhase.ready);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final file = await camera.stopVideoRecording();
      if (!mounted) {
        try {
          await File(file.path).delete();
        } catch (_) {}
        return;
      }

      // Move into app temp with a stable name for later upload.
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${dir.path}/access_practice_$stamp.mp4';
      final saved = await File(file.path).copy(destPath);
      try {
        if (file.path != destPath) await File(file.path).delete();
      } catch (_) {}

      await _disposePreviewPlayer();
      final player = VideoPlayerController.file(saved);
      await player.initialize();
      await player.setLooping(true);

      if (!mounted) {
        await player.dispose();
        try {
          await saved.delete();
        } catch (_) {}
        return;
      }

      setState(() {
        _recordedPath = saved.path;
        _previewPlayer = player;
        _phase = _CapturePhase.preview;
        _error = interrupted
            ? 'Recording stopped because the app left the foreground.'
            : (autoStop ? 'Maximum duration reached.' : null);
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.ready;
        _error = e.description?.trim().isNotEmpty == true
            ? e.description!
            : 'Could not stop recording.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.ready;
        _error = 'Recording failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retake() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _disposePreviewPlayer();
      await _deleteRecordedFile();
      if (!mounted) return;
      _elapsed = Duration.zero;
      if (_camera == null || !(_camera!.value.isInitialized)) {
        await _bootstrap();
        return;
      }
      setState(() {
        _phase = _CapturePhase.ready;
        _error = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useVideo() async {
    final path = _recordedPath;
    if (path == null || _busy) return;
    final name = path.split(Platform.pathSeparator).last;
    Navigator.of(context).pop(
      PracticeVideoCaptureResult(filePath: path, fileName: name),
    );
  }

  Future<void> _cancel() async {
    if (_busy) return;
    if (_phase == _CapturePhase.recording) {
      await _stopRecording();
    }
    await _disposePreviewPlayer();
    await _deleteRecordedFile();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Record Video', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _busy ? null : () => unawaited(_cancel()),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            if (_error != null && _phase != _CapturePhase.error)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _CapturePhase.loading:
        return const Center(
          child: CircularProgressIndicator(color: kCyan),
        );
      case _CapturePhase.error:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Camera unavailable.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_bootstrap()),
                style: FilledButton.styleFrom(backgroundColor: kAccent),
                child: const Text('Try again'),
              ),
            ],
          ),
        );
      case _CapturePhase.preview:
        final player = _previewPlayer;
        if (player == null || !player.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(color: kCyan));
        }
        return Center(
          child: AspectRatio(
            aspectRatio: player.value.aspectRatio == 0
                ? 9 / 16
                : player.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(player),
                Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 56,
                    color: Colors.white,
                    onPressed: () {
                      if (player.value.isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      player.value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case _CapturePhase.ready:
      case _CapturePhase.recording:
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(color: kCyan));
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(child: CameraPreview(camera)),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kCyan.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_phase == _CapturePhase.recording) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${_formatDuration(_elapsed)} / ${_formatDuration(_maxDuration)}',
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildControls() {
    if (_phase == _CapturePhase.error || _phase == _CapturePhase.loading) {
      return const SizedBox(height: 24);
    }

    if (_phase == _CapturePhase.preview) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => unawaited(_retake()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => unawaited(_useVideo()),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Use Video'),
              ),
            ),
          ],
        ),
      );
    }

    final recording = _phase == _CapturePhase.recording;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          Text(
            recording ? 'Recording… tap stop when finished' : 'Tap to start recording (no audio)',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _busy
                ? null
                : () {
                    if (recording) {
                      unawaited(_stopRecording());
                    } else {
                      unawaited(_startRecording());
                    }
                  },
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: recording ? 28 : 58,
                height: recording ? 28 : 58,
                decoration: BoxDecoration(
                  color: kRed,
                  borderRadius: BorderRadius.circular(recording ? 6 : 29),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
