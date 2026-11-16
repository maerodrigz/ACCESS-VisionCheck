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

  testWidgets('event coverage and documenter sections use distinct labels',
      (tester) async {
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
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.textContaining('Faculty Meeting').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Event Coverage Feedback'), findsOneWidget);
    expect(
      find.text(
        'How satisfied are you with the documentation coverage of your event?',
      ),
      findsOneWidget,
    );
    expect(find.text('Required'), findsWidgets);
    expect(find.text('Rate Your Documenters'), findsOneWidget);
    expect(
      find.text('Rate each documenter assigned to your event.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No eligible documenters available'),
      findsOneWidget,
    );

    // Event-level categories keep historical identifiers.
    expect(find.text('Team responsiveness'), findsOneWidget);
    expect(find.text('Overall satisfaction'), findsOneWidget);

    // Legacy / optional headings must not remain.
    expect(find.text('Overall event feedback'), findsNothing);
    expect(find.text('Rate Photographers'), findsNothing);
    expect(find.text('Rate Team Members'), findsNothing);
    expect(
      find.textContaining('Optional. You can submit Event Coverage Feedback'),
      findsNothing,
    );
  });

  testWidgets('history distinguishes event coverage and documenter ratings',
      (tester) async {
    tester.view.physicalSize = const Size(392, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.feedbacks.add(
      EventFeedback(
        eventTitle: 'Faculty Meeting',
        type: 'Documentation quality',
        message: 'Clear coverage of the main program.',
        rating: 5,
        date: 'Nov 10, 14:30',
        requestId: 21,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RequestorFeedbackScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Event Coverage Rating'), findsOneWidget);
    expect(find.text('Category: Documentation quality'), findsOneWidget);
  });
}
