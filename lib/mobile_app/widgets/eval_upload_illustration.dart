import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

/// Large upload illustration for the AI evaluation upload page.
class EvalUploadIllustration extends StatefulWidget {
  const EvalUploadIllustration({super.key, required this.isVideo, this.size = 140});

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
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
        final bob = math.sin(_controller.value * math.pi * 2) * 6;
        return Transform.translate(
          offset: Offset(0, bob),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Soft glow
    canvas.drawCircle(
      center,
      size.width * 0.42,
      Paint()..color = kEvalPrimary.withValues(alpha: 0.08 + pulse * 0.06),
    );

    // Cloud base
    final cloudPaint = Paint()
      ..shader = LinearGradient(
        colors: [kEvalPrimary.withValues(alpha: 0.25), kEvalSecondary.withValues(alpha: 0.18)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.3));

    _drawCloud(canvas, Offset(center.dx, center.dy + 8), size.width * 0.38, cloudPaint);

    // Upload arrow
    final arrowPaint = Paint()
      ..color = kEvalSecondary.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx, center.dy + size.height * 0.12),
      Offset(center.dx, center.dy - size.height * 0.06),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * 0.06),
      Offset(center.dx - 10, center.dy + size.height * 0.02),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * 0.06),
      Offset(center.dx + 10, center.dy + size.height * 0.02),
      arrowPaint,
    );

    // Media tile
    final tileRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - size.height * 0.18),
        width: size.width * 0.28,
        height: size.width * 0.28,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      tileRect,
      Paint()
        ..shader = LinearGradient(
          colors: [kEvalPrimary, kEvalSecondary.withValues(alpha: 0.9)],
        ).createShader(tileRect.outerRect),
    );
    canvas.drawRRect(
      tileRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (isVideo) {
      final play = Path()
        ..moveTo(center.dx - 4, center.dy - size.height * 0.22)
        ..lineTo(center.dx + 8, center.dy - size.height * 0.18)
        ..lineTo(center.dx - 4, center.dy - size.height * 0.14)
        ..close();
      canvas.drawPath(play, Paint()..color = Colors.white.withValues(alpha: 0.95));
    } else {
      canvas.drawCircle(
        Offset(center.dx - 4, center.dy - size.height * 0.2),
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(center.dx - 4, center.dy - size.height * 0.2), width: 14, height: 10),
        0.2,
        math.pi,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius * 0.55, paint);
    canvas.drawCircle(Offset(center.dx - radius * 0.45, center.dy + 4), radius * 0.38, paint);
    canvas.drawCircle(Offset(center.dx + radius * 0.42, center.dy + 6), radius * 0.34, paint);
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
