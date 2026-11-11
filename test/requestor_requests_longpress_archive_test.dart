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
    memberDataController.isLoading = false;
    memberDataController.error = null;
    appState.setServiceRequests([
      ServiceRequest(
        id: 'r-pending',
        requestId: 48,
        eventName: 'IT days',
        eventDate: DateTime(2026, 11, 18),
        requesterName: 'LT',
        status: 'Pending',
      ),
      ServiceRequest(
        id: 'r-completed',
        requestId: 44,
        eventName: 'Faculty Meeting',
        eventDate: DateTime(2026, 10, 23),
        requesterName: 'LT',
        status: 'Completed',
      ),
      ServiceRequest(
        id: 'r-archived',
        requestId: 40,
        eventName: 'Archived Seminar',
        eventDate: DateTime(2026, 9, 12),
        requesterName: 'LT',
        status: 'Rejected',
        requestorArchivedAt: DateTime(2026, 10, 1),
      ),
    ]);
  });

  tearDown(() {
    appState.setServiceRequests([]);
  });

  Future<void> pumpRequests(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RequestScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('long-press completed request offers View Details and Archive',
      (tester) async {
    await pumpRequests(tester);

    await tester.longPress(find.text('Faculty Meeting'));
    await tester.pumpAndSettle();

    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Archive Request'), findsOneWidget);
    expect(find.text('Restore Request'), findsNothing);
  });

  testWidgets('long-press pending request offers View Details only',
      (tester) async {
    await pumpRequests(tester);

    await tester.longPress(find.text('IT days'));
    await tester.pumpAndSettle();

    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Archive Request'), findsNothing);
    expect(find.text('Restore Request'), findsNothing);
  });

  testWidgets('archived filter and long-press restore action', (tester) async {
    await pumpRequests(tester);

    expect(find.text('Archived Seminar'), findsNothing);
    await tester.tap(find.textContaining('Archived'));
    await tester.pumpAndSettle();

    expect(find.text('Archived Seminar'), findsOneWidget);

    await tester.longPress(find.text('Archived Seminar'));
    await tester.pumpAndSettle();

    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Restore Request'), findsOneWidget);
    expect(find.text('Archive Request'), findsNothing);
  });

  testWidgets('archive confirmation dialog appears from sheet', (tester) async {
    await pumpRequests(tester);

    await tester.longPress(find.text('Faculty Meeting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Request'));
    await tester.pumpAndSettle();

    expect(find.text('Archive this request?'), findsOneWidget);
    expect(find.text('Archive Request'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Archive this request?'), findsNothing);
  });
}
