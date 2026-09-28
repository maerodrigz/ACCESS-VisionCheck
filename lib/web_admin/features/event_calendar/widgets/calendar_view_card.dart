import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:access_mobile/web_admin/features/event_calendar/event_calendar_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum CalendarViewMode { month, week, day }

class CalendarViewCard extends StatelessWidget {
  const CalendarViewCard({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.viewMode,
    required this.events,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onViewModeChanged,
    required this.onToday,
    required this.onEventTap,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarViewMode viewMode;
  final List<CalendarEventItem> events;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final VoidCallback onToday;
  final ValueChanged<CalendarEventItem> onEventTap;

  CalendarFormat get _format => switch (viewMode) {
        CalendarViewMode.month => CalendarFormat.month,
        CalendarViewMode.week => CalendarFormat.week,
        CalendarViewMode.day => CalendarFormat.week,
      };

  List<CalendarEventItem> _forDay(DateTime day) =>
      events.where((e) => e.occursOn(day)).toList()..sort((a, b) => a.eventDate.compareTo(b.eventDate));

  @override
  Widget build(BuildContext context) {
    final isMonth = viewMode == CalendarViewMode.month;

    return Container(
      decoration: AdminTheme.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Calendar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              SegmentedButton<CalendarViewMode>(
                segments: const [
                  ButtonSegment(value: CalendarViewMode.month, label: Text('Month')),
                  ButtonSegment(value: CalendarViewMode.week, label: Text('Week')),
                  ButtonSegment(value: CalendarViewMode.day, label: Text('Day')),
                ],
                selected: {viewMode},
                onSelectionChanged: (s) => onViewModeChanged(s.first),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onToday, child: const Text('Today')),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar<CalendarEventItem>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            calendarFormat: _format,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: _forDay,
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            rowHeight: isMonth ? 108 : 72,
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(2),
              markersMaxCount: 0,
              outsideDaysVisible: false,
              defaultDecoration: const BoxDecoration(),
              todayDecoration: const BoxDecoration(),
              selectedDecoration: const BoxDecoration(),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) => _CalendarDayCell(
                day: day,
                events: _forDay(day),
                isToday: false,
                isSelected: false,
                onEventTap: onEventTap,
              ),
              todayBuilder: (context, day, _) => _CalendarDayCell(
                day: day,
                events: _forDay(day),
                isToday: true,
                isSelected: isSameDay(day, selectedDay),
                onEventTap: onEventTap,
              ),
              selectedBuilder: (context, day, _) => _CalendarDayCell(
                day: day,
                events: _forDay(day),
                isToday: isSameDay(day, DateTime.now()),
                isSelected: true,
                onEventTap: onEventTap,
              ),
              outsideBuilder: (context, day, _) => _CalendarDayCell(
                day: day,
                events: const [],
                isToday: false,
                isSelected: false,
                muted: true,
                onEventTap: onEventTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.onEventTap,
    this.muted = false,
  });

  final DateTime day;
  final List<CalendarEventItem> events;
  final bool isToday;
  final bool isSelected;
  final bool muted;
  final ValueChanged<CalendarEventItem> onEventTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = isSelected
        ? AdminTheme.accentBlue
        : isToday
            ? AdminTheme.accentCyan
            : null;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: ringColor != null
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: ringColor.withValues(alpha: 0.1),
                      border: Border.all(color: ringColor, width: 1.5),
                    )
                  : null,
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted
                      ? AdminTheme.textSecondary.withValues(alpha: 0.4)
                      : ringColor ?? AdminTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: events.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...events.take(2).map(
                            (e) => _CalendarEventTitle(
                              event: e,
                              onTap: () => onEventTap(e),
                            ),
                          ),
                      if (events.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            '+${events.length - 2} more',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventTitle extends StatefulWidget {
  const _CalendarEventTitle({required this.event, required this.onTap});

  final CalendarEventItem event;
  final VoidCallback onTap;

  @override
  State<_CalendarEventTitle> createState() => _CalendarEventTitleState();
}

class _CalendarEventTitleState extends State<_CalendarEventTitle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = eventStatusColor(widget.event.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            widget.event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
