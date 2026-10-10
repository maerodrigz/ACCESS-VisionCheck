import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/themes/theme.dart';

void openAccessLegalDocument(
  BuildContext context,
  AccessLegalDocument document, {
  RegistrationLegalAudience? registrationAudience,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(
        document: document,
        registrationAudience: registrationAudience,
      ),
    ),
  );
}

/// Scrollable legal document (Terms, Privacy, Content Standards).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
    this.registrationAudience,
  });

  final AccessLegalDocument document;
  final RegistrationLegalAudience? registrationAudience;

  @override
  Widget build(BuildContext context) {
    final sections = accessLegalSections(document, registrationAudience: registrationAudience);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          registrationAudience != null
              ? document.registrationTitle(registrationAudience!)
              : document.title,
          style: dashText(const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Text(
            'Last updated: ${document.lastUpdated}',
            style: dashText(const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          if (registrationAudience != null) ...[
            const SizedBox(height: 8),
            Text(
              'Written for ${registrationAudienceLabel(registrationAudience!)} registration.',
              style: dashText(const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
          const SizedBox(height: 20),
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            _LegalSectionBlock(section: sections[i]),
          ],
          const SizedBox(height: 24),
          Text(
            registrationAudience != null
                ? 'This document applies to ${registrationAudienceLabel(registrationAudience!)} accounts. '
                    'For other roles, see the combined policies linked at login or ask an administrator.'
                : 'For role-specific terms, open Legal from your Profile after sign-in.',
            style: dashText(const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45)),
          ),
          const SizedBox(height: 12),
          Text(
            'Questions? Contact your ACCESS administrator at USTP Oroquieta Campus.',
            style: dashText(const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({required this.section});

  final AccessLegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.25,
            )),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: dashText(const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            )),
          ),
        ],
      ),
    );
  }
}
