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
  Color? color,
}) {
  return Member(
    userId: userId,
    name: name,
    rank: rank,
    initials: initials,
    uploads: 3,
    goodEvaluations: points,
    monthlyPoints: monthly,
    avatarColor: color ?? const Color(0xFF0052D4),
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
  late String? savedSkill;

  setUp(() {
    savedMembers = List<Member>.from(appState.members);
    savedName = appState.profileName;
    savedPoints = appState.profilePoints;
    savedRank = appState.profileRankPosition;
    savedSkill = appState.profileSkillLevel;
  });

  tearDown(() {
    appState.members
      ..clear()
      ..addAll(savedMembers);
    appState.profileName = savedName ?? '';
    appState.profilePoints = savedPoints;
    appState.profileRankPosition = savedRank;
    appState.profileSkillLevel = savedSkill;
    appState.notifyListeners();
  });

  Future<void> pumpRankings(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RankingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('podium shows Top Members with places 2-1-3 and leaderboard rest',
      (tester) async {
    appState.profileName = 'Shan Lee';
    appState.profilePoints = 658;
    appState.profileRankPosition = 1;
    appState.profileSkillLevel = 'Intermediate';
    appState.members
      ..clear()
      ..addAll([
        _member(
          userId: 1,
          name: 'Shan Lee',
          initials: 'SL',
          points: 658,
          monthly: 100,
          rank: 'Intermediate',
        ),
        _member(
          userId: 2,
          name: 'makoy gas',
          initials: 'MG',
          points: 230,
          monthly: 80,
          rank: 'Beginner',
        ),
        _member(
          userId: 3,
          name: 'Dan Thee',
          initials: 'DT',
          points: 224,
          monthly: 70,
          rank: 'Beginner',
        ),
        _member(
          userId: 4,
          name: 'Mela Dee With A Very Long Display Name',
          initials: 'MD',
          points: 40,
          monthly: 10,
          rank: 'Beginner',
          color: const Color(0xFF22C55E),
        ),
      ]);

    await pumpRankings(tester);

    expect(find.text('Top Members'), findsOneWidget);
    expect(find.text('4 members'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/rankings/rankings_podium.png')),
      findsOneWidget,
    );
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('Intermediate'), findsWidgets);
    expect(find.text('Beginner'), findsWidgets);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('Mela Dee With A Very Long Display Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('podium with one member does not invent places 2 and 3', (tester) async {
    appState.profileName = 'Solo Member';
    appState.profilePoints = 50;
    appState.profileRankPosition = 1;
    appState.members
      ..clear()
      ..add(_member(userId: 9, name: 'Solo Member', initials: 'SM', points: 50));

    await pumpRankings(tester, width: 320);

    expect(find.text('Top Members'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#2'), findsNothing);
    expect(find.text('#3'), findsNothing);
    expect(find.text('Leaderboard'), findsNothing);
  });

  testWidgets('This Month filters podium XP and excludes zero monthly members',
      (tester) async {
    appState.profileName = 'Active Member';
    appState.profilePoints = 500;
    appState.profileRankPosition = 1;
    appState.members
      ..clear()
      ..addAll([
        _member(userId: 1, name: 'Active Member', initials: 'AM', points: 500, monthly: 90),
        _member(userId: 2, name: 'Quiet Member', initials: 'QM', points: 400, monthly: 0),
        _member(userId: 3, name: 'Rising Member', initials: 'RM', points: 100, monthly: 40),
      ]);

    await pumpRankings(tester);
    await tester.tap(find.text('This Month'));
    await tester.pump();

    expect(find.text('Active Member'), findsWidgets);
    expect(find.text('Rising Member'), findsOneWidget);
    expect(find.text('Quiet Member'), findsNothing);
    expect(find.text('2 members'), findsOneWidget);
  });
}
