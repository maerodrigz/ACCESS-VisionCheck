import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Default ACCESS VisionCheck mark — logo gradient tile with a photo symbol.
class AccessVisionCheckMark extends StatelessWidget {
  const AccessVisionCheckMark({
    super.key,
    required this.size,
    this.showBubbles = true,
  });

  final double size;
  final bool showBubbles;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    final tileSize = size * 0.78;
    final iconSize = tileSize * 0.44;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showBubbles) ...[
            Positioned(
              left: size * 0.06,
              bottom: size * 0.1,
              child: _bubble(size * 0.22, 0.28),
            ),
            Positioned(
              right: size * 0.04,
              bottom: size * 0.14,
              child: _bubble(size * 0.18, 0.22),
            ),
            Positioned(
              left: size * 0.28,
              bottom: size * 0.02,
              child: _bubble(size * 0.14, 0.18),
            ),
          ],
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [kCyan, kAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: 0.22),
                  blurRadius: size * 0.08,
                  offset: Offset(0, size * 0.04),
                ),
              ],
            ),
            child: Icon(
              Icons.photo_rounded,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double diameter, double alpha) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kCyan.withValues(alpha: alpha),
      ),
    );
  }
}
