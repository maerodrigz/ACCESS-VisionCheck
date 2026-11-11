import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<Member> savedMembers;
  late int? savedRank;
  late int savedPoints;
  late String? savedSkill;
  late String? savedName;

  setUp(() {
    savedMembers = List<Member>.from(appState.members);
    savedRank = appState.profileRankPosition;
    savedPoints = appState.profilePoints;
    savedSkill = appState.profileSkillLevel;
    savedName = appState.profileName;
  });

  tearDown(() {
    appState.members
      ..clear()
      ..addAll(savedMembers);
    appState.profileRankPosition = savedRank;
    appState.profilePoints = savedPoints;
    appState.profileSkillLevel = savedSkill;
    appState.profileName = savedName ?? '';
    appState.notifyListeners();
  });

  testWidgets('Phase 1 rankings hero, rank card, and period toggle', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.profileName = 'Shan Lee';
    appState.profilePoints = 658;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Intermediate';
    appState.members
      ..clear()
      ..add(
        Member(
          userId: 77,
          name: 'Shan Lee',
          rank: 'Intermediate',
          initials: 'SL',
          uploads: 17,
          goodEvaluations: 658,
          monthlyPoints: 120,
          avatarColor: const Color(0xFF0052D4),
        ),
      );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RankingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rankings'), findsWidgets);
    expect(
      find.text('See top documenters, your rank, and skill progress.'),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/images/rankings/rankings_trophy.png')),
      findsOneWidget,
    );
    expect(find.text('Shan Lee'), findsWidgets);
    expect(find.text('658 XP (All Time)'), findsOneWidget);
    expect(find.text('Leaderboard Rank'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('All Time'), findsOneWidget);

    // Earned-title "Unranked" must not sit beside leaderboard #1.
    expect(find.text('Unranked'), findsNothing);

    await tester.tap(find.text('This Month'));
    await tester.pump();
    expect(find.textContaining('XP (This Month)'), findsOneWidget);
  });

  testWidgets('Phase 1 shows Unranked when no leaderboard position', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.profileName = 'New Member';
    appState.profilePoints = 0;
    appState.profileRankPosition = null;
    appState.profileSkillLevel = 'Beginner';
    appState.members.clear();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RankingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('Leaderboard Rank'), findsNothing);
    expect(find.text('-'), findsOneWidget);
  });
}
