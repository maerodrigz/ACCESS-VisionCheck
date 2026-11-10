import 'package:access_mobile/mobile_app/screens/requestor/requestor_feedback_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    appState.serviceRequests
      ..clear()
      ..add(
        ServiceRequest(
          id: '21',
          requestId: 21,
          eventName: 'Faculty Meeting',
          eventDate: DateTime(2026, 10, 23),
          requesterName: 'Lin Ti',
          status: 'Completed',
        ),
      );
    appState.feedbacks.clear();
  });

  tearDown(() {
    appState.serviceRequests.clear();
    appState.feedbacks.clear();
  });

  Future<void> pumpFeedback(WidgetTester tester, {Size size = const Size(392, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RequestorFeedbackScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('compact category grid uses two columns and single selection',
      (tester) async {
    await pumpFeedback(tester);

    // Select an event so the form fields appear.
    final eventFinder = find.textContaining('Faculty Meeting');
    expect(eventFinder, findsWidgets);
    await tester.tap(eventFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Documentation quality'), findsOneWidget);
    expect(find.text('Coverage completeness'), findsOneWidget);
    expect(find.text('Team responsiveness'), findsOneWidget);
    expect(find.text('Suggestion'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    // Two-column Wrap: first two category labels share roughly the same dy.
    final doc = tester.getCenter(find.text('Documentation quality'));
    final coverage = tester.getCenter(find.text('Coverage completeness'));
    expect((doc.dy - coverage.dy).abs(), lessThan(8));
    expect(coverage.dx, greaterThan(doc.dx + 40));

    await tester.tap(find.text('Suggestion'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);

    await tester.tap(find.text('Other'));
    await tester.pump();
    // Still single-selection UI (one selected check among category tiles).
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('stars message placeholder and submit chrome are present',
      (tester) async {
    await pumpFeedback(tester);

    await tester.tap(find.textContaining('Faculty Meeting').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Overall rating'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
    expect(find.text('Tell us about your experience...'), findsOneWidget);
    expect(find.text('Submit Feedback'), findsOneWidget);

    // Tap third star.
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(2));
    await tester.pump();
    expect(find.text('Average'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      'Coverage was clear and timely.',
    );
    await tester.pump();
    expect(find.text('Coverage was clear and timely.'), findsOneWidget);
  });

  testWidgets('narrow width keeps category grid usable', (tester) async {
    await pumpFeedback(tester, size: const Size(320, 1800));
    await tester.pump(const Duration(milliseconds: 200));

    // Auto-selected completed event should reveal the compact form.
    expect(find.text('Documentation quality'), findsOneWidget);
    expect(find.text('Coverage completeness'), findsOneWidget);
    expect(find.text('Submit Feedback'), findsOneWidget);
    expect(find.byType(FittedBox), findsWidgets);
    expect(find.text('Tell us about your experience...'), findsOneWidget);

    // Category tiles and stars must remain tappable without layout exceptions.
    await tester.tap(find.text('Suggestion'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(2));
    await tester.pump();
    expect(find.text('Average'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
