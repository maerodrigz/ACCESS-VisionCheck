import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gold trophy illustration for high-scoring evaluations (>= 90%).
class EvalTrophyIllustration extends StatefulWidget {
  const EvalTrophyIllustration({super.key, this.size = 88});

  final double size;

  @override
  State<EvalTrophyIllustration> createState() => _EvalTrophyIllustrationState();
}

class _EvalTrophyIllustrationState extends State<EvalTrophyIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
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
        final pulse = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _TrophyPainter(pulse: pulse),
          ),
        );
      },
    );
  }
}

class _TrophyPainter extends CustomPainter {
  _TrophyPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final glow = Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.18 + pulse * 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(cx, size.height * 0.42), size.width * 0.34, glow);

    final cup = Path()
      ..moveTo(cx - size.width * 0.22, size.height * 0.22)
      ..lineTo(cx - size.width * 0.14, size.height * 0.48)
      ..quadraticBezierTo(cx, size.height * 0.56, cx + size.width * 0.14, size.height * 0.48)
      ..lineTo(cx + size.width * 0.22, size.height * 0.22)
      ..close();

    final gold = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(const Color(0xFFFDE68A), const Color(0xFFFBBF24), pulse)!,
        const Color(0xFFD97706),
      ],
    );

    canvas.drawPath(
      cup,
      Paint()..shader = gold.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Handles
    final handle = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx - size.width * 0.24, size.height * 0.33), radius: size.width * 0.1),
      -math.pi / 2,
      math.pi,
      false,
      handle,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + size.width * 0.24, size.height * 0.33), radius: size.width * 0.1),
      -math.pi / 2,
      math.pi,
      false,
      handle,
    );

    // Stem & base
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, size.height * 0.62), width: size.width * 0.08, height: size.height * 0.12),
      Paint()..color = const Color(0xFFB45309),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, size.height * 0.74), width: size.width * 0.36, height: size.height * 0.08),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF92400E),
    );

    // Star on cup
    _drawStar(canvas, Offset(cx, size.height * 0.36), size.width * 0.06, const Color(0xFFFFF7ED));
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final point = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter oldDelegate) => oldDelegate.pulse != pulse;
}
