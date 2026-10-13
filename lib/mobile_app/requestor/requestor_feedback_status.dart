import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/request_status.dart';

/// Tracks requestor service feedback vs per-member team ratings separately.
class RequestorFeedbackCompletion {
  const RequestorFeedbackCompletion({
    required this.eventFeedbackRequestIds,
    required this.teamRequiredRequestIds,
    required this.teamCompleteRequestIds,
  });

  final Set<int> eventFeedbackRequestIds;
  final Set<int> teamRequiredRequestIds;
  final Set<int> teamCompleteRequestIds;

  bool eventDone(int requestId) => eventFeedbackRequestIds.contains(requestId);

  bool teamRequired(int requestId) => teamRequiredRequestIds.contains(requestId);

  bool teamDone(int requestId) {
    if (!teamRequired(requestId)) return true;
    return teamCompleteRequestIds.contains(requestId);
  }

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
    if (!event && !team && teamRequired(requestId)) return 'Service + team due';
    if (!event) return 'Service feedback due';
    if (!team) return 'Team ratings due';
    return 'Complete';
  }
}
