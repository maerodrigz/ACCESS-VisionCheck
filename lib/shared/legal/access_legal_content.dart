/// ACCESS VisionCheck legal copy (Terms, Privacy, Content Standards).

/// Registration opens legal documents written for one audience only.
enum RegistrationLegalAudience {
  member,
  requestor,
}

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

  String registrationTitle(RegistrationLegalAudience audience) => switch (this) {
        AccessLegalDocument.terms => switch (audience) {
            RegistrationLegalAudience.member => 'Terms and Conditions (Members)',
            RegistrationLegalAudience.requestor => 'Terms and Conditions (Requestors)',
          },
        AccessLegalDocument.privacy => switch (audience) {
            RegistrationLegalAudience.member => 'Privacy Policy (Members)',
            RegistrationLegalAudience.requestor => 'Privacy Policy (Requestors)',
          },
        AccessLegalDocument.contentStandards => 'Content Standards (Members)',
      };

  String get lastUpdated => 'August 30, 2026';
}

class AccessLegalSection {
  const AccessLegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

List<AccessLegalSection> accessLegalSections(
  AccessLegalDocument document, {
  RegistrationLegalAudience? registrationAudience,
}) {
  if (registrationAudience != null) {
    return switch (document) {
      AccessLegalDocument.terms => switch (registrationAudience) {
          RegistrationLegalAudience.member => _memberTermsSections,
          RegistrationLegalAudience.requestor => _requestorTermsSections,
        },
      AccessLegalDocument.privacy => switch (registrationAudience) {
          RegistrationLegalAudience.member => _memberPrivacySections,
          RegistrationLegalAudience.requestor => _requestorPrivacySections,
        },
      AccessLegalDocument.contentStandards => _memberContentStandardsSections,
    };
  }
  return switch (document) {
    AccessLegalDocument.terms => _termsSectionsGeneral,
    AccessLegalDocument.privacy => _privacySectionsGeneral,
    AccessLegalDocument.contentStandards => _contentStandardsSectionsGeneral,
  };
}

String registrationAudienceLabel(RegistrationLegalAudience audience) => switch (audience) {
      RegistrationLegalAudience.member => 'Documentation member',
      RegistrationLegalAudience.requestor => 'Requestor (faculty, instructor, or organization)',
    };

/// Profile, login footer, and admin: combined overview.
const _termsSectionsGeneral = [
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
        'security. Violations may result in rejection, account suspension, or referral to ACCESS administrators.',
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
        'updates means you accept the revised terms. For questions, contact your ACCESS administrator.',
  ),
];

const _memberTermsSections = [
  AccessLegalSection(
    heading: '1. About ACCESS VisionCheck (Members)',
    body:
        'These Terms and Conditions apply to you as a documentation member of ACCESS VisionCheck at '
        'USTP Oroquieta Campus. By registering a member account, you agree to the rules below.',
  ),
  AccessLegalSection(
    heading: '2. Your member account',
    body:
        'Member accounts are issued after administrator approval. You must provide accurate name, student ID, '
        'email, and contact details. Keep your password private and do not share your account. Use the app only '
        'for ACCESS documentation team activities.',
  ),
  AccessLegalSection(
    heading: '3. Assignments and event coverage',
    body:
        'You may receive documentation assignments for campus events. You must accept or decline assignments '
        'in the app and upload coverage media when you accept. Missed deadlines or repeated declines may '
        'affect future assignments at administrator discretion.',
  ),
  AccessLegalSection(
    heading: '4. Practice evaluations and integrity',
    body:
        'Practice media evaluations use automated scoring, optional AI feedback, and administrator integrity '
        'review. You must stay within daily evaluation limits and comply with outcomes, including re-upload '
        'requests. Do not attempt to bypass AI integrity checks.',
  ),
  AccessLegalSection(
    heading: '5. Your uploads and XP',
    body:
        'You retain ownership of your photos and videos. You grant ACCESS administrators permission to store, '
        'review, and display your work for training, galleries, and integrity review. XP, rankings, and '
        'competency tiers are informational and may be adjusted by administrators.',
  ),
  AccessLegalSection(
    heading: '6. Prohibited conduct',
    body:
        'Do not upload inappropriate, illegal, or misleading content. Do not harass other users or interfere '
        'with platform security. Violations may result in rejected media, account suspension, or administrator action.',
  ),
  AccessLegalSection(
    heading: '7. Changes and contact',
    body:
        'ACCESS administrators may update these member terms as the platform evolves. Continued use after '
        'updates means you accept the revised terms. For questions, contact your ACCESS administrator.',
  ),
];

const _requestorTermsSections = [
  AccessLegalSection(
    heading: '1. About ACCESS VisionCheck (Requestors)',
    body:
        'These Terms and Conditions apply to you as a requestor (faculty, instructor, or student organization) '
        'using ACCESS VisionCheck at USTP Oroquieta Campus. By registering, you agree to the rules below.',
  ),
  AccessLegalSection(
    heading: '2. Your requestor account',
    body:
        'Requestor accounts are issued after administrator approval. You must provide accurate registration '
        'information, including organization or representative details when required. Keep your login '
        'credentials private.',
  ),
  AccessLegalSection(
    heading: '3. Documentation requests',
    body:
        'You may submit requests for event documentation coverage. Event titles, dates, locations, and descriptions '
        'must be accurate. Administrators approve or reject requests. You may not use the platform for '
        'non-university or unauthorized activities.',
  ),
  AccessLegalSection(
    heading: '4. After documentation is completed',
    body:
        'When coverage is complete, you may review gallery media and provide feedback through the app. Use '
        'feedback responsibly and in line with campus conduct expectations.',
  ),
  AccessLegalSection(
    heading: '5. Communication and notifications',
    body:
        'You agree to receive in-app and email notifications about your request status when those channels '
        'are enabled. Respond promptly if an administrator needs clarification about your request.',
  ),
  AccessLegalSection(
    heading: '6. Prohibited conduct',
    body:
        'Do not submit false requests, misuse member work, harass users, or attempt to interfere with platform '
        'security. Violations may result in rejected requests or account suspension.',
  ),
  AccessLegalSection(
    heading: '7. Changes and contact',
    body:
        'ACCESS administrators may update these requestor terms as the platform evolves. Continued use after '
        'updates means you accept the revised terms. For questions, contact your ACCESS administrator.',
  ),
];

