import 'dart:async';

import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:flutter/widgets.dart';

/// Foreground-only presence heartbeat for Member / Organization accounts.
///
/// Sends POST /api/presence/heartbeat about every 60s while authenticated and
/// resumed. Stops when backgrounded, logged out, or role is not member/org.
class PresenceHeartbeatService with WidgetsBindingObserver {
  PresenceHeartbeatService._();

  static final PresenceHeartbeatService instance = PresenceHeartbeatService._();

  static const Duration interval = Duration(seconds: 60);

  Timer? _timer;
  bool _started = false;
  bool _foreground = true;
  bool _inFlight = false;
  VoidCallback? _authListener;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _authListener = _onAuthChanged;
    authController.addListener(_authListener!);
    _foreground = true;
    _sync();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    if (_authListener != null) {
      authController.removeListener(_authListener!);
      _authListener = null;
    }
    _stopTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _sync(immediate: true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _foreground = false;
        _stopTimer();
        break;
    }
  }

  void _onAuthChanged() => _sync(immediate: true);

  bool get _eligible {
    final user = authController.user;
    if (user == null || user.token.trim().isEmpty) return false;
    final role = user.role.apiValue.toLowerCase();
    return role == 'member' || role == 'organization';
  }

  void _sync({bool immediate = false}) {
    if (!_started || !_foreground || !_eligible) {
      _stopTimer();
      return;
    }
    if (immediate) {
      unawaited(_beat());
    }
    _timer ??= Timer.periodic(interval, (_) => unawaited(_beat()));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _beat() async {
    if (!_started || !_foreground || !_eligible || _inFlight) return;
    if (apiClient.token == null || apiClient.token!.isEmpty) return;
    _inFlight = true;
    try {
      await apiClient.post('/presence/heartbeat', {});
    } catch (e, st) {
      // Soft-fail: presence must never block the app.
      debugPrint('Presence heartbeat skipped: $e\n$st');
    } finally {
      _inFlight = false;
    }
  }
}
