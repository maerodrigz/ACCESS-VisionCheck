/// Configurable XP rules mirrored from the ACCESS backend pipeline.
class MemberXpConfig {
  MemberXpConfig._();

  /// From `access_backend/app/services/media_pipeline.py`. Points use stored overall
  /// (v2 Clarity formula for new evals; historical rows keep their original overall).
  static const String evaluationFormula = 'overall_score × 100';

  /// From `access_backend/app/services/ai_review_workflow.py`.
  static const int aiConfirmedPenalty = 25;

  /// Mirrors pipeline XP from legacy 0–1 overall (derived from backend overall_score).
  static int xpFromEvaluationScore(double score) {
    final normalized = score <= 1.0 ? score : score / 5.0;
    return (normalized.clamp(0.0, 1.0) * 100).round();
  }

  static const skillTierIntro =
      'My Skill Level uses Quality Skill Classification: Beginner, Developing, Proficient, '
      'Advanced, and Expert. Photo and Video are classified separately from the latest 10 '
      'qualifying comparable evaluations under the current scoring formula.';

  static const xpRankIntro =
      'XP Rank reflects participation rewards on the leaderboard (total XP). It is separate '
      'from My Skill Level (quality classification) and from Media Integrity review.';

  static const mediaIntegrityIntro =
      'Media Integrity covers AI detection and admin review. It can hold or exclude an upload '
      'from quality classification and XP until resolved. A low AI probability alone is not treated as proof '
      'of inauthentic media.';

  static const collapsedXpHint =
      'Earn XP from eligible practice evaluations. My Skill Level uses quality classifications only.';

  static const howXpIntro =
      'XP Rank is your participation score on the leaderboard. My Skill Level is your '
      'Photo/Video quality classification. Media Integrity is a separate review path for AI and authenticity flags.';

  /// Compact Rankings screen summary (collapsed card body).
  static const howRankingsSummary =
      'Your XP determines your leaderboard position. My Skill Level shows Photo and Video '
      'quality classifications and is separate from XP.';

  static const howRankingsXpTile =
      'Earn up to 100 XP per eligible practice evaluation.';

  static const howRankingsSkillTile =
      'Photo/Video titles from quality scores and minimum qualifying evaluations.';

  static const skillLevelIntroV1 =
      'My Skill Level (Quality Skill Classification): Beginner 0.00–1.99 with 3 evals, '
      'Developing 2.00–2.99 with 3, Proficient 3.00–3.99 with 5, Advanced 4.00–4.49 with 8, '
      'Expert 4.50–5.00 with 10. Photo and Video are separate. Daily upload caps are separate from classification.';

  static const skillLevelIntroV2 =
      'My Skill Level (Quality Skill Classification): Beginner 0.00–1.99 with 3 evals, '
      'Developing 2.00–2.99 with 3, Proficient 3.00–3.99 with 5, Advanced 4.00–4.49 with 8, '
      'Expert 4.50–5.00 with 10. Uses the latest 10 qualifying comparable evaluations. '
      'Daily upload caps are separate from classification.';

  static String skillLevelIntroForPolicy(String policyVersion) {
    if (policyVersion.trim().toLowerCase() == 'v2') {
      return skillLevelIntroV2;
    }
    return skillLevelIntroV1;
  }

  /// Concise Quality Skill Classification requirements for Rankings "How Rankings Work".
  /// [policyVersion] kept for call-site compatibility; thresholds are classification rules.
  static String skillTierRequirementsForPolicy(String policyVersion) {
    final _ = policyVersion;
    return 'Quality Skill Classification uses eligible released practice evaluations under the '
        'current scoring formula. Beginner: 0.00–1.99 / 5 (3 evals). Developing: 2.00–2.99 (3). '
        'Proficient: 3.00–3.99 (5). Advanced: 4.00–4.49 (8). Expert: 4.50–5.00 (10). '
        'Photo and Video are classified separately. XP rank remains independent.';
  }

