// Parse and compare requestor event times (e.g. "9:00 AM") for schedule checks.

int? parseRequestTimeMinutes(String raw) {
  final text = raw.trim().toUpperCase();
  if (text.isEmpty) return null;

  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$').firstMatch(text);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  final meridiem = match.group(4);
  if (hour == null || minute == null) return null;

  if (meridiem != null) {
    if (meridiem == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }
  }

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

({int start, int end})? requestTimeRangeMinutes(String startRaw, String endRaw) {
  final start = parseRequestTimeMinutes(startRaw);
  final end = parseRequestTimeMinutes(endRaw);
  if (start == null || end == null) return null;
  if (end <= start) return null;
  return (start: start, end: end);
}

bool timeRangesOverlapMinutes(int startA, int endA, int startB, int endB) {
  return startA < endB && startB < endA;
}

String? validateRequestTimeFields({
  required String startTime,
  required String endTime,
}) {
  final start = parseRequestTimeMinutes(startTime);
  final end = parseRequestTimeMinutes(endTime);
  if (start == null) return 'Enter a valid start time (example: 9:00 AM).';
  if (end == null) return 'Enter a valid end time (example: 5:00 PM).';
  if (end <= start) return 'End time must be after start time.';
  return null;
}

String? campusTimeConflictMessage({
  required DateTime eventDate,
  required String startTime,
  required String endTime,
  required Iterable<({DateTime day, DateTime? start, DateTime? end, String title})> campusEvents,
}) {
  final range = requestTimeRangeMinutes(startTime, endTime);
  if (range == null) return null;

  for (final event in campusEvents) {
    if (event.day.year != eventDate.year ||
        event.day.month != eventDate.month ||
        event.day.day != eventDate.day) {
      continue;
    }
    if (event.start == null) continue;

    final eventStart = event.start!.hour * 60 + event.start!.minute;
    final eventEnd = event.end != null
        ? event.end!.hour * 60 + event.end!.minute
        : eventStart + 60;
    if (eventEnd <= eventStart) continue;

    if (timeRangesOverlapMinutes(range.start, range.end, eventStart, eventEnd)) {
      final label = event.start!.hour == 0 && event.start!.minute == 0
          ? event.title
          : '${event.title} (${_formatMinutes(eventStart)} to ${_formatMinutes(eventEnd)})';
      return 'This time overlaps with a campus event ($label). '
          'Same date is fine, but pick a different time slot.';
    }
  }
  return null;
}

String _formatMinutes(int minutes) {
  final hour24 = minutes ~/ 60;
  final minute = minutes % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}
