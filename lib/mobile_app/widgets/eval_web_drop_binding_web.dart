import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:access_mobile/mobile_app/widgets/eval_web_drop_binding_stub.dart';

StreamSubscription<html.Event>? _dragOverSub;
StreamSubscription<html.Event>? _dropSub;
StreamSubscription<html.Event>? _dragEnterSub;
StreamSubscription<html.Event>? _dragLeaveSub;
int _dragDepth = 0;

/// Registers document-level file drop handling while the upload page is open.
class EvalWebDropBinding {
  static void install({
    required EvalWebFileDropHandler onDrop,
    required bool isVideo,
    required int maxBytes,
    required void Function(bool dragging) onDragging,
    required void Function(String message) onReject,
  }) {
    dispose();
    _dragDepth = 0;

    _dragOverSub = html.document.onDragOver.listen((e) {
      e.preventDefault();
    });

    _dragEnterSub = html.document.onDragEnter.listen((e) {
      e.preventDefault();
      _dragDepth++;
      onDragging(true);
    });

    _dragLeaveSub = html.document.onDragLeave.listen((e) {
      e.preventDefault();
      _dragDepth = (_dragDepth - 1).clamp(0, 999);
      if (_dragDepth == 0) onDragging(false);
    });

    _dropSub = html.document.onDrop.listen((e) {
      e.preventDefault();
      _dragDepth = 0;
      onDragging(false);

      final files = e.dataTransfer?.files;
      if (files == null || files.isEmpty) return;
      final file = files.first;

      final typeOk = isVideo ? file.type.startsWith('video/') : file.type.startsWith('image/');
      if (!typeOk) {
        onReject(isVideo ? 'Please drop a video file.' : 'Please drop an image file.');
        return;
      }
      if (file.size > maxBytes) {
        onReject('File exceeds the maximum allowed size.');
        return;
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        final data = reader.result;
        if (data is! ByteBuffer) return;
        onDrop(file.name, data.asUint8List());
      });
    });
  }

  static void dispose() {
    _dragOverSub?.cancel();
    _dropSub?.cancel();
    _dragEnterSub?.cancel();
    _dragLeaveSub?.cancel();
    _dragOverSub = null;
    _dropSub = null;
    _dragEnterSub = null;
    _dragLeaveSub = null;
    _dragDepth = 0;
  }
}
