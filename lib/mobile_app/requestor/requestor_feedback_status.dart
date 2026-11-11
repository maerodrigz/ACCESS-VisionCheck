import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/request_status.dart';

/// Tracks requestor service feedback vs per-documenter ratings separately.
///
/// Event Coverage Feedback is required. Documenter ratings are required when
/// the backend reports at least one rateable assignment for the event.
class RequestorFeedbackCompletion {
  const RequestorFeedbackCompletion({
    required this.eventFeedbackRequestIds,
    required this.teamRequiredRequestIds,
    required this.teamCompleteRequestIds,
  });

  final Set<int> eventFeedbackRequestIds;
  /// Requests with at least one rateable documenter assignment.
  final Set<int> teamRequiredRequestIds;
  final Set<int> teamCompleteRequestIds;

  bool eventDone(int requestId) => eventFeedbackRequestIds.contains(requestId);

  bool teamAvailable(int requestId) =>
      teamRequiredRequestIds.contains(requestId);

  bool teamRequired(int requestId) => teamAvailable(requestId);

  bool teamDone(int requestId) {
    if (!teamAvailable(requestId)) return true;
    return teamCompleteRequestIds.contains(requestId);
  }

  /// Complete only when event coverage and required documenter ratings are done.
  bool fullyDone(ServiceRequest request) {
    final id = request.requestId;
    if (id == null) return true;
    return eventDone(id) && teamDone(id);
  }

  bool pending(ServiceRequest request) {
    if (request.requestStatus != RequestStatus.completed) return false;
    return !fullyDone(request);
  }

  String statusLabel(int requestId) {
    final event = eventDone(requestId);
    final team = teamDone(requestId);
    if (event && team) return 'Complete';
    if (!event && !team && teamRequired(requestId)) {
      return 'Coverage + documenters due';
    }
    if (!event) return 'Coverage feedback due';
    if (!team) return 'Documenter ratings due';
    return 'Complete';
  }
}
