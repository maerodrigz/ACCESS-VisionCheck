import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/services/gallery_media_download_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Opens a read-only full-screen viewer for approved event gallery media.
void openMemberGalleryMediaViewer(
  BuildContext context, {
  required List<EventGalleryMedia> items,
  required int initialIndex,
  required String eventName,
  DateTime? eventDate,
  bool allowDownload = false,
}) {
  if (items.isEmpty) return;
  final index = initialIndex.clamp(0, items.length - 1);

  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MemberGalleryMediaViewer(
          items: items,
          initialIndex: index,
          eventName: eventName,
          eventDate: eventDate,
          allowDownload: allowDownload,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Full-screen read-only photo/video viewer for the member event gallery.
class MemberGalleryMediaViewer extends StatefulWidget {
  const MemberGalleryMediaViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.eventName,
    this.eventDate,
    this.allowDownload = false,
  });

  final List<EventGalleryMedia> items;
  final int initialIndex;
  final String eventName;
  final DateTime? eventDate;
  final bool allowDownload;

  @override
  State<MemberGalleryMediaViewer> createState() => _MemberGalleryMediaViewerState();
}

class _MemberGalleryMediaViewerState extends State<MemberGalleryMediaViewer> {
  late int _index;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoError = false;
  bool _showVideoControls = true;
  bool _downloading = false;

  EventGalleryMedia get _current => widget.items[_index];

  bool get _canGoPrev => _index > 0;
  bool get _canGoNext => _index < widget.items.length - 1;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _loadCurrentMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMedia() async {
    await _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _videoError = false;
    _showVideoControls = true;

    if (!_current.isVideo) {
      if (mounted) setState(() {});
      return;
    }

    final uri = Uri.tryParse(_current.thumbnailUrl);
    if (uri == null) {
      if (mounted) setState(() => _videoError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _videoReady = true;
        _videoError = false;
      });
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoError = true;
          _videoReady = false;
        });
      }
    }
  }

  String get _dateLabel {
    final d = widget.eventDate ?? _current.eventDate;
    return d != null ? EventGalleryAlbum.formatDate(d) : 'Date TBA';
  }

  String get _uploadedLabel {
    final d = _current.uploadedAt;
    if (d == null) return 'N/A';
    return EventGalleryAlbum.formatDate(d);
  }

  String get _mediaTypeLabel => _current.isVideo ? 'Video' : 'Photo';

  void _close() => Navigator.of(context).maybePop();

  void _goPrev() {
    if (!_canGoPrev) return;
    setState(() => _index--);
    _loadCurrentMedia();
  }

  void _goNext() {
    if (!_canGoNext) return;
    setState(() => _index++);
    _loadCurrentMedia();
  }

  void _toggleVideoPlayback() {
    final c = _videoController;
    if (c == null || !_videoReady) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  void _onVideoTap() {
    setState(() => _showVideoControls = !_showVideoControls);
  }

  Future<void> _saveToDevice() async {
    if (_downloading || !widget.allowDownload || kIsWeb) return;

    setState(() => _downloading = true);
    try {
      await GalleryMediaDownloadService.saveToDevice(_current);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _current.isVideo ? 'Video saved to your gallery.' : 'Photo saved to your gallery.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is UnsupportedError
          ? 'Save to device is not available here.'
          : 'Could not save media. ${e.toString().replaceFirst('Exception: ', '')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNav = widget.items.length > 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _MediaStage(
              item: _current,
              videoController: _videoController,
              videoReady: _videoReady,
              videoError: _videoError,
              onVideoTap: _onVideoTap,
            ),
            _ViewerChrome(
              onClose: _close,
              eventName: widget.eventName,
              dateLabel: _dateLabel,
              uploadedLabel: _uploadedLabel,
              mediaTypeLabel: _mediaTypeLabel,
              showBottomInfo: !_current.isVideo || _showVideoControls,
              indexLabel: showNav ? '${_index + 1} / ${widget.items.length}' : null,
              showDownload: widget.allowDownload && !kIsWeb,
              downloading: _downloading,
              onDownload: _saveToDevice,
            ),
            if (showNav && _canGoPrev)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ChromeIconButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: _goPrev,
                    tooltip: 'Previous',
                  ),
                ),
              ),
            if (showNav && _canGoNext)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ChromeIconButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: _goNext,
                    tooltip: 'Next',
                  ),
                ),
              ),
            if (_current.isVideo && _videoReady && _showVideoControls)
              _VideoPlaybackControls(
                controller: _videoController!,
                onToggle: _toggleVideoPlayback,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaStage extends StatelessWidget {
  const _MediaStage({
    required this.item,
    required this.videoController,
    required this.videoReady,
    required this.videoError,
    required this.onVideoTap,
  });

  final EventGalleryMedia item;
  final VideoPlayerController? videoController;
  final bool videoReady;
  final bool videoError;
  final VoidCallback onVideoTap;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      if (videoError) {
        return const Center(
          child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 64),
        );
      }
      if (!videoReady || videoController == null) {
        return const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
          ),
        );
      }

      return GestureDetector(
        onTap: onVideoTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AspectRatio(
            aspectRatio: videoController!.value.aspectRatio,
            child: VideoPlayer(videoController!),
          ),
        ),
      );
    }

    return Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Image.network(
          item.thumbnailUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
            );
          },
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white38,
            size: 56,
          ),
        ),
      ),
    );
  }
}

