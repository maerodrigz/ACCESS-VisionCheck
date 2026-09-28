import 'package:flutter/foundation.dart';

import 'package:access_mobile/shared/models/request_status.dart';

/// Tab/deep-link hooks registered by [RequesterShell] for notification taps.
class RequestorShellNavigation {
  RequestorShellNavigation._();

  static void Function({int? requestId})? openFeedback;
  static VoidCallback? openGallery;
  static VoidCallback? openCalendar;
  static void Function({RequestStatus? filter})? openRequests;

  static void clear() {
    openFeedback = null;
    openGallery = null;
    openCalendar = null;
    openRequests = null;
  }
}
