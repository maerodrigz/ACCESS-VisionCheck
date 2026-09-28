/// ACCESS VisionCheck legal copy (Terms, Privacy, Content Standards).
enum AccessLegalDocument {
  terms,
  privacy,
  contentStandards,
}

extension AccessLegalDocumentMeta on AccessLegalDocument {
  String get title => switch (this) {
        AccessLegalDocument.terms => 'Terms and Conditions',
        AccessLegalDocument.privacy => 'Privacy Policy',
        AccessLegalDocument.contentStandards => 'Content Standards',
      };

  String get lastUpdated => 'August 30, 2026';
}

class AccessLegalSection {
  const AccessLegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

List<AccessLegalSection> accessLegalSections(AccessLegalDocument document) {
  return switch (document) {
    AccessLegalDocument.terms => _termsSections,
    AccessLegalDocument.privacy => _privacySections,
    AccessLegalDocument.contentStandards => _contentStandardsSections,
  };
}

const _termsSections = [
  AccessLegalSection(
    heading: '1. About ACCESS VisionCheck',
    body:
        'ACCESS VisionCheck is a documentation practice and media quality platform for the ACCESS '
        'documentation team at USTP Oroquieta Campus. By creating an account or using the app, '
        'you agree to these Terms and Conditions.',
  ),
  AccessLegalSection(
    heading: '2. Eligible use',
    body:
        'Accounts are for approved members, requestors, and administrators only. You must provide '
        'accurate registration information and keep your login credentials private. You may not share '
        'your account or use the platform for purposes outside university documentation activities.',
  ),
  AccessLegalSection(
    heading: '3. Media evaluations and uploads',
    body:
        'Practice evaluations use automated quality scoring and optional AI feedback. Uploads may be '
        'reviewed by administrators for authenticity, policy compliance, and documentation standards. '
        'Daily evaluation limits, XP, and rankings are governed by ACCESS admin configuration.',
  ),
  AccessLegalSection(
    heading: '4. Your content',
    body:
        'You keep ownership of photos and videos you upload. You grant ACCESS administrators a '
        'limited license to store, review, evaluate, and display your submissions inside the platform '
        'for documentation training, event coverage, gallery, and integrity review purposes.',
  ),
  AccessLegalSection(
    heading: '5. Prohibited conduct',
    body:
        'Do not upload inappropriate, illegal, or misleading content. Do not attempt to bypass AI '
        'integrity checks, abuse evaluation limits, harass other users, or interfere with platform '
        'security. Violations may result in rejection, account suspension, or referral to ACCESS advisers.',
  ),
  AccessLegalSection(
    heading: '6. Disclaimers',
    body:
        'AI scores and feedback are advisory tools for skill development. They do not guarantee '
        'assignment selection, competency tier placement, or publication of your media. Administrators '
        'may override automated results.',
  ),
  AccessLegalSection(
    heading: '7. Changes and contact',
    body:
        'ACCESS administrators may update these terms as the platform evolves. Continued use after '
        'updates means you accept the revised terms. For questions, contact your ACCESS adviser or '
        'campus administrator.',
  ),
];

const _privacySections = [
  AccessLegalSection(
    heading: '1. Overview',
    body:
        'This Privacy Policy explains how ACCESS VisionCheck collects and uses information when you '
        'use the mobile app, web admin tools, and related backend services.',
  ),
  AccessLegalSection(
    heading: '2. Information we collect',
    body:
        'We collect account details (name, email, student or organization ID, contact number, role), '
        'profile information, documentation assignments, uploaded photos and videos, evaluation scores, '
        'AI analysis metadata, admin review notes, notifications, and basic usage activity such as login '
        'and submission timestamps.',
  ),
  AccessLegalSection(
    heading: '3. How we use information',
    body:
        'Data is used to operate the platform: authenticate users, assign documentation tasks, run media '
        'quality and integrity checks, show rankings and feedback, notify members and admins, and support '
        'campus documentation workflows.',
  ),
  AccessLegalSection(
    heading: '4. Who can see your data',
    body:
        'Members see their own submissions, scores, and notifications. ACCESS administrators and authorized '
        'requestors see information needed for approvals, assignments, event documentation, and integrity '
        'review. Data is not sold to third parties.',
  ),
  AccessLegalSection(
    heading: '5. AI and automated processing',
    body:
        'Uploaded media may be processed by automated quality models and optional AI feedback services. '
        'Results may flag suspicious or policy-related content for human admin review before any disciplinary action.',
  ),
  AccessLegalSection(
    heading: '6. Retention and security',
    body:
        'Media and account records are retained while your account is active and as needed for documentation '
        'history, unless an administrator removes them. Reasonable technical safeguards protect stored data, '
        'but no system is perfectly secure.',
  ),
  AccessLegalSection(
    heading: '7. Your choices',
    body:
        'You may update profile details in the app and contact an administrator to request account deactivation '
        'or clarification about stored media. Some records may be kept as required for documentation audit '
        'or university policy.',
  ),
];

const _contentStandardsSections = [
  AccessLegalSection(
    heading: 'ACCESS content standards',
    body:
        'All practice evaluations and documentation uploads must be appropriate for a university '
        'documentation team and suitable for campus-related use.',
  ),
  AccessLegalSection(
    heading: 'Allowed content',
    body:
        'Real photos and videos you captured for skill building, assigned event coverage, or approved '
        'documentation requests. Submissions should reflect honest practice work and meet basic quality '
        'expectations for the ACCESS program.',
  ),
  AccessLegalSection(
    heading: 'Not allowed',
    body:
        'Do not upload nudity, sexual content, gore, graphic violence, hate material, illegal content, '
        'or media you did not have rights to submit. Do not upload deepfakes or AI-generated work '
        'presented as your own practice capture.',
  ),
  AccessLegalSection(
    heading: 'Review and enforcement',
    body:
        'Potentially AI-generated or suspicious media may be flagged for admin review. Serious policy '
        'violations may be rejected, removed from review queues, and referred to ACCESS advisers. '
        'Repeated violations can affect account status and XP eligibility.',
  ),
];
