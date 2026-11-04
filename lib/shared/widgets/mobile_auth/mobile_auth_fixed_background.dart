import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';

/// Decorative auth background sized to the full window (stable across keyboard + routes).
class MobileAuthFixedBackground extends StatelessWidget {
  const MobileAuthFixedBackground({
    super.key,
    required this.assetPath,
    this.alignment = Alignment.topCenter,
  });

  final String assetPath;
  final Alignment alignment;

  static Size logicalWindowSize(BuildContext context) {
    final FlutterView view = View.of(context);
    return view.physicalSize / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    final logical = logicalWindowSize(context);
    return IgnorePointer(
      child: SizedBox(
        width: logical.width,
        height: logical.height,
        child: Image.asset(
          assetPath,
          width: logical.width,
          height: logical.height,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
