import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Normalized documentation request status for the Requestor UI.
enum RequestStatus {
  pending,
  approved,
  rejected,
  completed;

  String get label => switch (this) {
        RequestStatus.pending => 'Pending',
        RequestStatus.approved => 'Approved',
        RequestStatus.rejected => 'Rejected',
        RequestStatus.completed => 'Completed',
      };

  String get description => switch (this) {
        RequestStatus.pending => 'Waiting for administrator review.',
        RequestStatus.approved => 'Approved for documentation coverage.',
        RequestStatus.rejected => 'This request was not approved.',
        RequestStatus.completed => 'Event documentation has been completed.',
      };

  static RequestStatus fromApi(String? raw) {
    final s = (raw ?? 'pending').trim().toLowerCase().replaceAll(' ', '_');
    return switch (s) {
      'approved' => RequestStatus.approved,
      'rejected' => RequestStatus.rejected,
      'completed' => RequestStatus.completed,
      // Legacy / backend aliases collapse to Pending.
      'under_review' || 'in_review' => RequestStatus.pending,
      _ => RequestStatus.pending,
    };
  }

  static RequestStatus fromLegacyLabel(String label) {
    return switch (label) {
      'Approved' => RequestStatus.approved,
      'Rejected' => RequestStatus.rejected,
      'Completed' => RequestStatus.completed,
      'Under Review' || 'In Review' => RequestStatus.pending,
      _ => RequestStatus.pending,
    };
  }
}

class RequestStatusStyle {
  const RequestStatusStyle({
    required this.color,
    required this.background,
    required this.icon,
  });

  final Color color;
  final Color background;
  final IconData icon;

  static RequestStatusStyle forStatus(RequestStatus status) {
    return switch (status) {
      RequestStatus.pending => const RequestStatusStyle(
          color: kYellow,
          background: kYellowDim,
          icon: Icons.schedule_rounded,
        ),
      RequestStatus.approved => const RequestStatusStyle(
          color: kGreen,
          background: kGreenDim,
          icon: Icons.check_circle_rounded,
        ),
      RequestStatus.rejected => const RequestStatusStyle(
          color: kRed,
          background: kRedDim,
          icon: Icons.cancel_rounded,
        ),
      RequestStatus.completed => const RequestStatusStyle(
          color: kCyan,
          background: kCyanDim,
          icon: Icons.task_alt_rounded,
        ),
    };
  }
}

const requestStatusFilters = [
  (null, 'All'),
  (RequestStatus.pending, 'Pending'),
  (RequestStatus.approved, 'Approved'),
  (RequestStatus.completed, 'Completed'),
  (RequestStatus.rejected, 'Rejected'),
];

Color requestFilterTint(RequestStatus? status) {
  return switch (status) {
    RequestStatus.pending => kYellowDim,
    RequestStatus.approved => kGreenDim,
    RequestStatus.completed => kCyanDim,
    RequestStatus.rejected => kRedDim,
    null => kSurfaceAlt,
  };
}

Color requestFilterAccent(RequestStatus? status) {
  return switch (status) {
    RequestStatus.pending => kYellow,
    RequestStatus.approved => kGreen,
    RequestStatus.completed => kCyan,
    RequestStatus.rejected => kRed,
    null => kAccent,
  };
}

String emptyStateTitle(RequestStatus? filter, {required bool hasAnyRequests}) {
  if (filter == null && !hasAnyRequests) return 'No requests yet';
  return switch (filter) {
    RequestStatus.pending => 'No pending requests',
    RequestStatus.approved => 'No approved requests',
    RequestStatus.completed => 'No completed requests',
    RequestStatus.rejected => 'No rejected requests',
    null => 'No requests found',
  };
}

String emptyStateSubtitle(RequestStatus? filter, {required bool hasAnyRequests}) {
  if (filter == null && !hasAnyRequests) {
    return 'Your documentation requests will appear here.';
  }
  return switch (filter) {
    RequestStatus.pending => "You don't have any requests awaiting review.",
    RequestStatus.approved => 'Approved documentation requests will show here.',
    RequestStatus.completed => 'Completed event documentation will appear here.',
    RequestStatus.rejected => 'Rejected requests will be listed here if any.',
    null => 'Try a different filter to see your requests.',
  };
}

String formatRequestDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatRequestShortDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
