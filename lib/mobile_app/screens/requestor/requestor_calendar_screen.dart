import 'dart:async';

import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Campus event calendar for requestors — plan documentation dates around
/// what is already scheduled on campus. Your own requests live on Requests tab.
class RequestorCalendarScreen extends StatefulWidget {
  const RequestorCalendarScreen({
    super.key,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onPlanRequest,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  /// Opens the create-request form with the selected day pre-filled.
  final void Function(DateTime day)? onPlanRequest;

  @override
  State<RequestorCalendarScreen> createState() => _RequestorCalendarScreenState();
}

class _RequestorCalendarScreenState extends State<RequestorCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(memberDataController.ensureCalendarTab());
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> all, DateTime day) =>
      all.where((e) => _sameDay(e.startDate, day)).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

  List<CalendarEvent> _upcomingCampusEvents(List<CalendarEvent> all) {
    final today = _dayOnly(DateTime.now());
    return all
        .where((e) => e.isUpcoming && !_dayOnly(e.startDate).isBefore(today))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  bool _canPlanRequest(DateTime day) {
    final today = _dayOnly(DateTime.now());
    return !_dayOnly(day).isBefore(today);
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  void _prevMonth() => setState(
        () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
      );

  void _nextMonth() => setState(
        () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
      );

  String _formatSelectedDate(DateTime day) {
    return '${_monthNames[day.month - 1]} ${day.day}, ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = (firstDay.weekday + 6) % 7;
    final rows = ((startWeekday + daysInMonth) / 7).ceil();

    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestorTabHero(
            title: 'Campus calendar',
            subtitle:
                'See what is already scheduled so you can pick a good day for documentation.',
            onNotifications: widget.onNotificationsTap,
            onProfileTap: widget.onProfileTap,
            mini: true,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (context, _) {
                final campusEvents = appState.events;
                final loading = memberDataController.calendarTabLoading &&
                    campusEvents.isEmpty;
                final dayEvents = _eventsForDay(campusEvents, _selectedDay);
                final upcoming = _upcomingCampusEvents(campusEvents);
                final nextUp = upcoming.isEmpty ? null : upcoming.first;
                final canPlan = _canPlanRequest(_selectedDay);

                if (loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5),
                  );
                }

                return RefreshIndicator(
                  color: kAccent,
                  onRefresh: memberDataController.refreshCalendarTab,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      kMemberDashboardPagePadding,
                      12,
                      kMemberDashboardPagePadding,
                      56,
                    ),
                    children: [
                      if (nextUp != null) ...[
                        _NextCampusEventBanner(
                          event: nextUp,
                          onTap: () => showRequestorCampusEventDetail(context, nextUp),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
                          border: Border.all(color: kBorder),
                          boxShadow: [
                            BoxShadow(
                              color: kAccent.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _MonthNavButton(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: _prevMonth,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        _monthNames[_focusedMonth.month - 1],
                                        style: memberDashboardSectionTitleStyle.copyWith(
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        '${_focusedMonth.year}',
                                        style: memberDashboardMetaStyle.copyWith(
                                          color: kAccent,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _TodayPill(onTap: _goToToday),
                                const SizedBox(width: 4),
                                _MonthNavButton(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: _nextMonth,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: _weekdays
                                  .map(
                                    (d) => Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: memberDashboardMetaStyle.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 6),
                            ...List.generate(rows, (row) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: List.generate(7, (col) {
                                    final dayNum = row * 7 + col - startWeekday + 1;
                                    if (dayNum < 1 || dayNum > daysInMonth) {
                                      return const Expanded(child: SizedBox(height: 38));
                                    }
                                    final date = DateTime(
                                      _focusedMonth.year,
                                      _focusedMonth.month,
                                      dayNum,
                                    );
                                    final count = _eventsForDay(campusEvents, date).length;
                                    return Expanded(
                                      child: _CalendarDayCell(
                                        day: dayNum,
                                        isSelected: _sameDay(_selectedDay, date),
                                        isToday: _sameDay(today, date),
                                        hasEvent: count > 0,
                                        onTap: () => setState(() => _selectedDay = date),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: kCyan,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Campus event scheduled',
                                  style: memberDashboardMetaStyle.copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 18, color: kAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatSelectedDate(_selectedDay),
                                  style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
                                ),
                                Text(
                                  dayEvents.isEmpty
                                      ? (canPlan
                                          ? 'No campus events — open for planning'
                                          : 'No campus events on this day')
                                      : '${dayEvents.length} campus event${dayEvents.length == 1 ? '' : 's'}',
                                  style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (dayEvents.isEmpty)
                        MemberDashboardCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Icon(
                                canPlan ? Icons.event_available_rounded : Icons.event_busy_rounded,
                                size: 32,
                                color: canPlan ? kAccent : kIconInactive,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                canPlan
                                    ? 'Nothing else scheduled'
                                    : 'Past date',
                                style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                canPlan
                                    ? 'This day has no campus events yet. Good time to plan your documentation request.'
                                    : 'Pick a future date to plan a documentation request.',
                                style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ...dayEvents.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CalendarCampusEventTile(
                              event: event,
                              onTap: () => showRequestorCampusEventDetail(context, event),
                            ),
                          ),
                        ),
                      if (canPlan && widget.onPlanRequest != null) ...[
                        const SizedBox(height: 14),
                        MemberDashboardPrimaryButton(
                          label: 'Plan request for this date',
                          icon: Icons.add_rounded,
                          onPressed: () => widget.onPlanRequest!(_selectedDay),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NextCampusEventBanner extends StatelessWidget {
  const _NextCampusEventBanner({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: kMemberDarkHeroGradient,
            borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.event_rounded, color: kCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next on campus',
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      )),
                    ),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                    Text(
                      event.date,
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      )),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarCampusEventTile extends StatelessWidget {
  const _CalendarCampusEventTile({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.event_rounded, color: kCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.timeLabel != null && event.timeLabel!.isNotEmpty
                        ? '${event.date} · ${event.timeLabel}'
                        : event.date,
                    style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                  ),
                  if (event.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.location,
                      style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kAccent.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: kTextPrimary),
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kAccent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            'Today',
            style: TextStyle(
              color: kAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.hasEvent,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color textColor = kTextPrimary;
    FontWeight weight = FontWeight.w500;

    if (isSelected) {
      bg = kAccent;
      textColor = Colors.white;
      weight = FontWeight.w700;
    } else if (isToday) {
      bg = kAccent.withValues(alpha: 0.12);
      textColor = kAccent;
      weight = FontWeight.w700;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 38,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: weight,
                  ),
                ),
              ),
              if (hasEvent)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : kCyan,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 7),
            ],
          ),
        ),
      ),
    );
  }
}
