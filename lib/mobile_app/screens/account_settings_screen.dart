import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

/// Account-related settings — reuses [EditProfileScreen] for profile edits.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMemberDashboardBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kDashTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Settings',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
        ),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final isRequestor = authController.user?.role == AccessRole.organization;
          final fallbackName = isRequestor ? 'Requestor' : 'Member';
          final name = appState.profileName.trim().isNotEmpty
              ? appState.profileName.trim()
              : authController.user?.name ?? fallbackName;
          final email = appState.profileEmail.trim().isNotEmpty
              ? appState.profileEmail.trim()
              : authController.user?.email ?? '—';

          return ListView(
            padding: mobileScrollPadding(context, top: 12),
            children: [
              MemberDashboardCard(
                showAccentStrip: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your account', style: memberDashboardCardTitleStyle.copyWith(fontSize: 15)),
                    const SizedBox(height: 14),
                    _InfoRow(label: 'Full name', value: name),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Email', value: email),
                    if (appState.profileAccountRole.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Role', value: appState.profileAccountRole),
                    ],
                    if (appState.profileStatus.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Status', value: appState.profileStatus),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Photo, name, and contact number',
                onTap: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                  if (saved == true && context.mounted) {
                    await memberDataController.refreshAll();
                  }
                },
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.dns_outlined,
                  title: 'Backend connection',
                  subtitle: ApiConfig.baseUrl,
                  onTap: () => showBackendUrlDialog(context),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Email changes require an administrator. Use Edit profile for name, photo, and contact.',
                style: memberDashboardMetaStyle.copyWith(height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: memberDashboardBodyStyle.copyWith(color: kDashTextPrimary)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(color: kDashBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: kMemberDashboardAccent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: memberDashboardCardTitleStyle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kDashTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
