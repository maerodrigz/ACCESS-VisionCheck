import 'package:access_mobile/mobile_app/utils/skill_progress_trend.dart';
import 'package:access_mobile/mobile_app/widgets/member_home_dashboard.dart';
import 'package:access_mobile/mobile_app/widgets/member_skill_progress_section.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

Evaluation _ev({
  required double score,
  required DateTime at,
  String feedback = '',
  String reviewStatus = 'verified',
}) {
  return Evaluation(
    id: 'MED-${at.millisecondsSinceEpoch}',
    title: 'Practice',
    score: score,
    composition: '',
    lighting: '',
    feedback: feedback,
    date: at.toIso8601String(),
    evaluatedAt: at,
    reviewStatus: reviewStatus,
  );
}

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(360, 1400)),
      child: MaterialApp(
        home: Scaffold(
          body: MemberHomeDashboard(
            userName: 'Shan Lee',
            onViewPortfolio: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpOverview(WidgetTester tester, {VoidCallback? onViewDetails}) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(360, 900)),
      child: MaterialApp(
        home: Scaffold(
          body: MemberSkillProgressSection(
            layout: MemberSkillProgressLayout.homeOverview,
            onViewDetails: onViewDetails ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<Evaluation> savedEvaluations;
  late bool savedTabSynced;
  late String? savedTabError;

  setUp(() {
    savedEvaluations = List.of(appState.evaluations);
    savedTabSynced = memberDataController.evaluationsTabSynced;
    savedTabError = memberDataController.evaluationsTabError;
    appState.evaluations.clear();
    memberDataController.evaluationsTabSynced = true;
    memberDataController.evaluationsTabError = null;
  });

  tearDown(() {
    appState.evaluations
      ..clear()
      ..addAll(savedEvaluations);
    memberDataController.evaluationsTabSynced = savedTabSynced;
    memberDataController.evaluationsTabError = savedTabError;
  });

  testWidgets('member home no longer shows Performance Overview', (tester) async {
    await _pumpHome(tester);
    expect(find.text('Performance Overview'), findsNothing);
    expect(find.byType(MemberSkillProgressSection), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview widget shows latest/previous/delta', (tester) async {
    final t0 = DateTime(2026, 11, 1);
    final t1 = DateTime(2026, 11, 5);
    appState.evaluations.addAll([
      _ev(score: 0.77, at: t0),
      _ev(score: 0.84, at: t1, feedback: 'Nice framing.'),
    ]);

    await _pumpOverview(tester);

    expect(find.text('Performance Overview'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Latest Quality'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('84%'), findsWidgets);
    expect(find.text('77%'), findsOneWidget);
    expect(find.text('+7 pts'), findsOneWidget);
    expect(find.text('Improving'), findsOneWidget);
    expect(
      find.text('Your recent quality scores are moving up.'),
      findsOneWidget,
    );
    expect(find.text('Latest feedback'), findsOneWidget);
    expect(find.text('Nice framing.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero eligible scores shows unavailable metrics and trend copy',
      (tester) async {
    await _pumpOverview(tester);

    expect(find.text('Performance Overview'), findsOneWidget);
    expect(find.text('N/A'), findsWidgets);
    expect(find.text('Insufficient data'), findsOneWidget);
    expect(
      find.text('More eligible evaluations are needed to show a trend.'),
      findsOneWidget,
    );
  });

  testWidgets('one eligible score keeps previous and change unavailable',
      (tester) async {
    appState.evaluations.add(_ev(score: 0.70, at: DateTime(2026, 11, 2)));
    await _pumpOverview(tester);

    expect(find.text('70%'), findsWidgets);
    expect(find.text('N/A'), findsWidgets);
    expect(find.text('Insufficient data'), findsOneWidget);
  });

  testWidgets('declining delta renders correctly on overview widget', (tester) async {
    final base = DateTime(2026, 10, 1);
    appState.evaluations.addAll([
      _ev(score: 0.80, at: base),
      _ev(score: 0.75, at: base.add(const Duration(days: 1))),
    ]);
    await _pumpOverview(tester);
    expect(find.text('-5 pts'), findsOneWidget);
    expect(find.text('Declining'), findsOneWidget);
  });

  testWidgets('unchanged delta renders stable on overview widget', (tester) async {
    final base = DateTime(2026, 10, 1);
    appState.evaluations.addAll([
      _ev(score: 0.70, at: base),
      _ev(score: 0.70, at: base.add(const Duration(days: 2))),
    ]);
    await _pumpOverview(tester);
    expect(find.text('0 pts'), findsOneWidget);
    expect(find.text('Stable'), findsOneWidget);
  });

  testWidgets('pending evaluations are excluded from overview metrics',
      (tester) async {
    final t0 = DateTime(2026, 11, 1);
    appState.evaluations.addAll([
      _ev(score: 0.60, at: t0),
      _ev(
        score: 0.95,
        at: t0.add(const Duration(days: 1)),
        reviewStatus: 'pending_review',
      ),
      _ev(score: 0.68, at: t0.add(const Duration(days: 2))),
    ]);
    await _pumpOverview(tester);

    final chronological = chronologicalEligibleEvaluations(appState.evaluations);
    expect(chronological.length, 2);
    expect(find.text('68%'), findsWidgets);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('95%'), findsNothing);
  });

  testWidgets('View Details is tappable', (tester) async {
    var tapped = false;
    await _pumpOverview(tester, onViewDetails: () => tapped = true);
    await tester.tap(find.text('View Details'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
