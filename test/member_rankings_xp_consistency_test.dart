import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Member _member({
  required int userId,
  required String name,
  required String initials,
  required int points,
  int monthly = 0,
  String rank = 'Beginner',
}) {
  return Member(
    userId: userId,
    name: name,
    rank: rank,
    initials: initials,
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

  late List<Member> savedMembers;
  late String? savedName;
  late int savedPoints;
  late int? savedRank;

  setUp(() {
    savedMembers = List<Member>.from(appState.members);
    savedName = appState.profileName;
    savedPoints = appState.profilePoints;
    savedRank = appState.profileRankPosition;
  });

  tearDown(() {
    appState.members
      ..clear()
      ..addAll(savedMembers);
    appState.profileName = savedName ?? '';
    appState.profilePoints = savedPoints;
    appState.profileRankPosition = savedRank;
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
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('All Time My Rank matches podium #1 for top XP member', (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 658;
    // Stale skill-sorted position must not override board-derived #1.
    appState.profileRankPosition = 99;
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Shan Lee', initials: 'SL', points: 658, monthly: 10),
        _member(userId: 2, name: 'makoy gas', initials: 'MG', points: 230, monthly: 80),
      ]);

    await pumpRankings(tester);

    expect(find.text('Leaderboard Rank'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('Unranked'), findsNothing);
  });

  testWidgets('This Month uses monthly XP order and Unranked when zero monthly',
      (tester) async {
    appState.profileName = 'Quiet Member';
    appState.profilePoints = 400;
    appState.profileRankPosition = 2;
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Active Member', initials: 'AM', points: 500, monthly: 90),
        _member(userId: 2, name: 'Quiet Member', initials: 'QM', points: 400, monthly: 0),
        _member(userId: 3, name: 'Rising Member', initials: 'RM', points: 100, monthly: 40),
      ]);

    await pumpRankings(tester);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();

    // Quiet Member has 0 monthly XP → Unranked badge, not all-time #2.
    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('90 XP'), findsOneWidget);
    expect(find.text('40 XP'), findsOneWidget);
    // Zero-monthly member is excluded from the monthly board list.
    expect(find.text('0 XP'), findsNothing);
  });

  testWidgets('Equal XP uses name then stable order for podium places', (tester) async {
    appState.profileName = 'Amy';
    appState.profilePoints = 100;
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 2, name: 'Zoe', initials: 'Z', points: 100, monthly: 5),
        _member(userId: 1, name: 'Amy', initials: 'A', points: 100, monthly: 5),
        _member(userId: 3, name: 'Bob', initials: 'B', points: 50, monthly: 5),
      ]);

    await pumpRankings(tester);

    // Amy sorts before Zoe at equal XP → My Rank #1.
    expect(find.text('Leaderboard Rank'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
  });
}
