import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/event_calendar/event_calendar_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class UpcomingEventList extends StatelessWidget {
  const UpcomingEventList({
    super.key,
    required this.events,
    required this.onEventTap,
    this.title = 'Upcoming events',
  });

  final List<CalendarEventItem> events;
  final ValueChanged<CalendarEventItem> onEventTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(events);

    return Container(
      decoration: AdminTheme.cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available_outlined, size: 18, color: AdminTheme.accentBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      '${events.length} scheduled',
                      style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No upcoming events in this view.',
                  style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ...grouped.entries.take(6).map(
                  (entry) => _DateEventGroup(
                    date: entry.key,
                    events: entry.value,
                    onEventTap: onEventTap,
                  ),
                ),
        ],
      ),
    );
  }

  Map<DateTime, List<CalendarEventItem>> _groupByDate(List<CalendarEventItem> items) {
    final map = <DateTime, List<CalendarEventItem>>{};
    for (final e in items) {
      final key = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()..sort();
    return {for (final k in keys) k: map[k]!};
  }
}

class _DateEventGroup extends StatelessWidget {
  const _DateEventGroup({
    required this.date,
    required this.events,
    required this.onEventTap,
  });

  final DateTime date;
  final List<CalendarEventItem> events;
  final ValueChanged<CalendarEventItem> onEventTap;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdminTheme.accentBlue.withValues(alpha: 0.1),
                  border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AdminTheme.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weekday, $month ${date.day}, ${date.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminTheme.textPrimary),
                  ),
                  Text(
                    '${events.length} event${events.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...events.map(
            (e) => Padding(
              padding: const EdgeInsets.only(left: 46, bottom: 6),
              child: _EventTitleLink(event: e, onTap: () => onEventTap(e)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTitleLink extends StatefulWidget {
  const _EventTitleLink({required this.event, required this.onTap});

  final CalendarEventItem event;
  final VoidCallback onTap;

  @override
  State<_EventTitleLink> createState() => _EventTitleLinkState();
}

class _EventTitleLinkState extends State<_EventTitleLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = eventStatusColor(widget.event.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.06) : AdminTheme.contentBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.35) : AdminTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.event.timeLabel,
                      style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: _hovered ? color : AdminTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
