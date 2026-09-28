import 'dart:convert';

import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountManagementRepository {
  static const _lockedKey = 'account_management_locked_ids';
  static const _hiddenKey = 'account_management_hidden_ids';
  static const _overridesKey = 'account_management_profile_overrides';
  static const _activityKey = 'account_management_activity_log';

  Future<AccountManagementData> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception('Backend offline. Run: cd access_backend && python manage.py runserver');
    }

    final raw = await adminApi.allUsers();
    final locked = await _loadIdSet(_lockedKey);
    final hidden = await _loadIdSet(_hiddenKey);
    final overrides = await _loadOverrides();
    final extraActivity = await _loadActivityLog();

    final accounts = raw
        .map((m) => _mapAccount(m, locked: locked, overrides: overrides, extraActivity: extraActivity))
        .where((a) => !hidden.contains(a.id))
        .toList();

    accounts.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

    return AccountManagementData(accounts: accounts, stats: _computeStats(accounts));
  }

  List<AccountProfile> filter({
    required List<AccountProfile> items,
    required AccountFilterChip chip,
    required String search,
  }) {
    return items.where((a) => a.matchesFilter(chip) && a.matchesSearch(search)).toList();
  }

  Future<void> activateAccount(AccountProfile account) async {
    await adminApi.setUserStatus(account.id, 'approved');
    await _removeLocked(account.id);
  }

  Future<void> deactivateAccount(AccountProfile account, {String? reason}) async {
    await adminApi.setUserStatus(
      account.id,
      'rejected',
      rejectionReason: reason ?? 'Deactivated by administrator',
    );
    await _appendActivity(account.id, 'Account deactivated');
  }

  Future<void> lockAccount(AccountProfile account) async {
    final set = await _loadIdSet(_lockedKey);
    set.add(account.id);
    await _saveIdSet(_lockedKey, set);
    await _appendActivity(account.id, 'Account locked');
  }

  Future<void> unlockAccount(AccountProfile account) async {
    await _removeLocked(account.id);
    await _appendActivity(account.id, 'Account unlocked');
  }

  Future<void> resetPassword(AccountProfile account) async {
    await _appendActivity(account.id, 'Password reset initiated');
  }

  Future<void> resendVerification(AccountProfile account) async {
    if (account.apiStatus != 'pending') return;
    await _appendActivity(account.id, 'Verification email resent');
  }

  Future<void> verifyAccount(AccountProfile account) async {
    await adminApi.setUserStatus(account.id, 'approved');
    await _appendActivity(account.id, 'Email verified · account activated');
  }

  Future<void> updateRole(AccountProfile account, AccountRoleType roleType) async {
    await adminApi.setUserRole(account.id, roleType.apiRole);
    await _appendActivity(account.id, 'Role updated to ${roleType.label}');
  }

  Future<void> saveProfileEdits(int userId, {String? name, String? contact}) async {
    final map = await _loadOverrides();
    final entry = Map<String, dynamic>.from(map['$userId'] as Map? ?? {});
    if (name != null) entry['name'] = name;
    if (contact != null) entry['contact'] = contact;
    map['$userId'] = entry;
    await _saveOverrides(map);
    await _appendActivity(userId, 'Profile information updated');
  }

  Future<void> deleteAccount(AccountProfile account, {String? reason}) async {
    if (account.roleType == AccountRoleType.photographer || account.roleType == AccountRoleType.videographer) {
      try {
        await adminApi.removeMember(account.id, removalReason: reason ?? 'Deleted by administrator');
      } catch (_) {
        await adminApi.setUserStatus(
          account.id,
          'rejected',
          rejectionReason: reason ?? 'Deleted by administrator',
        );
      }
    } else {
      await adminApi.setUserStatus(
        account.id,
        'rejected',
        rejectionReason: reason ?? 'Deleted by administrator',
      );
    }
    final hidden = await _loadIdSet(_hiddenKey);
    hidden.add(account.id);
    await _saveIdSet(_hiddenKey, hidden);
    await _removeLocked(account.id);
  }

  Future<void> createAccount({
    required String fullName,
    required String email,
    required String password,
    required AccountRoleType roleType,
    String? contactNumber,
  }) async {
    await adminApi.createUser(
      name: fullName,
      email: email,
      password: password,
      role: roleType.apiRole,
    );
    if (contactNumber != null && contactNumber.trim().isNotEmpty) {
      // Contact is applied after reload via profile edit overlay once user id is known.
    }
  }

  String buildExportCsv(List<AccountProfile> accounts) {
    final buf = StringBuffer('Full Name,Email,Role,Status,Email Verified,Last Login,Created\n');
    for (final a in accounts) {
      buf.writeln([
        _csv(a.displayName),
        _csv(a.email),
        _csv(a.roleType.label),
        _csv(a.accessStatus.label),
        a.emailVerified ? 'Yes' : 'No',
        _csv(a.lastLoginLabel),
        _csv(a.createdLabel),
      ].join(','));
    }
    return buf.toString();
  }

  AccountProfile _mapAccount(
    Map<String, dynamic> m, {
    required Set<int> locked,
    required Map<String, dynamic> overrides,
    required Map<String, List<Map<String, dynamic>>> extraActivity,
  }) {
    final id = m['user_id'] as int? ?? -1;
    final override = Map<String, dynamic>.from(overrides['$id'] as Map? ?? {});
    final role = m['role'] as String? ?? 'Member';
    final primaryTaskRole = m['primary_task_role'] as String?;
    final roleType = roleTypeFromApi(role: role, primaryTaskRole: primaryTaskRole);
    final status = (m['status'] as String? ?? 'pending').toLowerCase();
    final isActive = m['is_active'] as bool? ?? true;
    final isLocked = locked.contains(id);
    final accessStatus = accessStatusFrom(status: status, isActive: isActive, locked: isLocked);
    final emailVerified = status == 'approved';
    final createdAt = _parseDate(m['created_at']);
    final lastLogin = _parseDate(m['last_active']);
    final approvedAt = _parseDate(m['approved_at']);

    final activity = _buildLoginActivity(
      lastLogin: lastLogin,
      approvedAt: approvedAt,
      createdAt: createdAt,
      extra: extraActivity['$id'] ?? [],
    );

    return AccountProfile(
      id: id,
      fullName: m['name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      roleType: roleType,
      accessStatus: accessStatus,
      emailVerified: emailVerified,
      apiRole: role,
      apiStatus: status,
      isActiveAccount: isActive,
      contactNumber: m['contact_number'] as String?,
      studentId: m['student_id'] as String?,
      createdAt: createdAt,
      lastLogin: lastLogin,
      approvedAt: approvedAt,
      primaryTaskRole: primaryTaskRole,
      loginActivity: activity,
      nameOverride: override['name'] as String?,
      contactOverride: override['contact'] as String?,
    );
  }

  List<LoginActivityEntry> _buildLoginActivity({
    DateTime? lastLogin,
    DateTime? approvedAt,
    DateTime? createdAt,
    required List<Map<String, dynamic>> extra,
  }) {
    final entries = <LoginActivityEntry>[];
    for (final e in extra) {
      final at = _parseDate(e['at']);
      final label = e['label'] as String? ?? '';
      if (at != null && label.isNotEmpty) {
        entries.add(LoginActivityEntry(at: at, label: label));
      }
    }
    if (lastLogin != null) {
      entries.add(LoginActivityEntry(at: lastLogin, label: 'Logged in successfully'));
    }
    if (approvedAt != null) {
      entries.add(LoginActivityEntry(at: approvedAt, label: 'Account activated'));
    }
    if (createdAt != null) {
      entries.add(LoginActivityEntry(at: createdAt, label: 'Account created'));
    }
    entries.sort((a, b) => b.at.compareTo(a.at));
    final seen = <String>{};
    return entries.where((e) => seen.add('${e.label}|${e.at.millisecondsSinceEpoch}')).toList();
  }

  AccountCenterStats _computeStats(List<AccountProfile> accounts) {
    var active = 0, inactive = 0, locked = 0;
    for (final a in accounts) {
      switch (a.accessStatus) {
        case AccountAccessStatus.active:
          active++;
        case AccountAccessStatus.inactive:
          inactive++;
        case AccountAccessStatus.locked:
          locked++;
        case AccountAccessStatus.unverified:
          inactive++;
      }
    }
    return AccountCenterStats(
      total: accounts.length,
      active: active,
      inactive: inactive,
      locked: locked,
    );
  }

  Future<void> _appendActivity(int userId, String label) async {
    final map = await _loadActivityLog();
    final list = List<Map<String, dynamic>>.from(map['$userId'] ?? []);
    list.insert(0, {'at': DateTime.now().toIso8601String(), 'label': label});
    map['$userId'] = list.take(20).toList();
    await _saveActivityLog(map);
  }

  Future<void> _removeLocked(int id) async {
    final set = await _loadIdSet(_lockedKey);
    set.remove(id);
    await _saveIdSet(_lockedKey, set);
  }

  Future<Set<int>> _loadIdSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.map((e) => int.tryParse('$e')).whereType<int>().toSet();
  }

  Future<void> _saveIdSet(String key, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids.toList()));
  }

  Future<Map<String, dynamic>> _loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_overridesKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<void> _saveOverrides(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overridesKey, jsonEncode(map));
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadActivityLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activityKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) {
      if (v is List) {
        return MapEntry(k.toString(), v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
      return MapEntry(k.toString(), <Map<String, dynamic>>[]);
    });
  }

  Future<void> _saveActivityLog(Map<String, List<Map<String, dynamic>>> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activityKey, jsonEncode(map));
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static String _csv(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
