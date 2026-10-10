import 'dart:math' as math;

import 'package:flutter/material.dart';
/// Upload hero illustration for the AI evaluation upload page.
class EvalUploadIllustration extends StatefulWidget {
  const EvalUploadIllustration({super.key, required this.isVideo, this.size = 132});

  final bool isVideo;
  final double size;

  @override
  State<EvalUploadIllustration> createState() => _EvalUploadIllustrationState();
}

class _EvalUploadIllustrationState extends State<EvalUploadIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final bob = math.sin(_controller.value * math.pi * 2) * 4;
        return Transform.translate(
          offset: Offset(0, bob),
          child: SizedBox(
            width: widget.size,
            height: widget.size * 0.92,
            child: CustomPaint(
              painter: _UploadIllustrationPainter(
                isVideo: widget.isVideo,
                pulse: 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UploadIllustrationPainter extends CustomPainter {
  _UploadIllustrationPainter({required this.isVideo, required this.pulse});

  final bool isVideo;
  final double pulse;

  static const _navy = Color(0xFF1E3A5F);
  static const _circleBlue = Color(0xFF7DD3FC);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h * 0.58;

    // Overlapping soft circles
    void drawCircle(Offset c, double r, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()..color = _circleBlue.withValues(alpha: alpha + pulse * 0.04),
      );
    }

    drawCircle(Offset(w * 0.38, baseY), w * 0.22, 0.35);
    drawCircle(Offset(w * 0.62, baseY), w * 0.2, 0.28);
    drawCircle(Offset(w * 0.5, baseY + w * 0.04), w * 0.24, 0.22);

    // Upload arrow (below circles)
    final arrowPaint = Paint()
      ..color = _navy.withValues(alpha: 0.75)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final ax = w * 0.5;
    final ay = baseY + w * 0.22;
    canvas.drawLine(Offset(ax, ay + w * 0.08), Offset(ax, ay - w * 0.02), arrowPaint);
    canvas.drawLine(Offset(ax, ay - w * 0.02), Offset(ax - 9, ay + w * 0.04), arrowPaint);
    canvas.drawLine(Offset(ax, ay - w * 0.02), Offset(ax + 9, ay + w * 0.04), arrowPaint);

    // Device tile (camera / video)
    final tileW = w * 0.3;
    final tileH = w * 0.3;
    final tileCenter = Offset(w * 0.5, h * 0.32);
    final tileRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: tileCenter, width: tileW, height: tileH),
      Radius.circular(tileW * 0.22),
    );
    canvas.drawRRect(
      tileRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), _navy],
        ).createShader(tileRect.outerRect),
    );
    canvas.drawRRect(
      tileRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final iconCenter = tileCenter;
    if (isVideo) {
      final play = Path()
        ..moveTo(iconCenter.dx - 5, iconCenter.dy - 7)
        ..lineTo(iconCenter.dx + 9, iconCenter.dy)
        ..lineTo(iconCenter.dx - 5, iconCenter.dy + 7)
        ..close();
      canvas.drawPath(play, Paint()..color = Colors.white.withValues(alpha: 0.95));
    } else {
      canvas.drawCircle(
        Offset(iconCenter.dx, iconCenter.dy - 2),
        tileW * 0.14,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        Offset(iconCenter.dx, iconCenter.dy - 2),
        tileW * 0.09,
        Paint()..color = _navy.withValues(alpha: 0.35),
      );
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(iconCenter.dx, iconCenter.dy + tileW * 0.12),
          width: tileW * 0.38,
          height: tileW * 0.22,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(body, Paint()..color = Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _UploadIllustrationPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.isVideo != isVideo;
}

String formatEvalFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
