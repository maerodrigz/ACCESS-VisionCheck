/// Documentation coverage availability for rescheduling.
enum CoverageLevel {
  available,
  limited,
  unavailable;

  static CoverageLevel fromApi(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'limited' => CoverageLevel.limited,
      'unavailable' => CoverageLevel.unavailable,
      _ => CoverageLevel.available,
    };
  }

  String get label => switch (this) {
        CoverageLevel.available => 'Available',
        CoverageLevel.limited => 'Limited',
        CoverageLevel.unavailable => 'Unavailable',
      };
}

class CoverageDay {
  const CoverageDay({
    required this.date,
    required this.level,
    required this.bookings,
    required this.selectable,
  });

  final DateTime date;
  final CoverageLevel level;
  final int bookings;
  final bool selectable;

  factory CoverageDay.fromApi(Map<String, dynamic> json) {
    final raw = json['date'] as String? ?? '';
    return CoverageDay(
      date: DateTime.parse(raw.length >= 10 ? raw.substring(0, 10) : raw),
      level: CoverageLevel.fromApi(json['level'] as String?),
      bookings: json['bookings'] as int? ?? 0,
      selectable: json['selectable'] as bool? ?? false,
    );
  }
}

class CoverageTimeSlot {
  const CoverageTimeSlot({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.level,
    required this.selectable,
  });

  final String id;
  final String label;
  final String startTime;
  final String endTime;
  final CoverageLevel level;
  final bool selectable;

  factory CoverageTimeSlot.fromApi(Map<String, dynamic> json) {
    return CoverageTimeSlot(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      level: CoverageLevel.fromApi(json['level'] as String?),
      selectable: json['selectable'] as bool? ?? false,
    );
  }
}

class RescheduleHistoryEntry {
  const RescheduleHistoryEntry({
    required this.rescheduledAt,
    required this.fromEventDate,
    required this.toEventDate,
    this.fromStartTime,
    this.fromEndTime,
    this.toStartTime,
    this.toEndTime,
    this.previousStatus,
    this.rejectionReason,
  });

  final DateTime? rescheduledAt;
  final DateTime? fromEventDate;
  final DateTime? toEventDate;
  final String? fromStartTime;
  final String? fromEndTime;
  final String? toStartTime;
  final String? toEndTime;
  final String? previousStatus;
  final String? rejectionReason;

  factory RescheduleHistoryEntry.fromApi(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) {
      if (raw == null || raw.length < 10) return null;
      return DateTime.tryParse(raw.substring(0, 10));
    }

    DateTime? parseTs(String? raw) => raw != null ? DateTime.tryParse(raw) : null;

    return RescheduleHistoryEntry(
      rescheduledAt: parseTs(json['rescheduled_at'] as String?),
      fromEventDate: parseDate(json['from_event_date'] as String?),
      toEventDate: parseDate(json['to_event_date'] as String?),
      fromStartTime: json['from_start_time'] as String?,
      fromEndTime: json['from_end_time'] as String?,
      toStartTime: json['to_start_time'] as String?,
      toEndTime: json['to_end_time'] as String?,
      previousStatus: json['previous_status'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}
