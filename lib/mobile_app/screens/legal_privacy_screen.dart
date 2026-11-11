import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/screens/legal_document_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Hub for Terms, Privacy, and Content Standards from the member Profile tab.
class LegalPrivacyScreen extends StatelessWidget {
  const LegalPrivacyScreen({
    super.key,
    this.forRequestor = false,
  });

  final bool forRequestor;

  RegistrationLegalAudience get _audience => forRequestor
      ? RegistrationLegalAudience.requestor
      : RegistrationLegalAudience.member;

  void _open(BuildContext context, AccessLegalDocument document) {
    openAccessLegalDocument(
      context,
      document,
      registrationAudience: _audience,
    );
  }

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
          'Legal & Privacy',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
        ),
      ),
      body: ListView(
        padding: mobileScrollPadding(context, top: 12),
        children: [
          Text(
            forRequestor
                ? 'Policies for requestor accounts at USTP Oroquieta.'
                : 'Policies for documentation members and practice uploads.',
            style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          MemberDashboardCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LegalRow(
                  icon: Icons.description_outlined,
                  title: AccessLegalDocument.terms.title,
                  subtitle: 'Platform rules and acceptable use',
                  onTap: () => _open(context, AccessLegalDocument.terms),
                ),
                const Divider(height: 1, indent: 56),
                _LegalRow(
                  icon: Icons.privacy_tip_outlined,
                  title: AccessLegalDocument.privacy.title,
                  subtitle: 'How your data and media are handled',
                  onTap: () => _open(context, AccessLegalDocument.privacy),
                ),
                const Divider(height: 1, indent: 56),
                _LegalRow(
                  icon: Icons.policy_outlined,
                  title: 'Content Standards',
                  subtitle: forRequestor
                      ? 'Requests, feedback, and documentation use'
                      : 'Upload rules for evaluations and coverage',
                  onTap: () => _open(context, AccessLegalDocument.contentStandards),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated ${AccessLegalDocument.terms.lastUpdated}. '
            'Contact your ACCESS administrator at USTP Oroquieta for questions.',
            style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
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
                color: kTextPrimary,
              ),
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