class _ViewerChrome extends StatelessWidget {
  const _ViewerChrome({
    required this.onClose,
    required this.eventName,
    required this.dateLabel,
    required this.uploadedLabel,
    required this.mediaTypeLabel,
    required this.showBottomInfo,
    this.indexLabel,
    this.showDownload = false,
    this.downloading = false,
    this.onDownload,
  });

  final VoidCallback onClose;
  final String eventName;
  final String dateLabel;
  final String uploadedLabel;
  final String mediaTypeLabel;
  final bool showBottomInfo;
  final String? indexLabel;
  final bool showDownload;
  final bool downloading;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 16),
                child: Row(
                  children: [
                    _ChromeIconButton(
                      icon: Icons.close_rounded,
                      onPressed: onClose,
                      tooltip: 'Close',
                    ),
                    const Spacer(),
                    if (showDownload)
                      downloading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white70,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : _ChromeIconButton(
                              icon: Icons.download_rounded,
                              onPressed: downloading ? () {} : (onDownload ?? () {}),
                              tooltip: 'Save to device',
                            ),
                    if (showDownload && indexLabel != null) const SizedBox(width: 8),
                    if (indexLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          indexLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showBottomInfo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 16 + bottomInset),
                child: _MediaInfoPanel(
                  eventName: eventName,
                  dateLabel: dateLabel,
                  uploadedLabel: uploadedLabel,
                  mediaTypeLabel: mediaTypeLabel,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaInfoPanel extends StatelessWidget {
  const _MediaInfoPanel({
    required this.eventName,
    required this.dateLabel,
    required this.uploadedLabel,
    required this.mediaTypeLabel,
  });

  final String eventName;
  final String dateLabel;
  final String uploadedLabel;
  final String mediaTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetaRow(label: 'Event', value: eventName),
        const SizedBox(height: 6),
        _MetaRow(label: 'Date', value: dateLabel),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _MetaRow(label: 'Media type', value: mediaTypeLabel)),
            const SizedBox(width: 12),
            Expanded(child: _MetaRow(label: 'Published', value: uploadedLabel)),
          ],
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _VideoPlaybackControls extends StatelessWidget {
  const _VideoPlaybackControls({
    required this.controller,
    required this.onToggle,
  });

  final VideoPlayerController controller;
  final VoidCallback onToggle;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final value = controller.value;
        final position = value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        final playing = value.isPlaying;

        return Stack(
          children: [
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggle,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
