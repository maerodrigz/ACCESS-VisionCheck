import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Development-only video playback diagnostics. Never logs URLs or tokens.
void evalVideoDiag(
  String event, {
  Map<String, Object?> fields = const {},
}) {
  if (!kDebugMode) return;
  final parts = <String>[event];
  for (final entry in fields.entries) {
    final key = entry.key;
    // Hard deny sensitive keys even if a caller passes them by mistake.
    if (_sensitiveKey(key)) continue;
    final value = entry.value;
    if (value == null) continue;
    parts.add('$key=$value');
  }
  developer.log(parts.join(' '), name: 'ACCESS.video');
}

bool _sensitiveKey(String key) {
  final lower = key.toLowerCase();
  return lower.contains('url') ||
      lower.contains('token') ||
      lower.contains('jwt') ||
      lower.contains('authorization') ||
      lower.contains('path') ||
      lower.contains('location') ||
      lower.contains('sign');
}
