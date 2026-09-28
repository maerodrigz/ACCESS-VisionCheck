import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/themes/theme.dart';

void openAccessLegalDocument(BuildContext context, AccessLegalDocument document) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(document: document)),
  );
}

/// Scrollable legal document (Terms, Privacy, Content Standards).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final AccessLegalDocument document;

  @override
  Widget build(BuildContext context) {
    final sections = accessLegalSections(document);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          document.title,
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
          const SizedBox(height: 20),
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            _LegalSectionBlock(section: sections[i]),
          ],
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
