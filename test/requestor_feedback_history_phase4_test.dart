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
    appState.serviceRequests.clear();
    appState.feedbacks.clear();
  });

  tearDown(() {
    appState.serviceRequests.clear();
    appState.feedbacks.clear();
  });

  Future<void> pumpFeedback(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 1800);
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

  testWidgets('empty submissions state shows count zero', (tester) async {
    await pumpFeedback(tester);

    expect(find.text('Your Submissions'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('No feedback submitted yet.'), findsOneWidget);
  });

  testWidgets('compact history card expands and collapses with real content',
      (tester) async {
    appState.feedbacks.add(
      EventFeedback(
        eventTitle: 'Faculty Meeting',
        type: 'Documentation quality',
        message:
            'Photos were clear and delivered on time. Coverage included the main program and networking segment with useful angles.',
        rating: 4,
        date: 'Nov 10, 14:30',
        requestId: 21,
        adminResponse: 'Thank you for the helpful notes.',
        reviewStatus: 'reviewed',
      ),
    );

    await pumpFeedback(tester);

    expect(find.text('Your Submissions'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Faculty Meeting'), findsOneWidget);
    expect(find.text('Documentation quality'), findsOneWidget);
    expect(find.text('Nov 10, 14:30'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('ACCESS team response'), findsNothing);

    // Collapsed preview truncates long message.
    final preview = tester.widget<Text>(
      find.textContaining('Photos were clear').first,
    );
    expect(preview.maxLines, 2);

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('Hide details'), findsOneWidget);
    expect(find.text('ACCESS team response'), findsOneWidget);
    expect(find.text('Thank you for the helpful notes.'), findsOneWidget);

    final expanded = tester.widget<Text>(
      find.textContaining('Photos were clear').first,
    );
    expect(expanded.maxLines, isNull);

    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle();
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('ACCESS team response'), findsNothing);
  });

  testWidgets('history remains read-only with no edit or delete actions',
      (tester) async {
    appState.feedbacks.add(
      EventFeedback(
        eventTitle: 'Campus Fair',
        type: 'Suggestion',
        message: 'Add a short highlight reel next time.',
        rating: 5,
        date: 'Oct 2, 09:15',
        requestId: 44,
      ),
    );

    await pumpFeedback(tester);

    expect(find.text('Edit Feedback'), findsNothing);
    expect(find.text('Delete Feedback'), findsNothing);
    expect(find.text('Resubmit Feedback'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });
}
