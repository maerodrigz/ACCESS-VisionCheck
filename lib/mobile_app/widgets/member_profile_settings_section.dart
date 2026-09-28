import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/account_settings_screen.dart';
import 'package:access_mobile/mobile_app/screens/change_password_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/screens/legal_document_screen.dart';

/// Neutral icon styling for profile settings rows.
const _kSettingsIconColor = kTextPrimary;

/// Account & settings list on the member Profile tab.
class MemberProfileSettingsSection extends StatelessWidget {
  const MemberProfileSettingsSection({super.key, this.forRequestor = false});

  final bool forRequestor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AccessSectionHeader(title: 'Account & Settings'),
        const SizedBox(height: 12),
        MemberDashboardCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.settings_rounded,
                title: 'Account Settings',
                description: 'Profile, email, and connection options',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                ),
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        const AccessSectionHeader(title: 'Legal'),
        const SizedBox(height: 12),
        MemberDashboardCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms and Conditions',
                description: 'Platform rules and acceptable use',
                onTap: () => openAccessLegalDocument(context, AccessLegalDocument.terms),
              ),
              const Divider(height: 1, indent: 56),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                description: 'How your data and media are handled',
                onTap: () => openAccessLegalDocument(context, AccessLegalDocument.privacy),
              ),
              const Divider(height: 1, indent: 56),
              _SettingsRow(
                icon: Icons.policy_outlined,
                title: 'Content Standards',
                description: forRequestor
                    ? 'Documentation quality and platform standards'
                    : 'Upload rules for evaluations and coverage',
                onTap: () => openAccessLegalDocument(context, AccessLegalDocument.contentStandards),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              MemberDashboardIconTile(
                icon: icon,
                size: 40,
                iconSize: 20,
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
