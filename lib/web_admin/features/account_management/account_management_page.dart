import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_models.dart';
import 'package:access_mobile/web_admin/features/account_management/account_management_repository.dart';
import 'package:access_mobile/web_admin/features/account_management/widgets/account_card.dart';
import 'package:access_mobile/web_admin/features/account_management/widgets/account_details_drawer.dart';
import 'package:access_mobile/web_admin/features/account_management/widgets/account_dialogs.dart';
import 'package:access_mobile/web_admin/features/account_management/widgets/account_overview_cards.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Account Management Dashboard — user accounts, access control, and login activity.
class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final _repo = AccountManagementRepository();
  final _searchController = TextEditingController();

  AccountManagementData? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  AccountFilterChip _chip = AccountFilterChip.all;

  AccountProfile? _selected;
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          if (_selected != null) {
            final id = _selected!.id;
            _selected = data.accounts.where((a) => a.id == id).firstOrNull ?? _selected;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<AccountProfile> get _visible {
    final data = _data;
    if (data == null) return [];
    return _repo.filter(items: data.accounts, chip: _chip, search: _search);
  }

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _openDrawer(AccountProfile account) => setState(() {
        _selected = account;
        _drawerOpen = true;
      });

  void _closeDrawer() => setState(() => _drawerOpen = false);

  Future<void> _exportUsers() async {
    final data = _data;
    if (data == null) return;
    await Clipboard.setData(ClipboardData(text: _repo.buildExportCsv(_visible)));
    _toast('User list copied to clipboard (CSV)');
  }

  Future<void> _addAccount() async {
    final form = await AccountDialogs.showAddAccount(context);
    if (form == null) return;
    try {
      await _repo.createAccount(
        fullName: form.fullName,
        email: form.email,
        password: form.password,
        roleType: form.roleType,
        contactNumber: form.contactNumber,
      );
      await _load();
      _toast('Account created successfully');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  AccountProfile? get _active => _selected;

  Future<void> _withConfirm(
    String title,
    String message, {
    required Future<void> Function() action,
    bool destructive = false,
    String confirmLabel = 'Confirm',
  }) async {
    final account = _active;
    if (account == null) return;
    final ok = await AccountDialogs.confirm(
      context,
      title: title,
      message: message,
      destructive: destructive,
      confirmLabel: confirmLabel,
    );
    if (!ok || !mounted) return;
    try {
      await action();
      await _load();
      _toast('$title completed');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _changeRole(AccountProfile? account) async {
    if (account == null) return;
    final role = await AccountDialogs.showChangeRole(context, account.roleType);
    if (role == null || role == account.roleType) return;
    if (!mounted) return;
    final ok = await AccountDialogs.confirm(
      context,
      title: 'Change role',
      message: 'Update ${account.displayName} to ${role.label}?',
    );
    if (!ok || !mounted) return;
    try {
      await _repo.updateRole(account, role);
      await _load();
      _toast('Role updated');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = AdminBreakpoints.pagePadding(context);
    final accounts = _visible;
    final narrow = AdminBreakpoints.widthOf(context) < 720;

    return Container(
      color: AdminTheme.contentBg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: padding.copyWith(bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(narrow),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, role, or status…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final chip in AccountFilterChip.values) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(chip.label),
                                selected: _chip == chip,
                                onSelected: (_) => setState(() => _chip = chip),
                                selectedColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                                checkmarkColor: AdminTheme.accentBlue,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _chip == chip ? AdminTheme.accentBlue : AdminTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AdminTheme.accentBlue))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: padding.copyWith(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_data != null) AccountOverviewCards(stats: _data!.stats),
                                const SizedBox(height: 24),
                                const Text('User Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Manage authentication, account status, and platform access. Performance data lives in other modules.',
                                  style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                if (accounts.isEmpty)
                                  const AdminEmptyState(
                                    title: 'No accounts match filters',
                                    message: 'Try adjusting filters or search terms.',
                                    icon: Icons.manage_accounts_outlined,
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 720 ? 2 : 1;
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cols,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                          childAspectRatio: cols == 1 ? 0.95 : 0.82,
                                        ),
                                        itemCount: accounts.length,
                                        itemBuilder: (_, i) => AccountCard(
                                          account: accounts[i],
                                          onManage: _openDrawer,
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
              ),
            ],
          ),
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(onTap: _closeDrawer, child: Container(color: Colors.black.withValues(alpha: 0.25))),
            ),
          AccountDetailsDrawer(
            account: _selected,
            open: _drawerOpen,
            onClose: _closeDrawer,
            onActivate: () => _withConfirm(
              'Activate account',
              'Restore platform access for ${_active?.displayName}?',
              action: () => _repo.activateAccount(_active!),
            ),
            onDeactivate: () => _withConfirm(
              'Deactivate account',
              'This will block sign-in for ${_active?.displayName}. Continue?',
              destructive: true,
              confirmLabel: 'Deactivate',
              action: () => _repo.deactivateAccount(_active!),
            ),
            onLock: () => _withConfirm(
              'Lock account',
              'Lock ${_active?.displayName} until an administrator unlocks it?',
              destructive: true,
              confirmLabel: 'Lock',
              action: () => _repo.lockAccount(_active!),
            ),
            onUnlock: () => _withConfirm(
              'Unlock account',
              'Restore sign-in access for ${_active?.displayName}?',
              action: () => _repo.unlockAccount(_active!),
            ),
            onResetPassword: () => _withConfirm(
              'Reset password',
              'Send a password reset instruction for ${_active?.email}?',
              action: () => _repo.resetPassword(_active!),
              confirmLabel: 'Reset',
            ),
            onResendVerification: () => _withConfirm(
              'Resend verification',
              'Send a new verification email to ${_active?.email}?',
              action: () async {
                await _repo.resendVerification(_active!);
              },
            ),
            onEdit: () async {
              final account = _active;
              if (account == null) return;
              final form = await AccountDialogs.showEditAccount(context, account);
              if (form == null) return;
              try {
                await _repo.saveProfileEdits(account.id, name: form.name, contact: form.contact);
                await _load();
                _toast('Profile updated');
              } catch (e) {
                _toast(e.toString(), success: false);
              }
            },
            onDelete: () => _withConfirm(
              'Delete account',
              'Permanently remove ${_active?.displayName} from the platform? This cannot be undone.',
              destructive: true,
              confirmLabel: 'Delete',
              action: () => _repo.deleteAccount(_active!),
            ),
            onChangeRole: () => _changeRole(_active),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool narrow) {
    final actions = [
      OutlinedButton.icon(
        onPressed: _data == null ? null : _exportUsers,
        icon: const Icon(Icons.download_outlined, size: 18),
        label: Text(narrow ? 'Export' : 'Export Users'),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: _addAccount,
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: Text(narrow ? 'Add' : 'Add Account'),
        style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
      ),
      const SizedBox(width: 8),
      PageHeaderRefreshButton(onPressed: _load),
    ];

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage user accounts, authentication, access status, and login activity.',
            style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Management',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
              ),
              SizedBox(height: 6),
              Text(
                'Manage user accounts, authentication, access status, and login activity.',
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}
