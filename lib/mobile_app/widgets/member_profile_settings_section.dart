import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/account_settings_screen.dart';
import 'package:access_mobile/mobile_app/screens/change_password_screen.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/screens/legal_privacy_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';

/// Neutral icon styling for profile settings rows.
const _kSettingsIconColor = kTextPrimary;

/// Account & settings list on the member Profile tab.
class MemberProfileSettingsSection extends StatelessWidget {
  const MemberProfileSettingsSection({super.key, this.forRequestor = false});

  final bool forRequestor;

  Future<void> _openEditProfile(BuildContext context) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (saved == true && context.mounted) {
      await memberDataController.refreshAll();
    }
  }

  void _openAccountSettings(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSettingsScreen(forRequestor: forRequestor),
      ),
    );
  }

  void _openLegalPrivacy(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LegalPrivacyScreen(forRequestor: forRequestor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AccessSectionHeader(title: 'Account & Settings'),
        const SizedBox(height: 10),
        MemberDashboardCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                description: 'Photo, name, and verified contact number',
                onTap: () => _openEditProfile(context),
              ),
              const Divider(height: 1, indent: 56),
              _SettingsRow(
                icon: Icons.settings_rounded,
                title: 'Account Settings',
                description: 'Account summary and sign-in options',
                onTap: () => _openAccountSettings(context),
              ),
              const Divider(height: 1, indent: 56),
              _SettingsRow(
                icon: Icons.lock_rounded,
                title: 'Change Password',
                description: 'Update your sign-in password',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),
              const Divider(height: 1, indent: 56),
              _SettingsRow(
                icon: Icons.gavel_rounded,
                title: 'Legal & Privacy',
                description: 'Terms, privacy policy, and content standards',
                onTap: () => _openLegalPrivacy(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              MemberDashboardIconTile(
                icon: icon,
                size: 38,
                iconSize: 19,
                color: _kSettingsIconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: memberDashboardCardTitleStyle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kTextSecondary.withValues(alpha: 0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
