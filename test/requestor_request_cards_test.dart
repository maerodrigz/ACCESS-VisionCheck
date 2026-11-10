import 'package:access_mobile/mobile_app/screens/requestor/request_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    final savedRequests = List<ServiceRequest>.from(appState.serviceRequests);
    final wasLoading = memberDataController.isLoading;
    final savedError = memberDataController.error;
    memberDataController.isLoading = false;
    memberDataController.error = null;
    addTearDown(() {
      appState.setServiceRequests(savedRequests);
      memberDataController.isLoading = wasLoading;
      memberDataController.error = savedError;
    });
  });

  testWidgets('compact cards show title, request id, status, meta, and stages',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.setServiceRequests([
      ServiceRequest(
        id: 'r-pending',
        requestId: 48,
        eventName: 'IT days',
        eventDate: DateTime(2026, 11, 18),
        startTime: '8:00 AM',
        endTime: '5:00 PM',
        location: 'USTP OROQUIETA CAMPUS',
        requesterName: 'LT',
        status: 'Pending',
        submissionDate: DateTime(2026, 11, 1),
      ),
      ServiceRequest(
        id: 'r-declined',
        requestId: 40,
        eventName: 'Long Declined Campus Documentation Coverage Event',
        eventDate: DateTime(2026, 10, 10),
        requesterName: 'LT',
        status: 'Rejected',
        submissionDate: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 2),
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: RequestScreen()));
    await tester.pumpAndSettle();

    expect(find.text('IT days'), findsOneWidget);
    expect(find.text('Request #48'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(find.textContaining('8:00 AM'), findsOneWidget);
    expect(find.textContaining('USTP OROQUIETA CAMPUS'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.text('In review'), findsWidgets);
    expect(find.textContaining('Tracking:'), findsNothing);

    expect(find.textContaining('Long Declined'), findsOneWidget);
    expect(find.text('Declined'), findsWidgets);
    expect(find.text('Request declined'), findsNothing);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });
}
