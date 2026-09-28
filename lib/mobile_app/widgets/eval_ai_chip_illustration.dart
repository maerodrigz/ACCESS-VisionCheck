import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

/// Futuristic glowing AI processor chip for the evaluation hero card.
class EvalAiChipIllustration extends StatefulWidget {
  const EvalAiChipIllustration({super.key, this.size = 108});

  final double size;

  @override
  State<EvalAiChipIllustration> createState() => _EvalAiChipIllustrationState();
}

class _EvalAiChipIllustrationState extends State<EvalAiChipIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
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
        final glow = 0.35 + pulse * 0.25;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow rings
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: glow * 0.35),
                      blurRadius: 28 + pulse * 8,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: kEvalSecondary.withValues(alpha: glow * 0.45),
                      blurRadius: 20 + pulse * 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
              // Rotating orbit ring
              Transform.rotate(
                angle: _controller.value * math.pi * 2,
                child: Container(
                  width: widget.size * 0.88,
                  height: widget.size * 0.88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12 + pulse * 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.7 + pulse * 0.3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Chip body
              CustomPaint(
                size: Size(widget.size * 0.72, widget.size * 0.72),
                painter: _AiChipPainter(pulse: pulse, spin: _controller.value),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiChipPainter extends CustomPainter {
  _AiChipPainter({required this.pulse, required this.spin});

  final double pulse;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width * 0.82, height: size.height * 0.82),
      const Radius.circular(10),
    );

    // Chip shadow
    canvas.drawRRect(
      chipRect.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // Chip fill
    final chipGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.28 + pulse * 0.08),
        Colors.white.withValues(alpha: 0.12),
        kEvalSecondary.withValues(alpha: 0.22 + pulse * 0.1),
      ],
    );
    canvas.drawRRect(
      chipRect,
      Paint()
        ..shader = chipGradient.createShader(chipRect.outerRect)
        ..style = PaintingStyle.fill,
    );

    // Chip border
    canvas.drawRRect(
      chipRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45 + pulse * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Pin rows (top & bottom)
    _drawPins(canvas, chipRect, top: true);
    _drawPins(canvas, chipRect, top: false);

    // Inner core
    final coreRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.42,
        height: size.height * 0.42,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      coreRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35 + pulse * 0.12),
            kEvalPrimary.withValues(alpha: 0.25),
          ],
        ).createShader(coreRect.outerRect),
    );
    canvas.drawRRect(
      coreRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Circuit traces
    final tracePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 + pulse * 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - size.width * 0.12, center.dy),
      Offset(center.dx + size.width * 0.12, center.dy),
      tracePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * 0.1),
      Offset(center.dx, center.dy + size.height * 0.1),
      tracePaint,
    );

    // AI label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'AI',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: size.width * 0.14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // Spark nodes
    for (var i = 0; i < 4; i++) {
      final angle = spin * math.pi * 2 + i * math.pi / 2;
      final radius = size.width * 0.28;
      final node = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(
        node,
        2 + pulse,
        Paint()..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.4),
      );
    }
  }

  void _drawPins(Canvas canvas, RRect chipRect, {required bool top}) {
    const pinCount = 5;
    final y = top ? chipRect.top : chipRect.bottom;
    final startX = chipRect.left + chipRect.width * 0.18;
    final endX = chipRect.right - chipRect.width * 0.18;
    final step = (endX - startX) / (pinCount - 1);

    for (var i = 0; i < pinCount; i++) {
      final x = startX + step * i;
      final pinTop = top ? y - 5 : y;
      final pinBottom = top ? y : y + 5;
      canvas.drawLine(
        Offset(x, pinTop),
        Offset(x, pinBottom),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AiChipPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.spin != spin;
}
