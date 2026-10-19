import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/api/auth_service.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/navigation/app_navigator.dart';
import 'package:access_mobile/shared/services/push_notification_service.dart';

class AuthController extends ChangeNotifier {
  AuthController();

  Future<void>? _initialization;

  /// Completes when persisted session restore finishes (used by splash gate).
  /// Must run after [ApiConfig] load and [apiClient.warmUpConnection] in `main()`.
  Future<void> waitForInitialization() =>
      _initialization ??= _restoreSession();

  AuthUser? _user;
  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Shown on [VisionLoginScreen] after forced logout (deleted / deactivated account).
  String? consumeSessionEndMessage() {
    final msg = _sessionEndMessage;
    _sessionEndMessage = null;
    return msg;
  }

  void setSessionEndMessage(String? message) {
    _sessionEndMessage = message;
  }

  String? _sessionEndMessage;

  static const _sessionKey = 'access_vision_session';

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return;
    await _activatePersistedSession(raw, prefs);
  }

  /// After the user fixes backend URL on the login screen, try saved JWT again.
  Future<bool> retryPersistedSession() async {
    if (_user != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return false;
    apiClient.resetConnection();
    await apiClient.warmUpConnection();
    return _activatePersistedSession(raw, prefs);
  }

  /// Returns true when a saved session becomes the active user.
  Future<bool> _activatePersistedSession(String raw, SharedPreferences prefs) async {
    AuthUser? pending;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      pending = AuthUser(
        id: map['id'] as int,
        name: map['name'] as String,
        email: map['email'] as String,
        role: AccessRole.fromApi(map['role'] as String),
        token: map['token'] as String,
      );
      apiClient.setToken(pending.token);
      await apiClient.warmUpConnection();
      await apiClient.get('/profile');
      _user = pending;
      if (_user!.role == AccessRole.member || _user!.role == AccessRole.organization) {
        await _syncMemberSession();
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      apiClient.setToken(null);
      if (e.shouldEndSession) {
        if (e.code == 'rejected' || e.code == 'removed') {
          _sessionEndMessage =
              '${e.message} You can register again if your account was removed.';
        } else if (e.statusCode == 401) {
          _sessionEndMessage =
              'This account no longer exists. Sign in with another account or register again.';
        } else {
          _sessionEndMessage = e.message;
        }
        await prefs.remove(_sessionKey);
      } else if (_isUnreachableBackend(e)) {
        // Keep saved session; mobile sign-in stays clean (fix URL under Account settings).
        _sessionEndMessage = null;
      } else {
        await prefs.remove(_sessionKey);
        _sessionEndMessage = e.message;
      }
      notifyListeners();
      return false;
    } catch (_) {
      apiClient.setToken(null);
      await prefs.remove(_sessionKey);
      notifyListeners();
      return false;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    final user = await authService.login(email, password);
    _user = user;
    await _persist();
    if (user.role == AccessRole.member || user.role == AccessRole.organization) {
      await _syncMemberSession();
    }
    notifyListeners();
    return user;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? studentId,
    String? contactNumber,
    String? emailVerificationToken,
    String? adviserName,
    String? skillLevel,
  }) async {
    await authService.register(
      name: name,
      email: email,
      password: password,
      role: role,
      studentId: studentId,
      contactNumber: contactNumber,
      emailVerificationToken: emailVerificationToken,
      adviserName: adviserName,
      skillLevel: skillLevel,
    );
  }

  /// Refresh session display name/email after profile edit (keeps token).
  Future<void> updateSessionProfile({String? name, String? email}) async {
    if (_user == null) return;
    _user = AuthUser(
      id: _user!.id,
      name: name ?? _user!.name,
      email: email ?? _user!.email,
      role: _user!.role,
      token: _user!.token,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    await authService.logout();
    _user = null;
    appState.clearMemberProfile();
    memberDataController.resetForLogout();
    notifyListeners();
    // Profile and other pushed routes sit above [AuthGate]; pop so login is visible.
    popToAppRoot();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    unawaited(PushNotificationService.unregisterCurrent());
  }

  static bool _isUnreachableBackend(ApiException e) =>
      e.statusCode == null;

  /// Member/org shells load data on first paint; avoid blocking login with a full sync.
  Future<void> _syncMemberSession() async {
    if (kIsWeb) return;
    await PushNotificationService.ensureRegistered();
  }

  Future<void> _persist() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode({
      'id': _user!.id,
      'name': _user!.name,
      'email': _user!.email,
      'role': _user!.role.apiValue,
      'token': _user!.token,
    }));
  }
}

final authController = AuthController();