const _privacySectionsGeneral = [
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

const _memberPrivacySections = [
  AccessLegalSection(
    heading: '1. Privacy Policy for documentation members',
    body:
        'This policy describes how ACCESS VisionCheck handles your information when you register and use '
        'a member account.',
  ),
  AccessLegalSection(
    heading: '2. Information we collect from members',
    body:
        'We collect your name, student ID, email, contact number, profile details, assignment history, '
        'uploaded photos and videos, practice evaluation scores, AI integrity metadata, admin review notes, '
        'notifications, XP and ranking data, and login activity.',
  ),
  AccessLegalSection(
    heading: '3. How we use member information',
    body:
        'We use your data to approve your account, assign events, run quality and integrity checks on uploads, '
        'calculate XP and rankings, send assignment and review notifications, and support ACCESS documentation workflows.',
  ),
  AccessLegalSection(
    heading: '4. Who can see member information',
    body:
        'You see your own submissions and scores. ACCESS administrators see your full member profile and work '
        'for review and competency management. Requestors may see your name and coverage related to events they '
        'requested. We do not sell your data.',
  ),
  AccessLegalSection(
    heading: '5. AI and automated processing',
    body:
        'Your practice and event uploads may be analyzed by automated models. Suspicious results are reviewed '
        'by administrators before disciplinary action.',
  ),
  AccessLegalSection(
    heading: '6. Retention and security',
    body:
        'Media and records are kept while your account is active and for documentation history unless removed '
        'by an administrator. We use reasonable safeguards; no system is perfectly secure.',
  ),
  AccessLegalSection(
    heading: '7. Your choices',
    body:
        'Update profile details in the app. Contact an ACCESS administrator to ask about stored media or account '
        'deactivation. Some audit records may be retained per university policy.',
  ),
];

const _requestorPrivacySections = [
  AccessLegalSection(
    heading: '1. Privacy Policy for requestors',
    body:
        'This policy describes how ACCESS VisionCheck handles your information when you register and use '
        'a requestor account (faculty, instructor, or organization).',
  ),
  AccessLegalSection(
    heading: '2. Information we collect from requestors',
    body:
        'We collect your name or organization name, email, contact number, representative name when provided, '
        'documentation request details, feedback and ratings you submit, notifications, and login activity.',
  ),
  AccessLegalSection(
    heading: '3. How we use requestor information',
    body:
        'We use your data to approve your account, process documentation requests, assign members, notify you '
        'of request status, share completed gallery access, and support campus documentation workflows.',
  ),
  AccessLegalSection(
    heading: '4. Who can see requestor information',
    body:
        'You see your own requests and related gallery content. ACCESS administrators see your registration '
        'and requests for approval and operations. Assigned documentation members see event details needed '
        'to perform coverage. We do not sell your data.',
  ),
  AccessLegalSection(
    heading: '5. Email and notifications',
    body:
        'We may email you at your registered address about registration approval and request updates when '
        'email is configured on the server. You also receive in-app notifications.',
  ),
  AccessLegalSection(
    heading: '6. Retention and security',
    body:
        'Request and account records are kept while your account is active and for documentation history unless '
        'removed by an administrator. We use reasonable safeguards; no system is perfectly secure.',
  ),
  AccessLegalSection(
    heading: '7. Your choices',
    body:
        'Contact an ACCESS administrator to ask about your stored requests or account deactivation. Some records '
        'may be retained for documentation audit or university policy.',
  ),
];

const _contentStandardsSectionsGeneral = [
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
        'violations may be rejected, removed from review queues, and referred to ACCESS administrators. '
        'Repeated violations can affect account status and XP eligibility.',
  ),
];

const _memberContentStandardsSections = [
  AccessLegalSection(
    heading: '1. Content standards for members',
    body:
        'As a documentation member, all practice evaluations and event coverage uploads must be appropriate '
        'for the ACCESS team and suitable for campus-related use.',
  ),
  AccessLegalSection(
    heading: '2. Practice evaluation uploads',
    body:
        'Practice media is for skill development. Submit honest work you captured yourself. Stay within daily '
        'evaluation limits and content rules below.',
  ),
  AccessLegalSection(
    heading: '3. Event coverage uploads',
    body:
        'Coverage for assigned events must reflect the actual event. Meet administrator quality and timing '
        'expectations for the assignment.',
  ),
  AccessLegalSection(
    heading: '4. Not allowed',
    body:
        'Do not upload nudity, sexual content, gore, graphic violence, hate material, illegal content, '
        'or media you did not have rights to submit. Do not present AI-generated work as your own capture.',
  ),
  AccessLegalSection(
    heading: '5. Integrity review',
    body:
        'Suspicious or AI-flagged media may be held for administrator review. You must comply with outcomes, '
        'including re-upload requests. Serious violations can affect XP and account status.',