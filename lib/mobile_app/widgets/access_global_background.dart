import 'package:flutter/material.dart';

/// Shared viewport-locked background for authenticated Requestor and Member shells.
///
/// Renders [assetPath] once behind [child]. Scrollable content should use a
/// transparent page surface so this image stays fixed to the screen.
class AccessGlobalBackground extends StatelessWidget {
  const AccessGlobalBackground({
    super.key,
    this.child,
  });

  static const assetPath = 'assets/images/access_global_background.png';

  /// Shared [AssetImage] so Flutter reuses the same image provider across shells.
  static const imageProvider = AssetImage(assetPath);

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final painted = IgnorePointer(
      child: SizedBox.expand(
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );

    final content = child;
    if (content == null) return painted;

    return Stack(
      fit: StackFit.expand,
      children: [
        painted,
        content,
      ],
    );
  }

  /// Warm the image cache so tab/route transitions do not flash.
  static Future<void> precache(BuildContext context) {
    return precacheImage(imageProvider, context);
  }
}
