import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Member _member({
  required int userId,
  required String name,
  required String initials,
  required int points,
  int monthly = 0,
}) {
  return Member(
    userId: userId,
    name: name,
    rank: 'Documenter',
    initials: initials,
    uploads: 3,
    goodEvaluations: points,
    monthlyPoints: monthly,
    avatarColor: const Color(0xFF0052D4),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late String? savedName;
  late int savedPoints;
  late int? savedRank;
  late String? savedSkill;
  late List<Member> savedMembers;

  setUp(() {
    savedName = appState.profileName;
    savedPoints = appState.profilePoints;
    savedRank = appState.profileRankPosition;
    savedSkill = appState.profileSkillLevel;
    savedMembers = List<Member>.from(appState.members);
    memberDataController.rankingsLoading = false;
    memberDataController.rankingsError = null;
    memberDataController.evaluationsTabError = null;
  });

  tearDown(() {
    appState.profileName = savedName ?? '';
    appState.profilePoints = savedPoints;
    appState.profileRankPosition = savedRank;
    appState.profileSkillLevel = savedSkill;
    appState.members
      ..clear()
      ..addAll(savedMembers);
    memberDataController.rankingsLoading = false;
    memberDataController.rankingsError = null;
    memberDataController.evaluationsTabError = null;
    appState.notifyListeners();
  });

  Future<void> pumpRankings(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2200);
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

  testWidgets('Rankings omits Quality Trend and history chart error UI',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 120;
    appState.profileRankPosition = 2;
    appState.profileSkillLevel = 'Beginner';
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Alex Kim', initials: 'AK', points: 200, monthly: 40),
        _member(userId: 2, name: 'Shan Lee', initials: 'SL', points: 120, monthly: 10),
        _member(userId: 3, name: 'Jordan Lee', initials: 'JL', points: 90, monthly: 5),
        _member(userId: 4, name: 'Casey Ng', initials: 'CN', points: 40, monthly: 0),
      ]);
    // Stale evaluations-tab failure previously surfaced as "Could not load history"
    // when Rankings still mounted the Quality Trend chart without ensureEvaluationsTab.
    memberDataController.evaluationsTabError = 'Request failed (500)';
    appState.evaluations.clear();

    await pumpRankings(tester);

    expect(find.text('Quality trend'), findsNothing);
    expect(find.text('Practice quality over time'), findsNothing);
    expect(find.text('Could not load history'), findsNothing);
    expect(find.text('Performance Overview'), findsNothing);
    expect(find.text('Skill Tier Progress'), findsOneWidget);
    expect(find.text('How Rankings Work'), findsOneWidget);
    expect(find.text('How XP & Skill Tiers Work'), findsNothing);
  });

  testWidgets('monthly empty board shows period empty copy, not fake members',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 50;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Beginner';
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Shan Lee', initials: 'SL', points: 50, monthly: 0),
        _member(userId: 2, name: 'Alex Kim', initials: 'AK', points: 80, monthly: 0),
      ]);

    await pumpRankings(tester);

    await tester.tap(find.text('This Month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('No XP earned this month yet'), findsOneWidget);
    expect(find.text('Alex Kim'), findsNothing);
  });

  testWidgets('My Rank XP matches selected period leaderboard XP', (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 999; // intentionally diverge from board row
    appState.profileRankPosition = 99;
    appState.profileSkillLevel = 'Intermediate';
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Alex Kim', initials: 'AK', points: 300, monthly: 55),
        _member(userId: 2, name: 'Shan Lee', initials: 'SL', points: 150, monthly: 22),
        _member(userId: 3, name: 'Jordan Lee', initials: 'JL', points: 100, monthly: 11),
      ]);

    await pumpRankings(tester);

    // All Time: rank 2 with board XP 150 (not profilePoints 999).
    expect(find.text('#2'), findsWidgets);
    expect(find.textContaining('150'), findsWidgets);

    await tester.tap(find.text('This Month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // Monthly: still #2 with 22 XP from the same member row.
    expect(find.text('#2'), findsWidgets);
    expect(find.textContaining('22'), findsWidgets);
  });

  testWidgets('Infinix-width layout has no Quality Trend and keeps core sections',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 80;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Beginner';
    appState.members
      ..clear()
      ..add(
        _member(
          userId: 1,
          name: 'Shan Lee With A Very Long Display Name',
          initials: 'SL',
          points: 80,
          monthly: 12,
        ),
      );

    await pumpRankings(tester, width: 360);

    expect(tester.takeException(), isNull);
    expect(find.text('Rankings'), findsOneWidget);
    expect(find.text('Skill Tier Progress'), findsOneWidget);
    expect(find.text('Quality trend'), findsNothing);
  });
}
