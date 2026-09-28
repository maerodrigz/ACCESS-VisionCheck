import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class ProfileDropdown extends StatelessWidget {
  const ProfileDropdown({super.key, required this.user, this.iconOnly = false});

  final AuthUser user;
  final bool iconOnly;

  Future<void> _logout(BuildContext context) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will return to the login screen.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (ok == true) authController.logout();
  }

  void _navigate(BuildContext context, AdminRoute route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminNavigationScope.go(context, route);
    });
  }

  void _showMyProfile(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileRow('Name', user.name),
            _profileRow('Email', user.email),
            _profileRow('Role', user.role.displayLabel),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  static Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role.isAdmin;

    return PopupMenuButton<void>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        _ProfileMenuHeaderEntry(user: user),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => _showMyProfile(context),
          child: const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AdminTheme.textPrimary),
              SizedBox(width: 10),
              Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (isAdmin) ...[
          const PopupMenuDivider(),
          const _ProfileMenuSectionLabelEntry(label: 'Administration'),
          PopupMenuItem<void>(
            onTap: () => _navigate(context, AdminRoute.branding),
            child: const Row(
              children: [
                Icon(Icons.settings_outlined, size: 18, color: AdminTheme.textPrimary),
                SizedBox(width: 10),
                Text('System Configuration', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => _logout(context),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AdminTheme.danger),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: AdminTheme.danger, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!iconOnly) ...[
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.role.displayLabel,
                    style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          CircleAvatar(
            radius: iconOnly ? 18 : 20,
            backgroundColor: AdminTheme.accentBlue,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: iconOnly ? 14 : 15,
              ),
            ),
          ),
          if (!iconOnly)
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AdminTheme.textSecondary),
        ],
      ),
    );
  }
}

/// Header block — not a disabled menu item, so text stays full contrast.
class _ProfileMenuHeaderEntry extends PopupMenuEntry<void> {
  const _ProfileMenuHeaderEntry({required this.user});

  final AuthUser user;

  @override
  final double height = 76;

  @override
  bool represents(void value) => false;

  @override
  State<_ProfileMenuHeaderEntry> createState() => _ProfileMenuHeaderEntryState();
}

class _ProfileMenuHeaderEntryState extends State<_ProfileMenuHeaderEntry> {
  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            user.role.displayLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminTheme.accentBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuSectionLabelEntry extends PopupMenuEntry<void> {
  const _ProfileMenuSectionLabelEntry({required this.label});

  final String label;

  @override
  final double height = 32;

  @override
  bool represents(void value) => false;

  @override
  State<_ProfileMenuSectionLabelEntry> createState() => _ProfileMenuSectionLabelEntryState();
}

class _ProfileMenuSectionLabelEntryState extends State<_ProfileMenuSectionLabelEntry> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        widget.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AdminTheme.textSecondary.withValues(alpha: 0.9),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
