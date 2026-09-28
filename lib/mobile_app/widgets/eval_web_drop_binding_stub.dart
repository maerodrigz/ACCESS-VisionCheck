import 'package:flutter/foundation.dart';

typedef EvalWebFileDropHandler = void Function(String name, Uint8List bytes);

/// No-op on mobile/desktop — drag & drop is web-only.
class EvalWebDropBinding {
  static void install({
    required EvalWebFileDropHandler onDrop,
    required bool isVideo,
    required int maxBytes,
    required void Function(bool dragging) onDragging,
    required void Function(String message) onReject,
  }) {}

  static void dispose() {}
}
