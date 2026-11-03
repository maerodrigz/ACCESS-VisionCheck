import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/participation_quota_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter v2 UI contract using staging-shaped participation payload (no live HTTP).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    appState.clearMemberProfile();
  });

  test('v2 participation fields drive profile snapshot and v2 intro copy', () {
    const participation = {
      'skill_progression_policy_version': 'v2',
      'skill_progression_policy_configured': 'v2',
      'skill_progression_v2_blocked_reason': null,
      'skill_effective_tier': 'Intermediate',
      'skill_computed_tier': 'Intermediate',
      'skill_eligible_evaluations_count': 3,
      'skill_eligible_distinct_upload_days': 1,
      'skill_quality_average': 81.0,
      'skill_next_tier_required_evaluations': 12,
      'skill_next_tier_required_days': 10,
      'skill_remaining_eligible_evaluations': 9,
      'skill_remaining_distinct_upload_days': 9,
      'skill_remaining_quality_points': 0,
      'daily_evaluation_limit': 3,
    };

    final fields = participationFieldsFromApi(participation);
    appState.applyParticipation(
      skillProgressionPolicyVersion: fields['skill_progression_policy_version'] as String,
      skillEffectiveTier: fields['skill_effective_tier'] as String?,
      skillQualityAverage: fields['skill_quality_average'] as double?,
      skillEligibleEvaluationsCount: fields['skill_eligible_evaluations_count'] as int,
      skillDistinctUploadDays: fields['skill_eligible_distinct_upload_days'] as int,
      skillNextTierRequiredEvaluations: fields['skill_next_tier_required_evaluations'] as int?,
      skillNextTierRequiredDays: fields['skill_next_tier_required_days'] as int?,
      skillRemainingEligibleEvaluations: fields['skill_remaining_eligible_evaluations'] as int,
      skillRemainingDistinctUploadDays: fields['skill_remaining_distinct_upload_days'] as int,
      skillRemainingQualityPoints: fields['skill_remaining_quality_points'] as int,
      dailyEvaluationLimit: fields['daily_evaluation_limit'] as int,
    );
    appState.profileSkillScore = 81;

    expect(appState.profileSkillProgressionPolicyVersion, 'v2');
    final snap = MemberCompetencySnapshot.fromAppState();
    expect(snap.progressionPolicyVersion, 'v2');
    expect(snap.levelName, 'Intermediate');
    expect(snap.remainingDistinctUploadDays, 9);
    expect(snap.remainingEligibleEvaluations, 9);
    expect(snap.evalGateHint, contains('9 more skill-eligible'));
    expect(
      MemberXpConfig.skillLevelIntroForPolicy('v2'),
      contains('12 evals, 10 days'),
    );
    expect(appState.dailyEvaluationLimit, 3);
  });
}
