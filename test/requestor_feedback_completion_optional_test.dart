import 'package:access_mobile/mobile_app/requestor/requestor_feedback_status.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event feedback alone is incomplete when documenters are required', () {
    final completion = RequestorFeedbackCompletion(
      eventFeedbackRequestIds: {21},
      teamRequiredRequestIds: {21},
      teamCompleteRequestIds: const {},
    );
    final request = ServiceRequest(
      id: '21',
      requestId: 21,
      eventName: 'Faculty Meeting',
      eventDate: DateTime(2026, 10, 23),
      requesterName: 'Lin Ti',
      status: 'Completed',
    );

    expect(completion.eventDone(21), isTrue);
    expect(completion.teamDone(21), isFalse);
    expect(completion.fullyDone(request), isFalse);
    expect(completion.pending(request), isTrue);
    expect(completion.statusLabel(21), 'Documenter ratings due');
  });

  test('event-only completion when no documenters are rateable', () {
    final completion = RequestorFeedbackCompletion(
      eventFeedbackRequestIds: {21},
      teamRequiredRequestIds: const {},
      teamCompleteRequestIds: const {},
    );
    final request = ServiceRequest(
      id: '21',
      requestId: 21,
      eventName: 'Faculty Meeting',
      eventDate: DateTime(2026, 10, 23),
      requesterName: 'Lin Ti',
      status: 'Completed',
    );

    expect(completion.fullyDone(request), isTrue);
    expect(completion.pending(request), isFalse);
    expect(completion.statusLabel(21), 'Complete');
  });

  test('missing event coverage keeps request pending', () {
    final completion = RequestorFeedbackCompletion(
      eventFeedbackRequestIds: const {},
      teamRequiredRequestIds: {21},
      teamCompleteRequestIds: const {},
    );
    final request = ServiceRequest(
      id: '21',
      requestId: 21,
      eventName: 'Faculty Meeting',
      eventDate: DateTime(2026, 10, 23),
      requesterName: 'Lin Ti',
      status: 'Completed',
    );

    expect(completion.fullyDone(request), isFalse);
    expect(completion.pending(request), isTrue);
    expect(completion.statusLabel(21), 'Coverage + documenters due');
  });

  test('both event and documenter ratings mark complete', () {
    final completion = RequestorFeedbackCompletion(
      eventFeedbackRequestIds: {21},
      teamRequiredRequestIds: {21},
      teamCompleteRequestIds: {21},
    );
    final request = ServiceRequest(
      id: '21',
      requestId: 21,
      eventName: 'Faculty Meeting',
      eventDate: DateTime(2026, 10, 23),
      requesterName: 'Lin Ti',
      status: 'Completed',
    );

    expect(completion.fullyDone(request), isTrue);
    expect(completion.statusLabel(21), 'Complete');
  });
}
