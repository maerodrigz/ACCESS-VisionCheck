import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:access_mobile/shared/constants/firebase_config.dart';
import 'package:access_mobile/shared/constants/firebase_runtime_config.dart';

const _logName = 'ACCESS.firebase';

/// Initializes Firebase when [FirebaseConfig.isConfigured].
/// Returns `true` when Storage is available; `false` falls back to local `/uploads`.
Future<bool> initializeFirebaseApp() async {
  await FirebaseRuntimeConfig.ensureLoadedFromAsset();
  if (!FirebaseRuntimeConfig.isPushConfigured) {
    developer.log('Firebase not configured — push and cloud storage disabled.', name: _logName);
    return false;
  }
  if (Firebase.apps.isNotEmpty) return true;
  try {
    await Firebase.initializeApp(options: FirebaseRuntimeConfig.options);
    developer.log(
      'Firebase initialized (bucket: ${FirebaseConfig.storageBucket}).',
      name: _logName,
    );
    return true;
  } catch (e, st) {
    developer.log(
      'Firebase init failed — using local server storage.',
      name: _logName,
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

bool get isFirebaseStorageReady =>
    FirebaseConfig.isConfigured && Firebase.apps.isNotEmpty;

bool get isFirebasePushReady =>
    FirebaseRuntimeConfig.isPushConfigured && Firebase.apps.isNotEmpty;
