import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('profile skill section shows level hero without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    appState.profileSkillLevel = 'Intermediate';
    appState.profileSkillScore = 68;
    appState.profilePoints = 420;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: MemberProfileSkillProgressSection(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Skill progress'), findsOneWidget);
    expect(find.text('Intermediate'), findsWidgets);
    expect(find.text('How levels work'), findsOneWidget);
    expect(find.text('View Rankings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skill track uses compact labels at 320px and 1.3 text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);

    appState.profileSkillLevel = 'Intermediate';
    appState.profileSkillScore = 68;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: MemberProfileSkillProgressSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Intermediate'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile skill section fits at 393px width', (tester) async {
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    appState.profileSkillLevel = 'Advanced';
    appState.profileSkillScore = 78;
    appState.profileSkillProgressionPolicyVersion = 'v1';
    appState.profileSkillProgressionSynced = true;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: MemberProfileSkillProgressSection(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Advanced'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  tearDown(() {
    appState.profileSkillLevel = null;
    appState.profileSkillScore = null;
    appState.profilePoints = 0;
    appState.profileSkillProgressionSynced = false;
    memberDataController.evaluationsTabSynced = false;
  });
}
