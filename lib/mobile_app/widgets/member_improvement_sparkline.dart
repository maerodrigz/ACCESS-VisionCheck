import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Lightweight CustomPainter sparkline (no chart package). Height should stay 70–90.
class MemberImprovementSparkline extends StatelessWidget {
  const MemberImprovementSparkline({
    super.key,
    required this.valuesOutOfFive,
    this.height = 80,
    this.lineColor = kCyan,
    this.fill = true,
  });

  final List<double> valuesOutOfFive;
  final double height;
  final Color lineColor;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height.clamp(70.0, 90.0),
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: valuesOutOfFive,
          lineColor: lineColor,
          fill: fill,
          gridColor: (isDark ? Colors.white : kTextPrimary).withValues(alpha: 0.06),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fill,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final bool fill;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 0.05 ? 0.5 : (maxV - minV);
    final padY = size.height * 0.14;
    final usableH = size.height - padY * 2;

    Offset pointAt(int i) {
      final t = values.length == 1 ? 0.0 : i / (values.length - 1);
      final x = t * size.width;
      final norm = (values[i] - minV) / span;
      final y = size.height - padY - (norm.clamp(0.0, 1.0) * usableH);
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      gridPaint,
    );

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(pointAt(values.length - 1).dx, size.height)
        ..lineTo(pointAt(0).dx, size.height)
        ..close();
      final shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.02),
        ],
      );
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 3.6, Paint()..color = lineColor);
    canvas.drawCircle(last, 1.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fill != fill;
  }
}
