import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Display account types for the Account Management dashboard.
enum AccountRoleType {
  administrator,
  photographer,
  videographer,
  requester;

  String get label => switch (this) {
        AccountRoleType.administrator => 'Administrator',
        AccountRoleType.photographer => 'Photographer',
        AccountRoleType.videographer => 'Videographer',
        AccountRoleType.requester => 'Requester',
      };

  IconData get icon => switch (this) {
        AccountRoleType.administrator => Icons.admin_panel_settings_outlined,
        AccountRoleType.photographer => Icons.camera_alt_outlined,
        AccountRoleType.videographer => Icons.videocam_outlined,
        AccountRoleType.requester => Icons.business_outlined,
      };

  /// Maps to PostgreSQL role name for API calls.
  String get apiRole => switch (this) {
        AccountRoleType.administrator => 'Admin',
        AccountRoleType.photographer => 'Member',
        AccountRoleType.videographer => 'Member',
        AccountRoleType.requester => 'Organization',
      };
}

enum AccountAccessStatus {
  active,
  inactive,
  locked,
  unverified;

  String get label => switch (this) {
        AccountAccessStatus.active => 'Active',
        AccountAccessStatus.inactive => 'Inactive',
        AccountAccessStatus.locked => 'Locked',
        AccountAccessStatus.unverified => 'Unverified',
      };

  Color get color => switch (this) {
        AccountAccessStatus.active => AdminTheme.success,
        AccountAccessStatus.inactive => AdminTheme.warning,
        AccountAccessStatus.locked => AdminTheme.danger,
        AccountAccessStatus.unverified => AdminTheme.textSecondary,
      };

  IconData get icon => switch (this) {
        AccountAccessStatus.active => Icons.check_circle_outline,
        AccountAccessStatus.inactive => Icons.pause_circle_outline,
        AccountAccessStatus.locked => Icons.lock_outline,
        AccountAccessStatus.unverified => Icons.mark_email_unread_outlined,
      };
}

enum AccountFilterChip {
  all,
  administrators,
  photographers,
  videographers,
  requesters,
  active,
  inactive,
  locked,
  unverified;

  String get label => switch (this) {
        AccountFilterChip.all => 'All Accounts',
        AccountFilterChip.administrators => 'Administrators',
        AccountFilterChip.photographers => 'Photographers',
        AccountFilterChip.videographers => 'Videographers',
        AccountFilterChip.requesters => 'Requesters',
        AccountFilterChip.active => 'Active',
        AccountFilterChip.inactive => 'Inactive',
        AccountFilterChip.locked => 'Locked',
        AccountFilterChip.unverified => 'Unverified',
      };
}

class AccountCenterStats {
  const AccountCenterStats({
    required this.total,
    required this.active,
    required this.inactive,
    required this.locked,
  });

  final int total;
  final int active;
  final int inactive;
  final int locked;
}

class LoginActivityEntry {
  const LoginActivityEntry({required this.at, required this.label});

  final DateTime at;
  final String label;

  String get timelineGroup => activityTimelineGroup(at);
}

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roleType,
    required this.accessStatus,
    required this.emailVerified,
    required this.apiRole,
    required this.apiStatus,
    required this.isActiveAccount,
    this.contactNumber,
    this.studentId,
    this.profileImageUrl,
    this.createdAt,
    this.lastLogin,
    this.approvedAt,
    this.primaryTaskRole,
    this.loginActivity = const [],
    this.nameOverride,
    this.contactOverride,
  });

  final int id;
  final String fullName;
  final String email;
  final AccountRoleType roleType;
  final AccountAccessStatus accessStatus;
  final bool emailVerified;
  final String apiRole;
  final String apiStatus;
  final bool isActiveAccount;
  final String? contactNumber;
  final String? studentId;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final DateTime? approvedAt;
  final String? primaryTaskRole;
  final List<LoginActivityEntry> loginActivity;
  final String? nameOverride;
  final String? contactOverride;

  String get displayName => nameOverride ?? fullName;
  String get displayContact => contactOverride ?? contactNumber ?? '—';

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get createdLabel => formatAccountDateTime(createdAt);
  String get lastLoginLabel => lastLogin == null ? 'Never' : formatAccountDateTime(lastLogin);

  bool matchesFilter(AccountFilterChip chip) {
    return switch (chip) {
      AccountFilterChip.all => true,
      AccountFilterChip.administrators => roleType == AccountRoleType.administrator,
      AccountFilterChip.photographers => roleType == AccountRoleType.photographer,
      AccountFilterChip.videographers => roleType == AccountRoleType.videographer,
      AccountFilterChip.requesters => roleType == AccountRoleType.requester,
      AccountFilterChip.active => accessStatus == AccountAccessStatus.active,
      AccountFilterChip.inactive => accessStatus == AccountAccessStatus.inactive,
      AccountFilterChip.locked => accessStatus == AccountAccessStatus.locked,
      AccountFilterChip.unverified => accessStatus == AccountAccessStatus.unverified,
    };
  }

  bool matchesSearch(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    return displayName.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q) ||
        roleType.label.toLowerCase().contains(q) ||
        accessStatus.label.toLowerCase().contains(q);
  }

  AccountProfile copyWith({
    String? nameOverride,
    String? contactOverride,
    AccountAccessStatus? accessStatus,
    bool? emailVerified,
    String? apiStatus,
    bool? isActiveAccount,
    List<LoginActivityEntry>? loginActivity,
  }) =>
      AccountProfile(
        id: id,
        fullName: fullName,
        email: email,
        roleType: roleType,
        accessStatus: accessStatus ?? this.accessStatus,
        emailVerified: emailVerified ?? this.emailVerified,
        apiRole: apiRole,
        apiStatus: apiStatus ?? this.apiStatus,
        isActiveAccount: isActiveAccount ?? this.isActiveAccount,
        contactNumber: contactNumber,
        studentId: studentId,
        profileImageUrl: profileImageUrl,
        createdAt: createdAt,
        lastLogin: lastLogin,
        approvedAt: approvedAt,
        primaryTaskRole: primaryTaskRole,
        loginActivity: loginActivity ?? this.loginActivity,
        nameOverride: nameOverride ?? this.nameOverride,
        contactOverride: contactOverride ?? this.contactOverride,
      );
}

class AccountManagementData {
  const AccountManagementData({required this.accounts, required this.stats});

  final List<AccountProfile> accounts;
  final AccountCenterStats stats;
}

String formatAccountDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ap = local.hour >= 12 ? 'PM' : 'AM';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $h:$m $ap';
}

String activityTimelineGroup(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${months[local.month - 1]} ${local.day}';
}

AccountRoleType roleTypeFromApi({
  required String role,
  String? primaryTaskRole,
}) {
  final r = role.toLowerCase();
  if (r == 'admin') return AccountRoleType.administrator;
  if (r == 'organization') return AccountRoleType.requester;
  final task = (primaryTaskRole ?? '').toLowerCase();
  if (task.contains('video')) return AccountRoleType.videographer;
  if (task.contains('photo')) return AccountRoleType.photographer;
  return AccountRoleType.photographer;
}

AccountAccessStatus accessStatusFrom({
  required String status,
  required bool isActive,
  required bool locked,
}) {
  if (locked) return AccountAccessStatus.locked;
  if (status == 'pending') return AccountAccessStatus.unverified;
  if (!isActive || status == 'rejected') return AccountAccessStatus.inactive;
  if (status == 'approved') return AccountAccessStatus.active;
  return AccountAccessStatus.inactive;
}
