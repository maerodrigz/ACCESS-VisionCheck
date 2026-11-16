import 'package:flutter/foundation.dart';

/// Coordinates evaluation video previews vs full-screen playback.
///
/// Full-screen viewers call [beginFullscreenPlayback] so report/list preview
/// [VideoPlayerController]s pause and release bandwidth. Previews may restore
/// after [endFullscreenPlayback] when a first-frame JPEG is not cached.
class EvalVideoPreviewGate extends ChangeNotifier {
  EvalVideoPreviewGate._();

  static final EvalVideoPreviewGate instance = EvalVideoPreviewGate._();

  int _fullscreenSessions = 0;

  /// True while at least one full-screen network video viewer is open.
  bool get previewsSuspended => _fullscreenSessions > 0;

  @visibleForTesting
  int get fullscreenSessionCount => _fullscreenSessions;

  void beginFullscreenPlayback() {
    _fullscreenSessions += 1;
    notifyListeners();
  }

  void endFullscreenPlayback() {
    if (_fullscreenSessions <= 0) return;
    _fullscreenSessions -= 1;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _fullscreenSessions = 0;
    notifyListeners();
  }
}
