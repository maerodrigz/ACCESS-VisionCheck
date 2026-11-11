import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_home_dashboard.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1.0,
  VoidCallback? onRankings,
  VoidCallback? onFeedback,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 1400),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: MemberHomeDashboard(
            userName: 'Shan Lee',
            onViewRankings: onRankings ?? () {},
            onViewAllRequestorFeedback: onFeedback ?? () {},
            onViewPortfolio: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.scrollUntilVisible(
    find.text('Skill Progress'),
    280,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late AuthUser? savedUser;
  late bool savedRatingsLoaded;
  late String? savedRatingsError;
  late List<Map<String, dynamic>> savedRatings;
  late int savedCount;
  late double? savedAverage;

  setUp(() {
    savedUser = authController.user;
    savedRatingsLoaded = memberDataController.requestorRatingsLoaded;
    savedRatingsError = memberDataController.requestorRatingsLoadError;
    savedRatings = List<Map<String, dynamic>>.from(
      memberDataController.requestorRatings,
    );
    savedCount = memberDataController.requestorRatingCount;
    savedAverage = memberDataController.requestorRatingAverage;

    authController.debugSetUserForTest(const AuthUser(
      id: 11,
      name: 'Shan Lee',
      email: 'shan@example.com',
      role: AccessRole.member,
      token: 'test-token',
    ));
    memberDataController.requestorRatingsLoaded = true;
    memberDataController.requestorRatingsLoadError = null;
    memberDataController.requestorRatingCount = 0;
    memberDataController.requestorRatingAverage = null;
    memberDataController.requestorRatings.clear();
  });

  tearDown(() {
    authController.debugSetUserForTest(savedUser);
    memberDataController.requestorRatingsLoaded = savedRatingsLoaded;
    memberDataController.requestorRatingsLoadError = savedRatingsError;
    memberDataController.requestorRatingCount = savedCount;
    memberDataController.requestorRatingAverage = savedAverage;
    memberDataController.requestorRatings
      ..clear()
      ..addAll(savedRatings);
  });

  testWidgets('home shows Skill Progress and Requestor Feedback cards',
      (tester) async {
    await _pumpHome(tester, width: 390);

    expect(find.text('Skill Progress'), findsOneWidget);
    expect(find.text('Requestor Feedback'), findsOneWidget);
    expect(find.text('Rankings'), findsWidgets);
    expect(find.text('View All'), findsWidgets);
    expect(find.text('No requestor feedback yet.'), findsOneWidget);

    final snapshot = MemberCompetencySnapshot.fromAppState();
    expect(find.text(snapshot.levelName), findsWidgets);
    expect(find.textContaining('XP'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback-present state shows member-specific preview', (tester) async {
    memberDataController.requestorRatingCount = 1;
    memberDataController.requestorRatingAverage = 5;
    memberDataController.requestorRatings
      ..clear()
      ..add({
        'rating': 5,
        'event_title': 'Campus Documentation Day',
        'comment': 'Excellent coverage and timely delivery.',
        'created_at': '2026-11-05T08:00:00Z',
        'request_id': 99,
      });

    await _pumpHome(tester);

    expect(find.text('Campus Documentation Day'), findsOneWidget);
    expect(find.text('Excellent coverage and timely delivery.'), findsOneWidget);
    expect(find.text('Nov 5, 2026'), findsOneWidget);
    expect(find.text('No requestor feedback yet.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rankings and View All remain tappable', (tester) async {
    var rankings = 0;
    var feedback = 0;
    await _pumpHome(
      tester,
      onRankings: () => rankings++,
      onFeedback: () => feedback++,
    );

    await tester.tap(find.text('Rankings').first);
    await tester.pump();
    expect(rankings, greaterThan(0));

    // Prefer the Requestor Feedback "View All" (below that heading).
    final feedbackViewAll = find.descendant(
      of: find.ancestor(
        of: find.text('Requestor Feedback'),
        matching: find.byType(Column),
      ),
      matching: find.text('View All'),
    );
    await tester.tap(feedbackViewAll.first);
    await tester.pump();
    expect(feedback, 1);
  });

  testWidgets('wide width keeps Skill Progress above Requestor Feedback',
      (tester) async {
    await _pumpHome(tester, width: 390);

    final skillY = tester.getTopLeft(find.text('Skill Progress')).dy;
    final feedbackY = tester.getTopLeft(find.text('Requestor Feedback')).dy;
    expect(feedbackY, greaterThan(skillY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow width stacks without overflow', (tester) async {
    await _pumpHome(tester, width: 320, textScale: 1.2);
    expect(find.text('Skill Progress'), findsOneWidget);
    expect(find.text('Requestor Feedback'), findsOneWidget);
    final skillY = tester.getTopLeft(find.text('Skill Progress')).dy;
    final feedbackY = tester.getTopLeft(find.text('Requestor Feedback')).dy;
    expect(feedbackY, greaterThan(skillY));
    expect(tester.takeException(), isNull);
  });
}
