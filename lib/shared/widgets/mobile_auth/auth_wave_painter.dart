import 'package:flutter/material.dart';

/// Overlapping cyan waves transitioning into the white form area.
class AuthWavePainter extends CustomPainter {
  AuthWavePainter({this.backWaveColor = const Color(0xFF00C4E8)});

  final Color backWaveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final back = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.25, h * 0.15, w * 0.55, h * 0.42)
      ..quadraticBezierTo(w * 0.82, h * 0.68, w, h * 0.38)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(back, Paint()..color = backWaveColor);

    final front = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.32, h * 0.32, w * 0.62, h * 0.58)
      ..quadraticBezierTo(w * 0.88, h * 0.78, w, h * 0.48)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(front, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant AuthWavePainter oldDelegate) =>
      oldDelegate.backWaveColor != backWaveColor;
}

class AuthWaveDivider extends StatelessWidget {
  const AuthWaveDivider({super.key, this.height = 52});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: AuthWavePainter()),
    );
  }
}
