import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/constants/firebase_config.dart';
import 'package:access_mobile/shared/services/firebase_app_init.dart';

const _logName = 'ACCESS.push';

/// Background FCM handler (top-level isolate entry).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebaseApp();
  developer.log('Background push: ${message.notification?.title}', name: _logName);
}

/// Registers FCM tokens for member and requestor mobile sessions.
abstract final class PushNotificationService {
  static String? _lastRegisteredToken;
  static Future<void> Function()? _inboxSyncHandler;

  static bool get isAvailable =>
      !kIsWeb && isFirebaseStorageReady && FirebaseConfig.messagingSenderId.isNotEmpty;

  /// Called when a push arrives or the user opens the app from a notification.
  static void bindInboxSyncHandler(Future<void> Function() handler) {
    _inboxSyncHandler = handler;
  }

  static Future<void> _syncInboxFromPush() async {
    final handler = _inboxSyncHandler;
    if (handler == null) return;
    try {
      await handler();
    } catch (e, st) {
      developer.log('Inbox sync after push failed', name: _logName, error: e, stackTrace: st);
    }
  }

  static Future<void> initialize() async {
    if (!isAvailable) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });
    FirebaseMessaging.onMessage.listen((_) {
      unawaited(_syncInboxFromPush());
    });
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      unawaited(_syncInboxFromPush());
    });
  }

  /// Refresh inbox when the app was opened from a terminated state via push.
  static Future<void> syncInboxIfOpenedFromPush() async {
    if (!isAvailable) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await _syncInboxFromPush();
    }
  }

  static Future<void> ensureRegistered() async {
    if (!isAvailable) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        developer.log('Push permission denied', name: _logName);
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e, st) {
      developer.log('Push registration failed', name: _logName, error: e, stackTrace: st);
    }
  }

  static Future<void> unregisterCurrent() async {
    if (!isAvailable) return;
    final token = _lastRegisteredToken;
    if (token == null || token.isEmpty) return;
    try {
      await memberApiService.unregisterPushToken(token);
    } catch (e, st) {
      developer.log('Push unregister failed', name: _logName, error: e, stackTrace: st);
    } finally {
      _lastRegisteredToken = null;
    }
  }

  static Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;
    try {
      final platform = _platformLabel();
      await memberApiService.registerPushToken(token: token, platform: platform);
      _lastRegisteredToken = token;
      developer.log('Push token registered ($platform)', name: _logName);
    } catch (e, st) {
      developer.log('Push token upload failed', name: _logName, error: e, stackTrace: st);
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
