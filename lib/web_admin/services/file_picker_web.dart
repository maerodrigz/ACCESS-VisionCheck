import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<List<({String name, Uint8List bytes})>> pickImagesFromWeb() async {
  final completer = Completer<List<({String name, Uint8List bytes})>>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = true;
  input.click();

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete([]);
      return;
    }
    final results = <({String name, Uint8List bytes})>[];
    var pending = files.length;
    for (final file in files) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        results.add((name: file.name, bytes: reader.result as Uint8List));
        pending--;
        if (pending == 0) completer.complete(results);
      });
    }
  });

  late void Function(html.Event) focusHandler;
  focusHandler = (_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete([]);
    });
    html.window.removeEventListener('focus', focusHandler);
  };
  html.window.addEventListener('focus', focusHandler);

  return completer.future;
}

Future<({String name, Uint8List bytes})?> pickSingleMediaFromWeb({required bool isVideo}) async {
  final completer = Completer<({String name, Uint8List bytes})?>();
  final input = html.FileUploadInputElement()
    ..accept = isVideo ? 'video/*' : 'image/*'
    ..multiple = false;
  input.click();

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      completer.complete((name: file.name, bytes: reader.result as Uint8List));
    });
  });

  late void Function(html.Event) focusHandler;
  focusHandler = (_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(null);
    });
    html.window.removeEventListener('focus', focusHandler);
  };
  html.window.addEventListener('focus', focusHandler);

  return completer.future;
}
