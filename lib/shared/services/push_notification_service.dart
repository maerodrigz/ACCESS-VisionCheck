import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/constants/firebase_runtime_config.dart';
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
  static Timer? _inboxSyncDebounce;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'access_alerts',
    'ACCESS alerts',
    description: 'Documentation requests, assignments, and announcements',
    importance: Importance.high,
  );

  static bool get isAvailable => !kIsWeb && isFirebasePushReady;

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

  static void _scheduleInboxSyncFromPush() {
    _inboxSyncDebounce?.cancel();
    _inboxSyncDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_syncInboxFromPush());
    });
  }

  static Future<void> _initLocalNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (_) {
        _scheduleInboxSyncFromPush();
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showForegroundTrayNotification(RemoteMessage message) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['message'];
    if (title == null && body == null) return;
    await _localNotifications.show(
      id: message.hashCode,
      title: title ?? 'ACCESS',
      body: body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> initialize() async {
    if (!isAvailable) return;
    await _initLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });
    FirebaseMessaging.onMessage.listen((message) {
      developer.log(
        'Foreground push: ${message.notification?.title ?? message.data}',
        name: _logName,
      );
      unawaited(_showForegroundTrayNotification(message));
      _scheduleInboxSyncFromPush();
    });
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      _scheduleInboxSyncFromPush();
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
    await FirebaseRuntimeConfig.ensureLoadedFromAsset();
    if (!FirebaseRuntimeConfig.isPushConfigured) {
      developer.log(
        'Push disabled: missing Firebase config. Add config/firebase.json or run with '
        '--dart-define-from-file=config/firebase.json',
        name: _logName,
      );
      return;
    }
    if (!isFirebasePushReady) {
      developer.log('Push disabled: Firebase not initialized.', name: _logName);
      return;
    }
    if (!isAvailable) return;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            developer.log('Android notification permission not granted', name: _logName);
          }
        }
      }
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
      if (token == null || token.isEmpty) {
        developer.log('FCM returned no device token', name: _logName);
        return;
      }
      await _registerToken(token);
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
