import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/mobile_app/controllers/app.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/services/firebase_app_init.dart';

/// Member / requester mobile app — run on a phone or emulator:
/// `flutter run -t lib/mobile_app/main_mobile.dart`
/// or use the root [main.dart] shortcut.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await initializeFirebaseApp();
  await ApiConfig.clearStaleOverridesWhenCompileTimeHostSet();
  await ApiConfig.loadLastWorkingBaseUrl();
  await ApiConfig.runtimeBaseUrl.load();
  await apiClient.warmUpConnection();
  // Branding loads on the splash screen so the branded UI appears immediately.
  runApp(const AccessApp());
}
