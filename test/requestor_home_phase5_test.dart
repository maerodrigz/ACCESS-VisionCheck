import 'package:access_mobile/mobile_app/screens/requestor/requestor_home_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
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
    final savedEvent = Set<int>.from(memberDataController.requestorEventFeedbackRequestIds);
    final savedTeamRequired =
        Set<int>.from(memberDataController.requestorTeamRequiredRequestIds);
    final savedTeamDone =
        Set<int>.from(memberDataController.requestorTeamCompleteRequestIds);
    addTearDown(() {
      appState.setServiceRequests(savedRequests);
      memberDataController.requestorEventFeedbackRequestIds
        ..clear()
        ..addAll(savedEvent);
      memberDataController.requestorTeamRequiredRequestIds
        ..clear()
        ..addAll(savedTeamRequired);
      memberDataController.requestorTeamCompleteRequestIds
        ..clear()
        ..addAll(savedTeamDone);
    });
  });

  testWidgets('upcoming order, feedback eligibility, and declined actions', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    memberDataController.requestorEventFeedbackRequestIds
      ..clear()
      ..add(8);
    memberDataController.requestorTeamRequiredRequestIds.clear();
    memberDataController.requestorTeamCompleteRequestIds.clear();

    appState.setServiceRequests([
      _request(
        id: 'later',
        name: 'Later Coverage',
        date: day.add(const Duration(days: 10)),
        status: 'Approved',
        location: 'Hall B',
      ),
      _request(
        id: 'nearest',
        name: 'Nearest Coverage',
        date: day.add(const Duration(days: 1)),
        status: 'Approved',
        start: '9:00 AM',
        end: '11:00 AM',
        location: 'Main Hall',
      ),
      _request(
        id: 'past',
        name: 'Past Coverage',
        date: day.subtract(const Duration(days: 2)),
        status: 'Approved',
      ),
      _request(
        id: 'waiting',
        name: 'Ordinary Pending',
        date: day.add(const Duration(days: 3)),
        status: 'Pending',
      ),
      _request(
        id: 'declined',
        name: 'Needs Review',
        date: day.add(const Duration(days: 4)),
        status: 'Rejected',
        rejectionReason: 'Date conflicts with another event.',
      ),
      _request(
        id: 'due',
        requestId: 7,
        name: 'Feedback Due Event',
        date: day.subtract(const Duration(days: 5)),
        status: 'Completed',
      ),
      _request(
        id: 'done',
        requestId: 8,
        name: 'Feedback Already Sent',
        date: day.subtract(const Duration(days: 6)),
        status: 'Completed',
      ),
    ]);

    var feedbackId = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestorHomeScreen(
            userName: 'Lin Ti',
            onOpenRequestTab: ({RequestStatus? filter}) {},
            onOpenFeedback: ({int? requestId}) => feedbackId = requestId ?? -1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nearest Coverage'), findsOneWidget);
    expect(find.text('Later Coverage'), findsWidgets);
    expect(find.text('Past Coverage'), findsNothing);
    expect(find.text('Main Hall'), findsOneWidget);
    expect(find.textContaining('9:00 AM'), findsOneWidget);

    expect(find.text('Action Required'), findsOneWidget);
    expect(find.text('Needs Review'), findsWidgets);
    expect(find.text('View request'), findsOneWidget);
    expect(find.text('Date conflicts with another event.'), findsOneWidget);

    expect(find.text('Feedback Due Event'), findsOneWidget);
    expect(find.text('Give Feedback'), findsOneWidget);
    expect(find.text('Feedback Already Sent'), findsNothing);
    expect(find.text('No feedback due'), findsNothing);

    await tester.tap(find.text('Give Feedback'));
    await tester.pump();
    expect(feedbackId, 7);
  });

  testWidgets('hides Action Required and shows empty upcoming and feedback', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    appState.setServiceRequests([]);
    memberDataController.requestorEventFeedbackRequestIds.clear();
    memberDataController.requestorTeamRequiredRequestIds.clear();
    memberDataController.requestorTeamCompleteRequestIds.clear();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestorHomeScreen(
            userName: 'Lin Ti',
            onOpenRequestTab: ({RequestStatus? filter}) {},
            onOpenFeedback: ({int? requestId}) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Action Required'), findsNothing);
    expect(find.text('No upcoming coverage'), findsOneWidget);
    expect(find.text('No feedback due'), findsOneWidget);
    expect(find.text('Give Feedback'), findsNothing);
  });
}

ServiceRequest _request({
  required String id,
  required String name,
  required DateTime date,
  required String status,
  int? requestId,
  String? location,
  String? start,
  String? end,
  String? rejectionReason,
}) {
  return ServiceRequest(
    id: id,
    requestId: requestId,
    eventName: name,
    eventDate: date,
    requesterName: 'Lin Ti',
    status: status,
    location: location,
    startTime: start,
    endTime: end,
    rejectionReason: rejectionReason,
  );
}
