// Platform file picker — web uses dart:html; mobile/desktop uses image_picker.
export 'file_picker_stub.dart' if (dart.library.html) 'file_picker_web.dart';
