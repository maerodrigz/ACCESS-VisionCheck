import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Member _member({
  required int userId,
  required String name,
  required int points,
  int monthly = 0,
}) {
  return Member(
    userId: userId,
    name: name,
    rank: 'Documenter',
    initials: name.isNotEmpty ? name[0] : '?',
    uploads: 2,
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
  });

  tearDown(() {
    appState.profileName = savedName ?? '';
    appState.profilePoints = savedPoints;
    appState.profileRankPosition = savedRank;
    appState.profileSkillLevel = savedSkill;
    appState.members
      ..clear()
      ..addAll(savedMembers);
    appState.notifyListeners();
  });

  Future<void> pumpRankings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RankingsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets('My Rank badge shows live #1 and Leaderboard Rank label',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 658;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Intermediate';
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Shan Lee', points: 658, monthly: 100),
        _member(userId: 2, name: 'Alex', points: 200, monthly: 40),
      ]);

    await pumpRankings(tester);

    expect(find.text('#1'), findsWidgets);
    expect(find.text('Leaderboard Rank'), findsWidgets);
    expect(find.text('Unranked'), findsNothing);
  });

  testWidgets('My Rank badge shows live #2 from leaderboard order',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 150;
    appState.profileRankPosition = 99;
    appState.profileSkillLevel = 'Beginner';
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Alex', points: 300, monthly: 50),
        _member(userId: 2, name: 'Shan Lee', points: 150, monthly: 20),
        _member(userId: 3, name: 'Jordan', points: 100, monthly: 10),
      ]);

    await pumpRankings(tester);

    expect(find.text('#2'), findsWidgets);
    expect(find.text('Leaderboard Rank'), findsWidgets);
  });

  testWidgets('My Rank badge shows Unranked when no board position',
      (tester) async {
    appState.profileName = 'New Member';
    appState.profilePoints = 0;
    appState.profileRankPosition = null;
    appState.profileSkillLevel = 'Beginner';
    appState.members.clear();

    await pumpRankings(tester);

    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('Leaderboard Rank'), findsNothing);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('#1'), findsNothing);
  });

  testWidgets('XP period label is fully visible without ellipsis', (tester) async {
    appState.profileName = 'Shan Lee With A Longer Display Name';
    appState.profilePoints = 658;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Intermediate';
    appState.members
      ..clear()
      ..add(_member(userId: 1, name: 'Shan Lee With A Longer Display Name', points: 658));

    await pumpRankings(tester);

    expect(find.text('658 XP (All Time)'), findsOneWidget);
    expect(find.textContaining('658 XP (All'), findsOneWidget);
    expect(find.text('Leaderboard Rank'), findsWidgets);

    await tester.tap(find.text('This Month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('XP (This Month)'), findsOneWidget);
  });

  testWidgets('narrow width keeps full All Time XP and Unranked badge',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.profileName = 'Casey';
    appState.profilePoints = 42;
    appState.profileRankPosition = null;
    appState.profileSkillLevel = 'Beginner';
    appState.members.clear();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RankingsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.takeException(), isNull);
    expect(find.text('42 XP (All Time)'), findsOneWidget);
    expect(find.text('Unranked'), findsOneWidget);
  });
}
