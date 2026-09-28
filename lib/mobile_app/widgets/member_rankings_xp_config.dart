import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';

/// Configurable XP rules mirrored from the ACCESS backend pipeline.
class MemberXpConfig {
  const MemberXpConfig._();

  /// From `access_backend/app/services/media_pipeline.py` — points added per evaluation.
  static const String evaluationFormula = 'overall_score × 100';

  /// From `access_backend/app/services/ai_review_workflow.py`.
  static const int aiConfirmedPenalty = 25;

  /// Mirrors `int(scores["overall_score"] * 100)` in the media pipeline.
  static int xpFromEvaluationScore(double score) {
    final normalized = score <= 1.0 ? score : score / 5.0;
    return (normalized.clamp(0.0, 1.0) * 100).round();
  }

  /// Skill tier thresholds (same as [MemberCompetencyTier.tiers] on the dashboard).
  static List<MemberCompetencyTier> get skillTiers => MemberCompetencyTier.tiers;

  /// Skill score weights from `access_backend/app/services/skill_scoring.py`.
  static const skillScoreWeights = <({String label, String weight})>[
    (label: 'Media quality', weight: '70%'),
    (label: 'Media integrity', weight: '30%'),
  ];

  static const howXpIntro =
      'XP comes from practice AI evaluations. Strong scores and a clean integrity record '
      'help you climb the leaderboard and improve your skill label.';

  static const skillLevelIntro =
      'Your skill label (Beginner, Intermediate, Advanced, Expert) comes from your average '
      'evaluation quality and media integrity record, not a single upload. You need at least '
      '3 evaluated submissions before leaving Beginner, 6 for Advanced, and 10 for Expert.';

  /// From `skill_level_from_score` in the backend.
  static const List<({String name, String range})> skillLevelTiers = [
    (name: 'Expert', range: '90+ score'),
    (name: 'Advanced', range: '75–89'),
    (name: 'Intermediate', range: '60–74'),
    (name: 'Beginner', range: 'Below 60'),
  ];

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
      'Tip: Skill level rewards strong evaluation scores and a clean integrity record, not how many files you upload per day.';

  static const contentStandardsTitle = 'ACCESS content standards';

  static const contentStandardsSummary =
      'Practice uploads must be appropriate for a university documentation team: real photos or videos you captured for skill building.';

  static const contentStandardsDetail =
      'Do not upload nudity, sexual content, gore, graphic violence, hate material, or illegal content. '
      'Violations may be rejected, removed from review, and referred to ACCESS advisers.';

  static const contentStandardsCheckbox =
      'I confirm this file meets ACCESS content standards and is my own work for documentation practice.';

  static const List<({String title, String body})> earningRules = [
    (
      title: 'Quality evaluations',
      body:
          'Each evaluated upload earns XP using $evaluationFormula (rounded to whole points). '
          'Higher scores mean more XP per submission.',
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
      title: 'Authentic media',
      body:
          'AI-confirmed generated media may reduce XP by $aiConfirmedPenalty points as part of the integrity review process.',
    ),
    (
      title: 'Appropriate content',
      body: contentStandardsDetail,
    ),
  ];
}
