import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('compact detail shows summary, progress, and hides awaiting card',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final request = ServiceRequest(
      id: 'REQ-48',
      requestId: 48,
      eventName: 'IT days',
      eventDate: DateTime(2026, 11, 18),
      startTime: '8:00 AM',
      endTime: '5:00 PM',
      location: 'USTP OROQUIETA CAMPUS',
      requesterName: 'Lin Ti',
      status: 'Pending',
      submissionDate: DateTime(2026, 11, 9),
      requirements: 'Coverage needed: Photo',
      description: 'Campus IT celebration',
    );

    await tester.pumpWidget(
      MaterialApp(home: RequestDetailScreen(request: request)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request Details'), findsOneWidget);
    expect(find.text('IT days'), findsOneWidget);
    expect(find.text('Request #48'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Request Progress'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.text('In Review'), findsWidgets);
    expect(find.text('Approved'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Awaiting review'), findsNothing);
    expect(
      find.textContaining('An administrator will approve or decline'),
      findsOneWidget,
    );
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Documentation Requirements'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('completed request shows archive menu', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final request = ServiceRequest(
      id: 'REQ-45',
      requestId: 45,
      eventName: 'FACULTY MEETING',
      eventDate: DateTime(2026, 10, 23),
      requesterName: 'Lin Ti',
      status: 'Completed',
      updatedAt: DateTime(2026, 10, 24),
    );

    await tester.pumpWidget(
      MaterialApp(home: RequestDetailScreen(request: request)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Rate'), findsOneWidget);
  });
}
