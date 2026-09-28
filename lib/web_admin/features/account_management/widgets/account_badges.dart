import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge({super.key, required this.status});

  final AccountAccessStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status.color)),
        ],
      ),
    );
  }
}

class AccountRoleBadge extends StatelessWidget {
  const AccountRoleBadge({super.key, required this.roleType});

  final AccountRoleType roleType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTheme.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roleType.icon, size: 12, color: AdminTheme.accentBlue),
          const SizedBox(width: 4),
          Text(roleType.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AdminTheme.accentBlue)),
        ],
      ),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AdminTheme.success : AdminTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_outlined : Icons.mark_email_unread_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(verified ? 'Verified' : 'Unverified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.radius = 28});

  final AccountProfile account;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
      backgroundImage: account.profileImageUrl != null ? NetworkImage(account.profileImageUrl!) : null,
      child: account.profileImageUrl == null
          ? Text(
              account.initials,
              style: TextStyle(
                color: AdminTheme.accentBlue,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.55,
              ),
            )
          : null,
    );
  }
}
