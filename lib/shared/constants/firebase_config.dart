import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client config via `--dart-define` (see Firebase Console → project settings).
///
/// Example:
/// flutter run --dart-define=FIREBASE_PROJECT_ID=access-visioncheck \
///   --dart-define=FIREBASE_STORAGE_BUCKET=access-visioncheck.appspot.com \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
abstract final class FirebaseConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  /// FCM push (no Firebase Storage console / Blaze required).
  static bool get isPushConfigured =>
      projectId.isNotEmpty &&
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty;

  /// Client uploads to Firebase Storage (optional).
  static bool get isConfigured =>
      isPushConfigured && storageBucket.isNotEmpty;

  static String get effectiveStorageBucket =>
      storageBucket.isNotEmpty ? storageBucket : '$projectId.appspot.com';

  static FirebaseOptions get options {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: effectiveStorageBucket,
        authDomain: authDomain.isNotEmpty ? authDomain : '$projectId.firebaseapp.com',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: effectiveStorageBucket,
    );
  }
}
