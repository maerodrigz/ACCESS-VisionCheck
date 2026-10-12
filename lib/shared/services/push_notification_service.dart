import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/constants/firebase_runtime_config.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/app_notification_mapper.dart';
import 'package:access_mobile/shared/services/firebase_app_init.dart';

const _logName = 'ACCESS.push';

typedef NotificationOpenHandler = Future<void> Function(AppNotification notification);

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
  static NotificationOpenHandler? _openHandler;
  static Timer? _inboxSyncDebounce;
  static RemoteMessage? _pendingRemoteOpen;

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

  /// Same UX as tapping a row in the in-app notification center.
  static void bindNotificationOpenHandler(NotificationOpenHandler handler) {
    _openHandler = handler;
    unawaited(flushPendingNotificationOpen());
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

  static Map<String, dynamic> _dataFromRemoteMessage(RemoteMessage message) {
    return message.data.map((key, value) => MapEntry(key, value.toString()));
  }

  static (String title, String body) _titleBodyFromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'ACCESS';
    final body = notification?.body ?? data['message'] ?? data['body'] ?? '';
    return (title, body);
  }

  static AppNotification _notificationFromRemoteMessage(RemoteMessage message) {
    final (title, body) = _titleBodyFromRemoteMessage(message);
    return appNotificationFromPushData(
      _dataFromRemoteMessage(message),
      title: title,
      body: body,
    );
  }

  static AppNotification _notificationFromPayloadMap(Map<String, dynamic> map) {
    final title = (map['title'] as String?) ?? 'ACCESS';
    final body = (map['body'] as String?) ?? (map['message'] as String?) ?? '';
    final data = <String, dynamic>{};
    for (final key in ['category', 'notification_id', 'action_type', 'action_ref_id']) {
      if (map.containsKey(key)) data[key] = map[key];
    }
    return appNotificationFromPushData(data, title: title, body: body);
  }

  static Future<void> _openFromRemoteMessage(RemoteMessage message) async {
    await _syncInboxFromPush();
    final stub = _notificationFromRemoteMessage(message);
    final resolved = resolveNotificationForOpen(stub);
    final handler = _openHandler;
    if (handler == null) {
      _pendingRemoteOpen = message;
      developer.log('Push open queued (UI not ready)', name: _logName);
      return;
    }
    try {
      await handler(resolved);
      _pendingRemoteOpen = null;
    } catch (e, st) {
      developer.log('Push open handler failed', name: _logName, error: e, stackTrace: st);
      _pendingRemoteOpen = message;
    }
  }

  static Future<void> flushPendingNotificationOpen() async {
    final pending = _pendingRemoteOpen;
    if (pending == null) return;
    if (_openHandler == null) return;
    await _openFromRemoteMessage(pending);
  }

  static Future<void> _initLocalNotifications() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          _scheduleInboxSyncFromPush();
          return;
        }
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          unawaited(_openFromPayloadMap(map));
        } catch (e, st) {
          developer.log('Tray payload parse failed', name: _logName, error: e, stackTrace: st);
          _scheduleInboxSyncFromPush();
        }
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _openFromPayloadMap(Map<String, dynamic> map) async {
    await _syncInboxFromPush();
    final stub = _notificationFromPayloadMap(map);
    final resolved = resolveNotificationForOpen(stub);
    final handler = _openHandler;
    if (handler == null) {
      developer.log('Tray open skipped (handler not bound)', name: _logName);
      return;
    }
    await handler(resolved);
  }

  static Future<void> _showForegroundTrayNotification(RemoteMessage message) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final (title, body) = _titleBodyFromRemoteMessage(message);
    if (title.isEmpty && body.isEmpty) return;

    final payloadMap = <String, dynamic>{
      'title': title,
      'body': body,
      ..._dataFromRemoteMessage(message),
    };

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
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
      payload: jsonEncode(payloadMap),
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
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_openFromRemoteMessage(message));
    });
  }

  /// Refresh inbox when the app was opened from a terminated state via push.
  static Future<void> syncInboxIfOpenedFromPush() async {
    if (!isAvailable) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _pendingRemoteOpen = initial;
      await _syncInboxFromPush();
      await flushPendingNotificationOpen();
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
