import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/quality_skill_classification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Member _member({
  required int userId,
  required String name,
  required String initials,
  required int points,
}) {
  return Member(
    userId: userId,
    name: name,
    rank: 'Beginner',
    initials: initials,
    uploads: 1,
    goodEvaluations: points,
    monthlyPoints: points,
    avatarColor: const Color(0xFF0052D4),
  );
}

MediaQualityClassification _skill({
  required String kind,
  required String title,
  required int count,
  required bool classified,
  double? average,
  String progress = '',
}) {
  return MediaQualityClassification(
    mediaKind: kind,
    title: title,
    qualifyingEvaluations: count,
    classified: classified,
    averageScore: average,
    averageScoreDisplay: average,
    progressSummary: progress,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<Member> savedMembers;
  late QualitySkillClassificationSnapshot? savedSkill;
  late String? savedSkillError;
  late bool savedSkillLoading;

  setUp(() {
    savedMembers = List<Member>.from(appState.members);
    savedSkill = memberDataController.qualitySkillClassification;
    savedSkillError = memberDataController.qualitySkillClassificationError;
    savedSkillLoading = memberDataController.qualitySkillClassificationLoading;
    memberDataController.rankingsLoading = false;
    memberDataController.rankingsError = null;
    memberDataController.qualitySkillClassification = null;
    memberDataController.qualitySkillClassificationError = null;
    memberDataController.qualitySkillClassificationLoading = false;
    appState.profileName = 'Member One';
    appState.profilePoints = 10;
  });

  tearDown(() {
    appState.members
      ..clear()
      ..addAll(savedMembers);
    memberDataController.qualitySkillClassification = savedSkill;
    memberDataController.qualitySkillClassificationError = savedSkillError;
    memberDataController.qualitySkillClassificationLoading = savedSkillLoading;
    memberDataController.rankingsLoading = false;
    memberDataController.rankingsError = null;
    appState.notifyListeners();
  });

  Future<void> pumpRankings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RankingsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  void board(List<Member> members) {
    appState.members
      ..clear()
      ..addAll(members);
  }

  testWidgets('one member appears on the podium and in the leaderboard', (tester) async {
    board([_member(userId: 1, name: 'Member One', initials: 'MO', points: 40)]);
    await pumpRankings(tester);

    expect(find.text('Top Members'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#2'), findsNothing);
    expect(find.text('Member One'), findsWidgets);
  });

  testWidgets('three members stay on the full leaderboard', (tester) async {
    board([
      _member(userId: 1, name: 'Member One', initials: 'MO', points: 90),
      _member(userId: 2, name: 'Member Two', initials: 'MT', points: 50),
      _member(userId: 3, name: 'Member Three', initials: 'MH', points: 20),
    ]);
    await pumpRankings(tester);

    expect(find.text('Top Members'), findsOneWidget);
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#2'), findsWidgets);
    expect(find.text('#3'), findsWidgets);
    expect(find.text('Member Three'), findsWidgets);
  });

  testWidgets('four or more members list ranks 1 through 4', (tester) async {
    board([
      _member(userId: 1, name: 'Member One', initials: 'MO', points: 90),
      _member(userId: 2, name: 'Member Two', initials: 'MT', points: 50),
      _member(userId: 3, name: 'Member Three', initials: 'MH', points: 20),
      _member(userId: 4, name: 'Member Four', initials: 'MF', points: 8),
    ]);
    await pumpRankings(tester);

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('Member Four'), findsOneWidget);
  });

  testWidgets('skill cards show API titles, counts, averages, and progress', (tester) async {
    board([_member(userId: 1, name: 'Member One', initials: 'MO', points: 40)]);
    memberDataController.qualitySkillClassification = QualitySkillClassificationSnapshot(
      photo: _skill(
        kind: 'photo',
        title: 'Developing',
        count: 4,
        classified: true,
        average: 2.4,
        progress: 'Toward Proficient: need 1 more qualifying evaluation.',
      ),
      video: _skill(
        kind: 'video',
        title: 'Not Yet Classified',
        count: 1,
        classified: false,
        progress: 'Complete at least 3 qualifying evaluations using the current scoring system.',
      ),
      disclaimer: 'Not a certification.',
    );
    await pumpRankings(tester);

    expect(find.text('Photo Skill'), findsOneWidget);
    expect(find.text('Video Skill'), findsOneWidget);
    expect(find.text('Developing'), findsOneWidget);
    expect(find.text('4 qualifying evaluations'), findsOneWidget);
    expect(find.text('2.40/5'), findsOneWidget);
    expect(find.text('Not Yet Classified'), findsWidgets);
    expect(find.text('1 qualifying evaluation'), findsOneWidget);
    expect(find.textContaining('Toward Proficient'), findsOneWidget);
    expect(find.text('2.00/5'), findsNothing);
  });

  testWidgets('skill classification error offers retry instead of a fake title', (tester) async {
    board([_member(userId: 1, name: 'Member One', initials: 'MO', points: 40)]);
    memberDataController.qualitySkillClassification = null;
    memberDataController.qualitySkillClassificationError = 'Server timeout';
    await pumpRankings(tester);

    expect(find.text('Could not load skill classification'), findsOneWidget);
    expect(find.text('Server timeout'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Photo Skill'), findsNothing);
    expect(find.text('Video Skill'), findsNothing);
    expect(find.text('Photo Skill: Not Yet Classified'), findsNothing);
    expect(find.text('Video Skill: Not Yet Classified'), findsNothing);
  });
}
