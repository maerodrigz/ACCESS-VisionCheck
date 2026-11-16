import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_home_dashboard.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(WidgetTester tester, {double width = 360}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: MemberHomeDashboard(
            userName: 'Shan Lee',
            onRefresh: () async {},
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

  late List<Challenge> savedChallenges;
  late List<CalendarEvent> savedEvents;
  late int savedUploads;
  late double savedAvg;
  late String savedName;

  setUp(() {
    savedChallenges = List.of(appState.challenges);
    savedEvents = List.of(appState.events);
    savedUploads = appState.profileUploads;
    savedAvg = appState.profileAverageScore;
    savedName = appState.profileName;

    appState.profileName = 'Shan Lee';
    appState.profileUploads = 17;
    appState.profileAverageScore = 0.72;
    appState.gallery.clear();
    appState.events
      ..clear()
      ..add(
        CalendarEvent(
          tag: 'Event',
          title: 'Campus Coverage',
          date: 'Fri, Nov 20, 2026',
          description: 'Coverage',
          status: 'Confirmed',
          statusColor: Colors.green,
          startDate: DateTime(2026, 11, 20, 9),
          endDate: DateTime(2026, 11, 20, 15),
          timeLabel: '9:00 AM – 3:00 PM',
          location: 'Library',
          requestId: 42,
        ),
      );
    appState.challenges
      ..clear()
      ..add(
        Challenge(
          requestId: 42,
          title: 'Campus Coverage',
          description: 'photo · Library',
          xp: 10,
          status: 'pending_acceptance',
          venue: 'Library',
          eventDate: 'Fri, Nov 20, 2026',
          eventTime: '9:00 AM – 3:00 PM',
          eventTimeRange: '9:00 AM – 3:00 PM',
        ),
      );
  });

  tearDown(() {
    appState.challenges
      ..clear()
      ..addAll(savedChallenges);
    appState.events
      ..clear()
      ..addAll(savedEvents);
    appState.profileUploads = savedUploads;
    appState.profileAverageScore = savedAvg;
    appState.profileName = savedName;
  });

  testWidgets('phase 2 upper content matches greeting, assignment, and stats',
      (tester) async {
    await _pumpHome(tester);

    expect(
      find.text('${memberDashboardGreeting()}, Shan!'),
      findsOneWidget,
    );
    expect(find.text('Here\'s your documentation overview.'), findsOneWidget);
    expect(find.text('My Next Assignment'), findsOneWidget);
    expect(find.text('Campus Coverage'), findsWidgets);
    expect(find.text('Fri, Nov 20, 2026'), findsOneWidget);
    expect(find.text('9:00 AM – 3:00 PM'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('My Tasks'), findsWidgets);
    expect(find.text('Uploads'), findsOneWidget);
    expect(find.text('Avg. Quality'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('Upcoming Event'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/requestor_greeting_illustration.png',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('memberNextAssignment skips past-dated events without changing status',
      () {
    appState.events
      ..clear()
      ..add(
        CalendarEvent(
          tag: 'Event',
          title: 'Old Coverage',
          date: 'Fri, Nov 6, 2026',
          description: 'Past',
          status: 'Pending',
          statusColor: Colors.orange,
          startDate: DateTime(2026, 11, 6, 9),
          requestId: 7,
          location: 'Hall',
        ),
      );
    appState.challenges
      ..clear()
      ..add(
        Challenge(
          requestId: 7,
          title: 'Old Coverage',
          description: 'photo · Hall',
          xp: 10,
          status: 'pending_acceptance',
          venue: 'Hall',
          eventDate: 'Fri, Nov 6, 2026',
        ),
      );

    expect(memberNextAssignment(), isNull);
    expect(appState.challenges.single.status, 'pending_acceptance');
  });
}
