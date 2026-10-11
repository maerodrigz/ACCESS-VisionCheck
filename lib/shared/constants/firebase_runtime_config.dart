import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/shared/constants/firebase_config.dart';

/// Compile-time `--dart-define-from-file=config/firebase.json` preferred.
/// Falls back to bundled asset for debug installs that omit dart-defines.
abstract final class FirebaseRuntimeConfig {
  static FirebaseOptions? _assetOptions;

  static Future<void> ensureLoadedFromAsset() async {
    if (FirebaseConfig.isPushConfigured || _assetOptions != null) return;
    try {
      final raw = await rootBundle.loadString('config/firebase.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final projectId = map['FIREBASE_PROJECT_ID']?.toString() ?? '';
      final apiKey = map['FIREBASE_API_KEY']?.toString() ?? '';
      final appId = map['FIREBASE_APP_ID']?.toString() ?? '';
      final sender = map['FIREBASE_MESSAGING_SENDER_ID']?.toString() ?? '';
      if (projectId.isEmpty || apiKey.isEmpty || appId.isEmpty || sender.isEmpty) {
        return;
      }
      final bucket = map['FIREBASE_STORAGE_BUCKET']?.toString() ?? '';
      _assetOptions = FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: sender,
        projectId: projectId,
        storageBucket: bucket.isNotEmpty ? bucket : '$projectId.appspot.com',
      );
    } catch (_) {
      // Asset missing in release or config not bundled.
    }
  }

  static bool get isPushConfigured =>
      FirebaseConfig.isPushConfigured || _assetOptions != null;

  static FirebaseOptions get options {
    if (FirebaseConfig.isPushConfigured) return FirebaseConfig.options;
    final asset = _assetOptions;
    if (asset != null) return asset;
    return FirebaseConfig.options;
  }
}
