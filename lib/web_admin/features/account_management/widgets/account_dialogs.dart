import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class AccountDialogs {
  AccountDialogs._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(color: AdminTheme.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: AdminTheme.danger) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<AccountCreateForm?> showAddAccount(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    var role = AccountRoleType.photographer;

    final result = await showDialog<AccountCreateForm>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email address', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Temporary password', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(labelText: 'Contact number (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<AccountRoleType>(
                    value: role,
                    isExpanded: true,
                    items: AccountRoleType.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    onChanged: (v) => setLocal(() => role = v ?? role),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final password = passwordCtrl.text.trim();
                if (name.isEmpty || email.isEmpty || password.length < 6) return;
                Navigator.pop(
                  ctx,
                  AccountCreateForm(
                    fullName: name,
                    email: email,
                    password: password,
                    roleType: role,
                    contactNumber: contactCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    contactCtrl.dispose();
    return result;
  }

  static Future<AccountEditForm?> showEditAccount(BuildContext context, AccountProfile account) async {
    final nameCtrl = TextEditingController(text: account.displayName);
    final contactCtrl = TextEditingController(text: account.contactNumber ?? account.contactOverride ?? '');

    final result = await showDialog<AccountEditForm>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Basic Information', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              const Text(
                'Email and role changes use dedicated account actions.',
                style: TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              AccountEditForm(name: nameCtrl.text.trim(), contact: contactCtrl.text.trim()),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    contactCtrl.dispose();
    return result;
  }

  static Future<AccountRoleType?> showChangeRole(BuildContext context, AccountRoleType current) async {
    var selected = current;
    return showDialog<AccountRoleType>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Role', style: TextStyle(fontWeight: FontWeight.w800)),
          content: DropdownButton<AccountRoleType>(
            value: selected,
            isExpanded: true,
            items: AccountRoleType.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
            onChanged: (v) => setLocal(() => selected = v ?? selected),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Update Role')),
          ],
        ),
      ),
    );
  }
}

class AccountCreateForm {
  const AccountCreateForm({
    required this.fullName,
    required this.email,
    required this.password,
    required this.roleType,
    this.contactNumber,
  });

  final String fullName;
  final String email;
  final String password;
  final AccountRoleType roleType;
  final String? contactNumber;
}

class AccountEditForm {
  const AccountEditForm({required this.name, required this.contact});

  final String name;
  final String contact;
}
