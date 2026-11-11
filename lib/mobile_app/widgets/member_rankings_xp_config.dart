/// Configurable XP rules mirrored from the ACCESS backend pipeline.
class MemberXpConfig {
  MemberXpConfig._();

  /// From `access_backend/app/services/media_pipeline.py` — points added per evaluation.
  static const String evaluationFormula = 'overall_score × 100';

  /// From `access_backend/app/services/ai_review_workflow.py`.
  static const int aiConfirmedPenalty = 25;

  /// Mirrors `int(scores["overall_score"] * 100)` in the media pipeline.
  static int xpFromEvaluationScore(double score) {
    final normalized = score <= 1.0 ? score : score / 5.0;
    return (normalized.clamp(0.0, 1.0) * 100).round();
  }

  static const skillTierIntro =
      'Skill Tier (Beginner through Expert) is based on the average quality score of '
      'eligible, released practice evaluations only. Pending or withheld uploads do not count '
      'until an officer releases scores.';

  static const xpRankIntro =
      'XP Rank reflects participation rewards on the leaderboard (total XP). It is separate '
      'from Skill Tier and from Media Integrity review.';

  static const mediaIntegrityIntro =
      'Media Integrity covers AI detection and admin review. It can hold or exclude an upload '
      'from skill tier and XP until resolved. A low AI probability alone is not treated as proof '
      'of inauthentic media.';

  static const collapsedXpHint =
      'Earn XP from eligible practice evaluations. Skill Tier uses released quality scores only.';

  static const howXpIntro =
      'XP Rank is your participation score on the leaderboard. Skill Tier is your quality-based '
      'classification. Media Integrity is a separate review path for AI and authenticity flags.';

  /// Compact Rankings screen summary (collapsed card body).
  static const howRankingsSummary =
      'Your XP determines your leaderboard position. Your Skill Tier reflects your practice '
      'evaluation quality.';

  static const howRankingsXpTile =
      'Earn up to 100 XP per eligible practice evaluation.';

  static const howRankingsSkillTile =
      'Based on quality scores and eligible practice evaluations.';

  static const skillLevelIntroV1 =
      'Skill Tier uses eligible released practice quality and evaluation count. '
      'Intermediate: 60%+ average with 3 eligible evaluations. Advanced: 75%+ with 6. '
      'Expert: 90%+ with 10. Daily upload cap (3/day) is separate from tier progress.';

  static const skillLevelIntroV2 =
      'Skill Tier uses eligible released practice quality, evaluation count, and distinct '
      'upload days (Manila calendar). Intermediate: 60%+, 3 evals, 2 days. Advanced: 75%+, '
      '12 evals, 10 days. Expert: 90%+, 24 evals, 24 days. Daily upload cap (3/day) is separate.';

  static String skillLevelIntroForPolicy(String policyVersion) {
    if (policyVersion.trim().toLowerCase() == 'v2') {
      return skillLevelIntroV2;
    }
    return skillLevelIntroV1;
  }

  /// Concise Skill Tier requirements for the Rankings "How Rankings Work" details.
  /// Does not mention daily upload caps (those are separate from tier progress).
  static String skillTierRequirementsForPolicy(String policyVersion) {
    if (policyVersion.trim().toLowerCase() == 'v2') {
      return 'Eligible released practice evaluations only. Intermediate: 60% average, '
          '3 evaluations, and 2 distinct upload days. Advanced: 75%, 12 evaluations, '
          '10 distinct upload days. Expert: 90%, 24 evaluations, 24 distinct upload days. '
          'Displayed tier may also reflect grandfathering or an admin override.';
    }
    return 'Eligible released practice evaluations only. Intermediate: 60% average and '
        '3 evaluations. Advanced: 75% and 6 evaluations. Expert: 90% and 10 evaluations. '
        'Displayed tier may also reflect grandfathering or an admin override.';
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
              'XP Rank is independent of Skill Tier.',
        ),
        (
          title: 'Media Integrity review',
          body:
              'Pending Media Integrity or admin review can delay XP and Skill Tier credit. '
              'Rejected media or confirmed AI-generated or manipulated uploads do not earn XP.',
        ),
        (
          title: 'Skill Tier requirements',
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

  /// From `skill_level_from_score` in the backend.
  static const List<({String name, String range})> skillLevelTiers = [
    (name: 'Expert', range: '90+ quality'),
    (name: 'Advanced', range: '75–89'),
    (name: 'Intermediate', range: '60–74'),
    (name: 'Beginner', range: 'Below 60'),
  ];

  static const leaderboardOrderNote =
      'This screen sorts members by XP (monthly or all-time). Skill Tier rank on your profile '
      'uses quality score and eligible evaluation count, not XP order.';

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
      'Tip: Skill Tier rewards strong released quality scores, not upload volume alone.';

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
      title: 'Skill Tier (quality)',
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
