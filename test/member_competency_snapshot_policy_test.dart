import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    appState.clearMemberProfile();
    appState.profileSkillProgressionSynced = false;
    appState.profileSkillProgressionPolicyVersion = 'v1';
  });

  group('MemberCompetencySnapshot policy awareness', () {
    test('v1 policy does not show distinct-day gate when participation synced', () {
      appState.profileSkillProgressionPolicyVersion = 'v1';
      appState.profileSkillProgressionSynced = true;
      appState.profileSkillLevel = 'Beginner';
      appState.profileSkillScore = 65;
      appState.profileSkillEligibleEvaluationsCount = 3;
      appState.profileSkillDistinctUploadDays = 0;
      appState.profileSkillRemainingEligibleEvaluations = 0;
      appState.profileSkillRemainingDistinctUploadDays = 2;
      appState.profileSkillRemainingQualityPoints = 0;

      final snap = MemberCompetencySnapshot.fromAppState();
      expect(snap.evalGateHint, isNull);
    });

    test('v2 policy shows day gate from backend when synced', () {
      appState.profileSkillProgressionPolicyVersion = 'v2';
      appState.profileSkillProgressionSynced = true;
      appState.profileSkillLevel = 'Beginner';
      appState.profileSkillScore = 65;
      appState.profileSkillEligibleEvaluationsCount = 3;
      appState.profileSkillDistinctUploadDays = 1;
      appState.profileSkillRemainingEligibleEvaluations = 0;
      appState.profileSkillRemainingDistinctUploadDays = 1;
      appState.profileSkillRemainingQualityPoints = 0;

      final snap = MemberCompetencySnapshot.fromAppState();
      expect(snap.evalGateHint, contains('distinct days'));
    });

    test('v1 fallback uses 6 eval gate for Advanced not 12', () {
      appState.profileSkillProgressionPolicyVersion = 'v1';
      appState.profileSkillProgressionSynced = false;
      appState.profileSkillLevel = 'Intermediate';
      appState.profileSkillScore = 80;
      appState.profileSkillEligibleEvaluationsCount = 5;

      final snap = MemberCompetencySnapshot.fromAppState();
      expect(snap.evalGateHint, contains('1 more'));
      expect(snap.evalGateHint, isNot(contains('distinct')));
    });

    test('unsynced v2 avoids inventing day counts when days unknown', () {
      appState.profileSkillProgressionPolicyVersion = 'v2';
      appState.profileSkillProgressionSynced = false;
      appState.profileSkillLevel = 'Beginner';
      appState.profileSkillScore = 65;
      appState.profileSkillEligibleEvaluationsCount = 3;
      appState.profileSkillDistinctUploadDays = 0;

      final snap = MemberCompetencySnapshot.fromAppState();
      expect(snap.evalGateHint, isNull);
    });
  });

  group('MemberSkillEvalGates', () {
    test('v1 and v2 evaluation minimums differ for Advanced', () {
      expect(
        MemberSkillEvalGates.minEvaluationsForTierIndex(2, policyVersion: 'v1'),
        6,
      );
      expect(
        MemberSkillEvalGates.minEvaluationsForTierIndex(2, policyVersion: 'v2'),
        12,
      );
      expect(
        MemberSkillEvalGates.minDistinctDaysForTierIndex(2, policyVersion: 'v1'),
        isNull,
      );
      expect(
        MemberSkillEvalGates.minDistinctDaysForTierIndex(2, policyVersion: 'v2'),
        10,
      );
    });
  });
}
