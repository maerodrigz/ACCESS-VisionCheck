import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/mobile_app/controllers/app.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/services/firebase_app_init.dart';
import 'package:access_mobile/mobile_app/navigation/notification_navigation.dart';
import 'package:access_mobile/shared/navigation/app_navigator.dart';
import 'package:access_mobile/shared/services/push_notification_service.dart';

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
  PushNotificationService.bindInboxSyncHandler(
    memberDataController.refreshNotifications,
  );
  PushNotificationService.bindNotificationOpenHandler((notification) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      throw StateError('Navigator not ready for push open');
    }
    await handleNotificationTap(ctx, notification, openedFromPush: true);
  });
  await PushNotificationService.initialize();
  await ApiConfig.clearStaleOverridesWhenCompileTimeHostSet();
  await ApiConfig.initAndroidDeviceProfile();
  await ApiConfig.loadLastWorkingBaseUrl();
  await ApiConfig.runtimeBaseUrl.load();
  await ApiConfig.clearStaleEmulatorBackendOverride();
  await ApiConfig.loadBundledMobileBackendDefault();
  if (ApiConfig.apiBaseUrlOverride.isNotEmpty ||
      ApiConfig.apiPublicHostOverride.isNotEmpty) {
    apiClient.resetConnection();
  }
  await apiClient.warmUpConnection();
  await authController.waitForInitialization();
  // Branding loads on the splash screen so the branded UI appears immediately.
  runApp(const AccessApp());
}