  static List<({String title, String body})> howRankingsDetailedRules(
    String policyVersion,
  ) =>
      [
        (
          title: 'XP earning',
          body:
              'Eligible practice evaluations award XP from the released quality score '
              '(up to 100 XP). Each submission chain can receive XP only once. '
              'XP Rank is independent of My Skill Level.',
        ),
        (
          title: 'Media Integrity review',
          body:
              'Pending Media Integrity or admin review can delay XP and quality classification credit. '
              'Rejected media or confirmed AI-generated or manipulated uploads do not earn XP.',
        ),
        (
          title: 'My Skill Level requirements',
          body: skillTierRequirementsForPolicy(policyVersion),
        ),
        (
          title: 'Monthly vs All-Time XP',
          body:
              'All-Time XP is your total awarded practice XP. This Month uses award timestamps. '
              'Older XP without a reliable award timestamp may not appear in This Month.',
        ),
        (
          title: 'What does not earn XP',
          body:
              'Event documentation uploads and assignment coverage do not award XP. '
              'Use practice evaluations for scored XP.',
        ),
      ];

  /// Quality Skill Classification titles shown in member-facing copy.
  static const List<({String name, String range})> skillLevelTiers = [
    (name: 'Expert', range: '4.50–5.00 · 10 evals'),
    (name: 'Advanced', range: '4.00–4.49 · 8 evals'),
    (name: 'Proficient', range: '3.00–3.99 · 5 evals'),
    (name: 'Developing', range: '2.00–2.99 · 3 evals'),
    (name: 'Beginner', range: '0.00–1.99 · 3 evals'),
  ];

  static const leaderboardOrderNote =
      'This screen sorts members by XP (monthly or all-time). My Skill Level on your profile '
      'uses Photo/Video quality classification, not XP order.';

  static const uploadGuidanceIntro =
      'ACCESS uses two upload paths. Daily limits apply only to practice AI evaluations, not '
      'to event documentation for assigned coverage.';

  static String evaluationDailyLimitBody(int limit) =>
      'Up to $limit practice photo or video ${limit == 1 ? 'file' : 'files'} per calendar day '
      'for AI quality scoring. Focus on your best work. Extra uploads do not automatically raise your level.';

  static const eventUploadGuidanceBody =
      'No fixed daily file count. Upload what your assignment needs, usually during or right after '
      'the event. Submissions must fall within the admin-configured upload window (often 7 days after the event).';

  static const uploadQualityTip =
      'Tip: My Skill Level rewards strong released quality scores, not upload volume alone.';

  static const contentStandardsTitle = 'ACCESS content standards';

  static const contentStandardsSummary =
      'Practice uploads must be appropriate for a university documentation team: real photos or videos you captured for skill building.';

  static const contentStandardsDetail =
      'Do not upload nudity, sexual content, gore, graphic violence, hate material, or illegal content. '
      'Violations may be rejected, removed from review, and referred to ACCESS advisers.';

  static const contentStandardsCheckbox =
      'I confirm that this media is my own work and follows ACCESS Content Standards.';

  static const List<({String title, String body})> earningRules = [
    (
      title: 'XP Rank (participation)',
      body:
          'Each eligible evaluated upload earns XP using $evaluationFormula (rounded). '
          'XP drives leaderboard order on this screen.',
    ),
    (
      title: 'My Skill Level (quality)',
      body: skillTierIntro,
    ),
    (
      title: 'Media Integrity',
      body: mediaIntegrityIntro,
    ),
    (
      title: 'Event documentation',
      body:
          'Photos and videos for assigned events are stored for the team and admins. '
          'They do not add XP. Use the Evaluations tab for scored practice uploads.',
    ),
    (
      title: 'Assignments',
      body:
          'Accepting and covering assigned events builds your participation record with admins, '
          'but assignment completion alone does not award XP today.',
    ),
    (
      title: 'Appropriate content',
      body: contentStandardsDetail,
    ),
  ];
}
