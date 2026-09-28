import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum EventStatus {
  upcoming,
  ongoing,
  completed,
  cancelled,
  pendingDocumentation,
  assigned,
}

EventStatus eventStatusFromString(String? raw) {
  if (raw == null || raw.isEmpty) return EventStatus.upcoming;
  final n = raw.toLowerCase().replaceAll(' ', '_');
  return switch (n) {
    'ongoing' => EventStatus.ongoing,
    'completed' => EventStatus.completed,
    'cancelled' || 'canceled' => EventStatus.cancelled,
    'pending_documentation' || 'pending documentation' => EventStatus.pendingDocumentation,
    'assigned' => EventStatus.assigned,
    _ => EventStatus.upcoming,
  };
}

String eventStatusToApi(EventStatus s) => switch (s) {
      EventStatus.upcoming => 'upcoming',
      EventStatus.ongoing => 'ongoing',
      EventStatus.completed => 'completed',
      EventStatus.cancelled => 'cancelled',
      EventStatus.pendingDocumentation => 'pending_documentation',
      EventStatus.assigned => 'assigned',
    };

String eventStatusLabel(EventStatus s) => switch (s) {
      EventStatus.upcoming => 'Upcoming',
      EventStatus.ongoing => 'Ongoing',
      EventStatus.completed => 'Completed',
      EventStatus.cancelled => 'Cancelled',
      EventStatus.pendingDocumentation => 'Pending Documentation',
      EventStatus.assigned => 'Assigned',
    };

Color eventStatusColor(EventStatus s) => switch (s) {
      EventStatus.upcoming => AdminTheme.accentBlue,
      EventStatus.ongoing => AdminTheme.accentCyan,
      EventStatus.completed => AdminTheme.success,
      EventStatus.cancelled => AdminTheme.textSecondary,
      EventStatus.pendingDocumentation => AdminTheme.warning,
      EventStatus.assigned => const Color(0xFF7C3AED),
    };

class CalendarEventItem {
  CalendarEventItem({
    required this.id,
    required this.title,
    required this.eventDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.description,
    this.status = EventStatus.upcoming,
    this.assignedMemberId,
    this.assignedMemberName,
    this.documentationRequestId,
    this.requestStatus,
    this.adminRemarks,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final DateTime eventDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? location;
  final String? description;
  final EventStatus status;
  final int? assignedMemberId;
  final String? assignedMemberName;
  final int? documentationRequestId;
  final String? requestStatus;
  final String? adminRemarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get timeLabel {
    if (startTime == null && endTime == null) return 'All day';
    final start = startTime != null ? _formatTime(startTime!) : '';
    final end = endTime != null ? _formatTime(endTime!) : '';
    if (start.isNotEmpty && end.isNotEmpty) return '$start – $end';
    return start.isNotEmpty ? start : end;
  }

  String get dateLabel =>
      '${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Human-readable date for UI, e.g. "Jul 25, 2026".
  String get displayDateLabel =>
      '${_months[eventDate.month - 1]} ${eventDate.day}, ${eventDate.year}';

  /// Short date for compact tiles, e.g. "Jul 25".
  String get shortDateLabel => '${_months[eventDate.month - 1]} ${eventDate.day}';

  String get weekdayLabel => _weekdays[eventDate.weekday - 1];

  String get displayDateTimeLabel => '$displayDateLabel · $timeLabel';

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final end = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day)
        : start;
    return !d.isBefore(start) && !d.isAfter(end);
  }

  factory CalendarEventItem.fromMap(Map<String, dynamic> m) {
    final dateStr = m['event_date'] as String? ?? m['start_date'] as String? ?? '';
    final endStr = m['end_date'] as String?;
    return CalendarEventItem(
      id: m['id'] as int? ?? 0,
      title: m['title'] as String? ?? 'Untitled event',
      eventDate: DateTime.tryParse(dateStr) ?? DateTime.now(),
      endDate: endStr != null ? DateTime.tryParse(endStr) : null,
      startTime: _parseTime(m['start_time'] as String?),
      endTime: _parseTime(m['end_time'] as String?),
      location: m['location'] as String? ?? m['venue'] as String?,
      description: m['description'] as String?,
      status: eventStatusFromString(m['status'] as String?),
      assignedMemberId: m['assigned_member_id'] as int?,
      assignedMemberName: m['assigned_member_name'] as String?,
      documentationRequestId:
          m['documentation_request_id'] as int? ?? m['request_id'] as int?,
      requestStatus: m['request_status'] as String?,
      adminRemarks: m['admin_remarks'] as String?,
      createdAt: DateTime.tryParse(m['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toApiBody() => {
        'title': title,
        if (description != null) 'description': description,
        'event_date': dateLabel,
        if (endDate != null)
          'end_date':
              '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
        if (startTime != null) 'start_time': _timeToApi(startTime!),
        if (endTime != null) 'end_time': _timeToApi(endTime!),
        if (location != null) 'location': location,
        'status': eventStatusToApi(status),
        if (assignedMemberId != null) 'assigned_member_id': assignedMemberId,
        if (documentationRequestId != null) 'documentation_request_id': documentationRequestId,
        if (adminRemarks != null) 'admin_remarks': adminRemarks,
      };

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final min = int.tryParse(parts[1]);
    if (h == null || min == null) return null;
    return TimeOfDay(hour: h, minute: min);
  }

  static String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  static String _timeToApi(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
