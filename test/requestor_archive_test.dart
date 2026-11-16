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
    final saved = List<ServiceRequest>.from(appState.serviceRequests);
    final wasLoading = memberDataController.isLoading;
    final savedError = memberDataController.error;
    memberDataController.isLoading = false;
    memberDataController.error = null;
    addTearDown(() {
      appState.setServiceRequests(saved);
      memberDataController.isLoading = wasLoading;
      memberDataController.error = savedError;
    });
  });

  testWidgets('active list hides archived; Archived chip shows them', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.setServiceRequests([
      ServiceRequest(
        id: 'r-active',
        requestId: 10,
        eventName: 'Active Completed Event',
        eventDate: DateTime(2026, 11, 1),
        requesterName: 'LT',
        status: 'Completed',
      ),
      ServiceRequest(
        id: 'r-archived',
        requestId: 11,
        eventName: 'Archived Declined Event',
        eventDate: DateTime(2026, 10, 1),
        requesterName: 'LT',
        status: 'Rejected',
        requestorArchivedAt: DateTime(2026, 10, 2),
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: RequestScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Active Completed Event'), findsOneWidget);
    expect(find.text('Archived Declined Event'), findsNothing);
    expect(find.textContaining('Archived (1)'), findsOneWidget);

    await tester.tap(find.textContaining('Archived (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Archived Declined Event'), findsOneWidget);
    expect(find.text('Active Completed Event'), findsNothing);
    expect(find.text('Archived'), findsWidgets);
    expect(find.text('Declined'), findsWidgets);
  });

  test('ServiceRequest archive helpers', () {
    final completed = ServiceRequest(
      id: '1',
      eventName: 'A',
      eventDate: DateTime(2026, 1, 1),
      requesterName: 'LT',
      status: 'Completed',
    );
    expect(completed.canRequestorArchive, isTrue);
    expect(completed.isRequestorArchived, isFalse);

    final pending = completed.copyWith(status: 'Pending');
    expect(pending.canRequestorArchive, isFalse);

    final archived = completed.copyWith(
      requestorArchivedAt: DateTime(2026, 1, 2),
    );
    expect(archived.isRequestorArchived, isTrue);
    expect(archived.canRequestorArchive, isFalse);
  });
}
