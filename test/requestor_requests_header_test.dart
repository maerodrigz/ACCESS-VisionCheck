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

  testWidgets('illustrated My Requests header shows live title and subtitle',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appState.setServiceRequests([
      ServiceRequest(
        id: 'r1',
        requestId: 1,
        eventName: 'Coverage Event',
        eventDate: DateTime(2026, 11, 20),
        requesterName: 'LT',
        status: 'Pending',
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: RequestScreen()));
    await tester.pumpAndSettle();

    expect(find.text('My Requests'), findsOneWidget);
    expect(
      find.text('Manage and track your documentation requests.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/requestor_requests_header.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Coverage Event'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('New Request'), findsOneWidget);
  });
}
