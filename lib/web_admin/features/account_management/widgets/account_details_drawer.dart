import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_models.dart';
import 'package:access_mobile/web_admin/features/account_management/widgets/account_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class AccountDetailsDrawer extends StatelessWidget {
  const AccountDetailsDrawer({
    super.key,
    required this.account,
    required this.open,
    required this.onClose,
    required this.onActivate,
    required this.onDeactivate,
    required this.onLock,
    required this.onUnlock,
    required this.onResetPassword,
    required this.onResendVerification,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeRole,
  });

  final AccountProfile? account;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback onResetPassword;
  final VoidCallback onResendVerification;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChangeRole;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: open ? 0 : -620,
      width: 580,
      child: Material(
        elevation: 16,
        child: Container(
          decoration: const BoxDecoration(
            color: AdminTheme.surface,
            border: Border(left: BorderSide(color: AdminTheme.border)),
          ),
          child: a == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(name: a.displayName, onClose: onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: AccountAvatar(account: a, radius: 40)),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                a.displayName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
                              ),
                            ),
                            Center(
                              child: Text(a.email, style: const TextStyle(fontSize: 13, color: AdminTheme.textSecondary)),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                AccountRoleBadge(roleType: a.roleType),
                                AccountStatusBadge(status: a.accessStatus),
                                VerificationBadge(verified: a.emailVerified),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const _SectionTitle('ACCOUNT DETAILS'),
                            const SizedBox(height: 8),
                            _DetailRow(label: 'Full name', value: a.displayName),
                            _DetailRow(label: 'Email address', value: a.email),
                            _DetailRow(label: 'Contact number', value: a.displayContact),
                            _DetailRow(label: 'Role', value: a.roleType.label),
                            _DetailRow(label: 'Account status', value: a.accessStatus.label),
                            _DetailRow(label: 'Email verification', value: a.emailVerified ? 'Verified' : 'Unverified'),
                            _DetailRow(label: 'Date created', value: a.createdLabel),
                            _DetailRow(label: 'Last login', value: a.lastLoginLabel),
                            const SizedBox(height: 20),
                            const _SectionTitle('RECENT LOGIN ACTIVITY'),
                            const SizedBox(height: 8),
                            if (a.loginActivity.isEmpty)
                              const Text('No activity recorded yet.', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary))
                            else
                              _ActivityList(entries: a.loginActivity),
                            const SizedBox(height: 24),
                            const _SectionTitle('ACCOUNT ACTIONS'),
                            const SizedBox(height: 10),
                            _ActionGrid(
                              account: a,
                              onActivate: onActivate,
                              onDeactivate: onDeactivate,
                              onLock: onLock,
                              onUnlock: onUnlock,
                              onResetPassword: onResetPassword,
                              onResendVerification: onResendVerification,
                              onEdit: onEdit,
                              onDelete: onDelete,
                              onChangeRole: onChangeRole,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onClose});

  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Manage Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminTheme.textSecondary, letterSpacing: 0.6));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary))),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.entries});

  final List<LoginActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<LoginActivityEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.timelineGroup, () => []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(group.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminTheme.textSecondary)),
          ),
          for (final e in group.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AdminTheme.accentBlue, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.account,
    required this.onActivate,
    required this.onDeactivate,
    required this.onLock,
    required this.onUnlock,
    required this.onResetPassword,
    required this.onResendVerification,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeRole,
  });

  final AccountProfile account;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback onResetPassword;
  final VoidCallback onResendVerification;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChangeRole;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (a.accessStatus != AccountAccessStatus.active)
          _ActionButton(icon: Icons.check_circle_outline, label: 'Activate', onTap: onActivate),
        if (a.accessStatus == AccountAccessStatus.active)
          _ActionButton(icon: Icons.pause_circle_outline, label: 'Deactivate', onTap: onDeactivate, danger: true),
        if (a.accessStatus != AccountAccessStatus.locked)
          _ActionButton(icon: Icons.lock_outline, label: 'Lock Account', onTap: onLock, danger: true),
        if (a.accessStatus == AccountAccessStatus.locked)
          _ActionButton(icon: Icons.lock_open_outlined, label: 'Unlock Account', onTap: onUnlock),
        _ActionButton(icon: Icons.password_outlined, label: 'Reset Password', onTap: onResetPassword),
        if (!a.emailVerified)
          _ActionButton(icon: Icons.mark_email_read_outlined, label: 'Resend Verification', onTap: onResendVerification),
        _ActionButton(icon: Icons.edit_outlined, label: 'Edit Information', onTap: onEdit),
        _ActionButton(icon: Icons.badge_outlined, label: 'Change Role', onTap: onChangeRole),
        _ActionButton(icon: Icons.delete_outline, label: 'Delete Account', onTap: onDelete, danger: true),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AdminTheme.danger : AdminTheme.accentBlue;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 168,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.08) : AdminTheme.contentBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.35) : AdminTheme.border),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
