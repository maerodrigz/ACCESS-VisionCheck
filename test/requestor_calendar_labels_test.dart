import 'package:access_mobile/mobile_app/screens/calendar_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<CalendarEvent> savedEvents;
  late List<CalendarEvent> savedMine;

  setUp(() {
    savedEvents = List<CalendarEvent>.from(appState.events);
    savedMine = List<CalendarEvent>.from(appState.myCalendarEvents);
  });

  tearDown(() {
    appState.events
      ..clear()
      ..addAll(savedEvents);
    appState.myCalendarEvents
      ..clear()
      ..addAll(savedMine);
    appState.notifyListeners();
  });

  testWidgets('requestor cells show chips, agenda, tabs, and plan date', (tester) async {
    tester.view.physicalSize = const Size(360, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final quietDay = now.day == 15 ? 16 : 15;

    appState.events.clear();
    appState.myCalendarEvents
      ..clear()
      ..addAll([
        _event(
          id: 1,
          requestId: 11,
          title: 'IT Days',
          day: DateTime(now.year, now.month, 1, 9),
          end: DateTime(now.year, now.month, 1, 11),
          timeLabel: '9:00 AM',
          location: 'Main Hall',
          status: 'Pending',
          requestStatus: 'pending',
        ),
        _event(
          id: 2,
          requestId: 12,
          title: 'Leadership Seminar',
          day: DateTime(now.year, now.month, 2, 9),
          location: 'Hall B',
          status: 'Approved',
          requestStatus: 'approved',
        ),
        _event(
          id: 3,
          requestId: 13,
          title: 'Outreach Program',
          day: DateTime(now.year, now.month, 2, 13),
          location: 'Quad',
          status: 'Approved',
          requestStatus: 'approved',
        ),
        _event(
          id: 4,
          requestId: 14,
          title: 'University Leadership and Outreach Documentation Seminar',
          day: DateTime(now.year, now.month, 3, 10),
          status: 'Pending',
          requestStatus: 'pending',
        ),
      ]);
    appState.notifyListeners();

    DateTime? planned;
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          forRequestor: true,
          onPlanRequest: (day) => planned = day,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IT Days'), findsWidgets);
    expect(find.text('Seminar +1'), findsOneWidget);
    expect(find.text('Leadership'), findsOneWidget);

    await tester.tap(find.text('IT Days').first);
    await tester.pumpAndSettle();
    expect(find.text('1 event'), findsOneWidget);
    expect(find.textContaining('9:00 AM – 11:00 AM'), findsOneWidget);
    expect(find.textContaining('Main Hall'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);

    await tester.tap(find.text('Seminar +1'));
    await tester.pumpAndSettle();
    expect(find.text('2 events'), findsOneWidget);
    expect(find.text('Outreach Program'), findsWidgets);
    expect(find.text('Approved'), findsWidgets);

    await tester.tap(find.text('$quietDay').first);
    await tester.pumpAndSettle();
    expect(find.text('No events'), findsOneWidget);
    expect(find.text('Nothing scheduled for this day.'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Plan request for this date'),
      240,
    );
    await tester.tap(find.text('Plan request for this date'));
    await tester.pump();
    expect(planned, DateTime(now.year, now.month, quietDay));

    await tester.tap(find.text('All Events'));
    await tester.pumpAndSettle();
    expect(find.text('IT Days'), findsNothing);
    expect(find.text('Seminar +1'), findsNothing);

    appState.events.add(
      _event(
        id: 90,
        title: 'Campus Outreach Fair',
        day: DateTime(now.year, now.month, 4, 8),
        location: 'Gymnasium',
        status: 'Upcoming',
      ),
    );
    appState.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Outreach'), findsOneWidget);
    expect(find.text('IT Days'), findsNothing);

    await tester.tap(find.text('My Requests'));
    await tester.pumpAndSettle();
    expect(find.text('IT Days'), findsWidgets);
    expect(find.text('Outreach'), findsNothing);

    final monthLabel = '${_months[now.month - 1]} ${now.year}';
    expect(find.text(monthLabel), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
    await tester.pumpAndSettle();
    final next = DateTime(now.year, now.month + 1);
    expect(find.text('${_months[next.month - 1]} ${next.year}'), findsOneWidget);
    expect(find.text('IT Days'), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text(monthLabel), findsOneWidget);
    expect(find.text('IT Days'), findsWidgets);
  });

  testWidgets('member calendar keeps dot cells', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    appState.events.clear();
    appState.myCalendarEvents
      ..clear()
      ..addAll([
        _event(
          id: 1,
          title: 'Member Only Briefing',
          day: DateTime(now.year, now.month, 2, 9),
          status: 'Upcoming',
        ),
        _event(
          id: 2,
          title: 'Second Briefing',
          day: DateTime(now.year, now.month, 2, 13),
          status: 'Upcoming',
        ),
      ]);
    appState.notifyListeners();

    await tester.pumpWidget(
      const MaterialApp(home: CalendarScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('+1'), findsNothing);
    expect(find.text('My Assignments'), findsOneWidget);
    expect(find.text('Plan request for this date'), findsNothing);
  });
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

CalendarEvent _event({
  required int id,
  required String title,
  required DateTime day,
  required String status,
  int? requestId,
  DateTime? end,
  String timeLabel = '9:00 AM',
  String location = '',
  String? requestStatus,
}) {
  return CalendarEvent(
    id: id,
    requestId: requestId,
    tag: 'Event Documentation',
    title: title,
    date: '${day.month}/${day.day}',
    description: location,
    status: status,
    statusColor: const Color(0xFFF59E0B),
    startDate: day,
    endDate: end,
    timeLabel: timeLabel,
    location: location,
    requestStatus: requestStatus ?? status.toLowerCase(),
  );
}
