import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_models.dart';
import 'package:access_mobile/web_admin/features/account_management/widgets/account_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef AccountTap = void Function(AccountProfile account);

class AccountCard extends StatefulWidget {
  const AccountCard({super.key, required this.account, required this.onManage});

  final AccountProfile account;
  final AccountTap onManage;

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool _hovered = false;

  AccountProfile get a => widget.account;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: AdminTheme.cardDecoration().copyWith(
          border: Border.all(
            color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.35) : AdminTheme.border,
          ),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccountAvatar(account: a, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.displayName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.email,
                        style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                AccountRoleBadge(roleType: a.roleType),
                AccountStatusBadge(status: a.accessStatus),
                VerificationBadge(verified: a.emailVerified),
              ],
            ),
            const SizedBox(height: 14),
            _MetaRow(icon: Icons.login, label: 'Last login', value: a.lastLoginLabel),
            const SizedBox(height: 6),
            _MetaRow(icon: Icons.calendar_today_outlined, label: 'Created', value: a.createdLabel),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => widget.onManage(a),
              style: FilledButton.styleFrom(
                backgroundColor: AdminTheme.accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Manage Account', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AdminTheme.textSecondary),
        const SizedBox(width: 6),
        Text('$label · ', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
