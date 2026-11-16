import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';
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

  late String? savedName;
  late int savedPoints;
  late int? savedRank;
  late String? savedSkill;
  late String savedPolicy;
  late List<Member> savedMembers;

  setUp(() {
    savedName = appState.profileName;
    savedPoints = appState.profilePoints;
    savedRank = appState.profileRankPosition;
    savedSkill = appState.profileSkillLevel;
    savedPolicy = appState.profileSkillProgressionPolicyVersion;
    savedMembers = List<Member>.from(appState.members);
    memberDataController.rankingsLoading = false;
    memberDataController.rankingsError = null;
  });

  tearDown(() {
    appState.profileName = savedName ?? '';
    appState.profilePoints = savedPoints;
    appState.profileRankPosition = savedRank;
    appState.profileSkillLevel = savedSkill;
    appState.profileSkillProgressionPolicyVersion = savedPolicy;
    appState.members
      ..clear()
      ..addAll(savedMembers);
    memberDataController.rankingsLoading = false;
    memberDataController.rankingsError = null;
    appState.notifyListeners();
  });

  Future<void> pumpRankings(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RankingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('How Rankings Work stays collapsed with summary tiles',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 658;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Intermediate';
    appState.profileSkillProgressionPolicyVersion = 'v1';
    appState.members.clear();

    await pumpRankings(tester);

    expect(find.text('My Skill Level'), findsWidgets);
    expect(find.text('Skill Tier Progress'), findsNothing);
    expect(find.text('Current tier: Intermediate'), findsNothing);
    expect(find.text('How Rankings Work'), findsOneWidget);
    expect(find.text('How XP & Skill Tiers Work'), findsNothing);
    expect(find.text(MemberXpConfig.howRankingsSummary), findsOneWidget);
    expect(find.text('XP Rank'), findsOneWidget);
    expect(find.text('Skill Level'), findsOneWidget);
    expect(find.text(MemberXpConfig.howRankingsXpTile), findsOneWidget);
    expect(find.text(MemberXpConfig.howRankingsSkillTile), findsOneWidget);
    expect(find.text('View detailed rules'), findsOneWidget);

    final skillCopy =
        MemberXpConfig.skillTierRequirementsForPolicy('v1');
    expect(find.text(skillCopy).hitTestable(), findsNothing);
    expect(find.textContaining('AI penalty'), findsNothing);
    expect(find.textContaining('3/day'), findsNothing);
  });

  testWidgets('expand and collapse detailed rules uses quality classification',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 658;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Intermediate';
    appState.profileSkillProgressionPolicyVersion = 'v1';
    appState.members.clear();

    await pumpRankings(tester);

    await tester.ensureVisible(find.text('View detailed rules'));
    await tester.tap(find.text('View detailed rules'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hide detailed rules'), findsOneWidget);
    expect(find.text('XP earning'), findsOneWidget);
    expect(find.text('Media Integrity review'), findsOneWidget);
    expect(find.text('My Skill Level requirements'), findsOneWidget);
    expect(find.text('Monthly vs All-Time XP'), findsOneWidget);
    await tester.ensureVisible(find.text('What does not earn XP'));
    expect(find.text('What does not earn XP'), findsOneWidget);
    expect(
      find.text(MemberXpConfig.skillTierRequirementsForPolicy('v1')),
      findsOneWidget,
    );
    expect(find.textContaining('Intermediate'), findsNothing);
    expect(find.textContaining('3/day'), findsNothing);

    await tester.tap(find.text('Hide detailed rules'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('View detailed rules'), findsOneWidget);
    expect(
      find.text(MemberXpConfig.skillTierRequirementsForPolicy('v1')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('v2 policy keeps the same quality classification requirements',
      (tester) async {
    appState.profileName = 'Carlos';
    appState.profilePoints = 100;
    appState.profileRankPosition = 2;
    appState.profileSkillLevel = 'Beginner';
    appState.profileSkillProgressionPolicyVersion = 'v2';
    appState.members.clear();

    await pumpRankings(tester);

    await tester.ensureVisible(find.text('View detailed rules'));
    await tester.tap(find.text('View detailed rules'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find
          .text(MemberXpConfig.skillTierRequirementsForPolicy('v2'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.textContaining('Developing'), findsWidgets);
    expect(find.textContaining('24 distinct upload days'), findsNothing);
    expect(find.textContaining('3/day'), findsNothing);
  });

  testWidgets('narrow width keeps How Rankings Work and expand target',
      (tester) async {
    appState.profileName = 'Narrow Member';
    appState.profilePoints = 10;
    appState.profileRankPosition = null;
    appState.profileSkillLevel = 'Beginner';
    appState.profileSkillProgressionPolicyVersion = 'v1';
    appState.members.clear();

    await pumpRankings(tester, width: 320);

    expect(find.text('My Skill Level'), findsWidgets);
    expect(find.text('Skill Tier Progress'), findsNothing);
    expect(find.text('How Rankings Work'), findsOneWidget);
    expect(find.text('XP Rank'), findsOneWidget);
    expect(find.text('Skill Level'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('View detailed rules'));
    await tester.tap(find.text('View detailed rules'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('XP earning').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
