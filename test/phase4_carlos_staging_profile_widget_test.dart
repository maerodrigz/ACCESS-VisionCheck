import 'dart:convert';
import 'dart:io';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/participation_quota_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile skill UI fed from live staging participation export (Phase 4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final exportFile = File(
    '${Directory.current.path}/access_mobile_staging_backups/phase4_staging_participation_live.json',
  );
  final hasExport = exportFile.existsSync();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    appState.clearMemberProfile();
  });

  test('live staging participation maps to competency snapshot (Carlos)', () {
    if (!hasExport) {
      fail(
        'NOT TESTED: run phase4_export_staging_participation.py with staging API on 3011',
      );
    }
    final participation =
        (jsonDecode(exportFile.readAsStringSync()) as Map<String, dynamic>)['participation']
            as Map<String, dynamic>;
    final fields = participationFieldsFromApi(participation);

    expect(participation['skill_computed_tier_v2_strict'], 'Beginner');
    expect(participation['skill_effective_tier'], 'Intermediate');
    expect(participation['daily_evaluation_limit'], 3);

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
    appState.profileSkillScore =
        ((fields['skill_quality_average'] as num?)?.round() ?? 0).toDouble();

    final snap = MemberCompetencySnapshot.fromAppState();
    expect(snap.levelName, 'Intermediate');
    expect(snap.progressionPolicyVersion, 'v2');
    expect(snap.remainingEligibleEvaluations, 9);
    expect(snap.remainingDistinctUploadDays, 9);
  }, skip: !hasExport ? 'staging export missing' : false);

  Future<void> seedFromExport() async {
    final participation =
        (jsonDecode(exportFile.readAsStringSync()) as Map<String, dynamic>)['participation']
            as Map<String, dynamic>;
    final fields = participationFieldsFromApi(participation);
    appState.applyParticipation(
      skillProgressionPolicyVersion: 'v2',
      skillEffectiveTier: fields['skill_effective_tier'] as String?,
      skillQualityAverage: fields['skill_quality_average'] as double?,
      skillEligibleEvaluationsCount: fields['skill_eligible_evaluations_count'] as int,
      skillDistinctUploadDays: fields['skill_eligible_distinct_upload_days'] as int,
      skillNextTierRequiredEvaluations: fields['skill_next_tier_required_evaluations'] as int?,
      skillNextTierRequiredDays: fields['skill_next_tier_required_days'] as int?,
      skillRemainingEligibleEvaluations: fields['skill_remaining_eligible_evaluations'] as int,
      skillRemainingDistinctUploadDays: fields['skill_remaining_distinct_upload_days'] as int,
      skillRemainingQualityPoints: fields['skill_remaining_quality_points'] as int,
      dailyEvaluationLimit: 3,
    );
    appState.profileSkillScore = 81;
    appState.profileSkillProgressionSynced = true;
  }

  testWidgets('Carlos staging Profile section at 320px', (tester) async {
    if (!hasExport) return;
    appState.clearMemberProfile();
    await seedFromExport();
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: MemberProfileSkillProgressSection(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Intermediate'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Carlos staging Profile section at 360px', (tester) async {
    if (!hasExport) return;
    appState.clearMemberProfile();
    await seedFromExport();
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: MemberProfileSkillProgressSection(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Carlos staging Profile section at 393px', (tester) async {
    if (!hasExport) return;
    appState.clearMemberProfile();
    await seedFromExport();
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: MemberProfileSkillProgressSection(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
