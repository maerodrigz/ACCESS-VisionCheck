import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_calendar_event_card.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/shared/models/request_status.dart';

const _requestorAgendaStrip = Color(0xFFE8F6FB);
const _requestorCalendarHeaderAsset =
    'assets/images/requestor_calendar_header.png';
/// Cropped banner aspect (2084×523).
const _requestorCalendarHeaderAspect = 2084 / 523;
const _requestorCalendarHeaderUnderpaint = Color(0xFFC9E8F8);
const _requestorCalendarHeaderRadius = 22.0;

class CalendarScreen extends StatefulWidget {
  /// When omitted, uses the default member- or requestor-facing copy.
  final String? subtitle;

  /// Requestor shell: same calendar UI with request filters and plan-request action.
  final bool forRequestor;

  /// Switches the member shell to the Gallery tab (index 3).
  final VoidCallback? onViewGallery;

  /// Opens the member assignments list.
  final VoidCallback? onViewAssignments;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  /// Requestor: open create-request form with the selected day pre-filled.
  final void Function(DateTime day)? onPlanRequest;

  const CalendarScreen({
    super.key,
    this.subtitle,
    this.forRequestor = false,
    this.onViewGallery,
    this.onViewAssignments,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onPlanRequest,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  String _searchQuery = '';
  bool _searchExpanded = false;
  bool _showAllUpcoming = false;
  bool _myAssignmentsOnly = true;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _upcomingPreviewLimit = 5;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.microtask(() {
        if (!mounted) return;
        if (appState.events.isEmpty && appState.myCalendarEvents.isEmpty) {
          unawaited(memberDataController.ensureCalendarTab());
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _hasActiveSearch => _searchQuery.trim().isNotEmpty;

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (_searchExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocusNode.requestFocus();
        });
      } else {
        _searchFocusNode.unfocus();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _matchesSearch(CalendarEvent e) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return e.title.toLowerCase().contains(q) ||
        e.location.toLowerCase().contains(q) ||
        e.tag.toLowerCase().contains(q);
  }

  List<CalendarEvent> get _visibleEvents {
    final list = _myAssignmentsOnly ? appState.myCalendarEvents : appState.events;
    return list.where(_matchesSearch).toList();
  }

  List<CalendarEvent> _eventsForDay(DateTime day) => _visibleEvents
      .where((e) => _sameDay(e.startDate, day))
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  List<CalendarEvent> get _upcomingEvents {
    final today = _dayOnly(DateTime.now());
    return _visibleEvents
        .where((e) => e.isUpcoming && !_dayOnly(e.startDate).isBefore(today))
        .where((e) => !_sameDay(e.startDate, _selectedDay))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }


  bool _canPlanRequestOnDay(DateTime day) {
    final today = _dayOnly(DateTime.now());
    return !_dayOnly(day).isBefore(today);
  }

  bool _isMyRequest(CalendarEvent event) {
    return appState.myCalendarEvents.any(
      (e) =>
          (event.id != null && e.id == event.id) ||
          (event.requestId != null && e.requestId == event.requestId),
    );
  }

  _RequestorChipPalette _requestorChipPalette(CalendarEvent event) {
    final raw = (event.requestStatus ?? event.status).trim().toLowerCase();
    if (raw.isNotEmpty) {
      if (raw.contains('approv')) {
        return const _RequestorChipPalette(
          accent: kGreen,
          fill: kGreenDim,
          icon: Icons.check_circle_outline_rounded,
        );
      }
      if (raw.contains('pending') || raw.contains('review')) {
        return const _RequestorChipPalette(
          accent: kYellow,
          fill: kYellowDim,
          icon: Icons.schedule_rounded,
        );
      }
      if (raw.contains('reject') || raw.contains('declin')) {
        return const _RequestorChipPalette(
          accent: kRed,
          fill: kRedDim,
          icon: Icons.cancel_outlined,
        );
      }
      if (raw.contains('complete') || raw.contains('past')) {
        return const _RequestorChipPalette(
          accent: kCyan,
          fill: kCyanDim,
          icon: Icons.task_alt_rounded,
        );
      }
    }
    if (_isMyRequest(event) || event.requestId != null) {
      return const _RequestorChipPalette(
        accent: kAccent,
        fill: Color(0xFFEAF3FF),
        icon: Icons.photo_camera_outlined,
      );
    }
    return const _RequestorChipPalette(
      accent: kCyan,
      fill: kCyanDim,
      icon: Icons.event_note_rounded,
    );
  }

  String _requestorShortTitle(String title) {
    final cleaned = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'Event';
    // Prefer the full short title when it already fits a date cell.
    if (cleaned.length <= 10) return cleaned;
    final words = cleaned.split(' ');
    for (final word in words.skip(1)) {
      if (word.length >= 4 && word.length <= 10) return word;
    }
    final first = words.first;
    if (first.length <= 10) return first;
    if (first.contains('-')) {
      final part = first.split('-').last;
      if (part.length >= 4 && part.length <= 10) return part;
    }
    return '${first.substring(0, 9)}…';
  }

  String _requestorScheduleLabel(CalendarEvent event) {
    final start = (event.timeLabel ?? '').trim();
    final startShown = start.isEmpty ? 'Time TBA' : start;
    final end = event.endDate;
    if (end == null) return startShown;
    final endLabel = _formatRequestorClock(end);
    if (endLabel == 'Time TBA' || endLabel == startShown) return startShown;
    if (startShown == 'Time TBA') return endLabel;
    return '$startShown – $endLabel';
  }

  String _formatRequestorClock(DateTime dt) {
    if (dt.hour == 0 && dt.minute == 0) return 'Time TBA';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String _requestorStatusLabel(CalendarEvent event) {
    final raw = (event.requestStatus ?? '').trim();
    if (raw.isNotEmpty) {
      return RequestStatus.fromApi(raw).label;
    }
    final status = event.status.trim();
    return status.isEmpty ? 'Scheduled' : status;
  }

  Color _requestorStatusColor(CalendarEvent event) {
    final raw = (event.requestStatus ?? '').trim();
    if (raw.isNotEmpty) {
      return RequestStatusStyle.forStatus(RequestStatus.fromApi(raw)).color;
    }
    return event.statusColor;
  }

  Color _requestorStatusBackground(CalendarEvent event) {
    final raw = (event.requestStatus ?? '').trim();
    if (raw.isNotEmpty) {
      return RequestStatusStyle.forStatus(RequestStatus.fromApi(raw)).background;
    }
    return event.statusColor.withValues(alpha: 0.12);
  }

  void _openEventDetail(BuildContext context, CalendarEvent event) {
    final isPrimaryScope = appState.myCalendarEvents.any(
      (e) => e.id == event.id || (e.requestId != null && e.requestId == event.requestId),
    );
    if (widget.forRequestor) {
      if (_myAssignmentsOnly || isPrimaryScope) {
        showMemberEventDetail(context, event);
      } else {
        showRequestorCampusEventDetail(context, event);
      }
    } else {
      // Members: campus "All Events" uses read-only member detail (no requestor planning copy).
      showMemberEventDetail(
        context,
        event,
        onViewGallery: widget.onViewGallery,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final padding = mobilePagePaddingOf(context);
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = (firstDay.weekday + 6) % 7;
    final rowCount = ((startWeekday + daysInMonth) / 7).ceil();
    final primaryAction = kMemberButtonPrimary;

    // Shared Requestor calendar chrome for both roles; actions stay role-gated.
    final primaryTabLabel =
        widget.forRequestor ? 'My Requests' : 'My Assignments';
    final secondaryTabLabel = 'All Events';
    final primaryTabIcon = widget.forRequestor
        ? Icons.description_outlined
        : Icons.assignment_ind_outlined;
    final headerSubtitle = widget.subtitle ??
        (widget.forRequestor
            ? 'Campus events and your documentation schedule.'
            : 'Your assignments and campus documentation schedule.');

    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestorBrandAppBar(
            onNotifications: widget.onNotificationsTap,
            onProfileTap: widget.onProfileTap,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (_, __) {
                final syncing = memberDataController.calendarTabLoading &&
                    appState.events.isEmpty &&
                    appState.myCalendarEvents.isEmpty;
                final loadError = memberDataController.calendarTabError;
                if (syncing) {
                  return const MobileLoadingView(message: 'Loading calendar…');
                }
                if (loadError != null &&
                    appState.events.isEmpty &&
                    appState.myCalendarEvents.isEmpty) {
                  return RefreshIndicator(
                    color: primaryAction,
                    onRefresh: memberDataController.refreshCalendarTab,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        _RequestorCalendarIllustratedHeader(
                          subtitle: headerSubtitle,
                        ),
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                        MobileEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Unable to load calendar',
                          subtitle: loadError,
                          actionLabel: 'Retry',
                          onAction: memberDataController.refreshCalendarTab,
                        ),
                      ],
                    ),
                  );
                }

                final dayEvents = _eventsForDay(_selectedDay);
                final upcoming = _upcomingEvents;
                final upcomingVisible = _showAllUpcoming
                    ? upcoming
                    : upcoming.take(_upcomingPreviewLimit).toList();

                return RefreshIndicator(
                  color: primaryAction,
                  onRefresh: () => memberDataController.refreshCalendarTab(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _RequestorCalendarIllustratedHeader(
                          subtitle: headerSubtitle,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _CalendarFilterTabs(
                          myAssignmentsOnly: _myAssignmentsOnly,
                          onChanged: (value) =>
                              setState(() => _myAssignmentsOnly = value),
                          onSearchTap: _toggleSearch,
                          searchActive: _hasActiveSearch || _searchExpanded,
                          primaryTabLabel: primaryTabLabel,
                          secondaryTabLabel: secondaryTabLabel,
                          accentColor: primaryAction,
                          forRequestor: true,
                          primaryIcon: primaryTabIcon,
                          secondaryIcon: Icons.event_note_rounded,
                        ),
                      ),
                      if (_searchExpanded)
                        SliverToBoxAdapter(
                          child: _CalendarSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            onClear: _clearSearch,
                            showClear: _hasActiveSearch,
                            accentColor: primaryAction,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
                          child: GestureDetector(
                            onHorizontalDragEnd: (details) {
                              final v = details.primaryVelocity ?? 0;
                              if (v > 280) {
                                _prevMonth();
                              } else if (v < -280) {
                                _nextMonth();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(
                                  kMemberDashboardCardRadius,
                                ),
                                border: Border.all(color: kBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _MonthNavButton(
                                        icon: Icons.chevron_left_rounded,
                                        accentColor: primaryAction,
                                        onTap: _prevMonth,
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_month_rounded,
                                              size: 15,
                                              color: primaryAction.withValues(
                                                alpha: 0.8,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                                                style:
                                                    memberDashboardSectionTitleStyle
                                                        .copyWith(fontSize: 15),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _TodayPill(
                                        onTap: _goToToday,
                                        accentColor: primaryAction,
                                      ),
                                      const SizedBox(width: 4),
                                      _MonthNavButton(
                                        icon: Icons.chevron_right_rounded,
                                        accentColor: primaryAction,
                                        onTap: _nextMonth,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: _weekdays
                                        .map(
                                          (d) => Expanded(
                                            child: Center(
                                              child: Text(
                                                d,
                                                style: memberDashboardMetaStyle
                                                    .copyWith(
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
                                  const SizedBox(height: 2),
                                  ...List.generate(rowCount, (row) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: List.generate(7, (col) {
                                          final dayOffset =
                                              row * 7 + col - startWeekday + 1;
                                          final date = DateTime(
                                            _focusedMonth.year,
                                            _focusedMonth.month,
                                            dayOffset,
                                          );
                                          final inMonth =
                                              date.month == _focusedMonth.month;
                                          final isSelected =
                                              _sameDay(_selectedDay, date);
                                          final isToday = _sameDay(today, date);
                                          final events = _eventsForDay(date);
                                          final palette = events.isEmpty
                                              ? const _RequestorChipPalette(
                                                  accent: kBorder,
                                                  fill: kSurfaceAlt,
                                                  icon: Icons.event_rounded,
                                                )
                                              : _requestorChipPalette(
                                                  events.first,
                                                );
                                          return Expanded(
                                            child: _RequestorCalendarDayCell(
                                              day: date.day,
                                              isSelected: isSelected,
                                              isToday: isToday,
                                              inMonth: inMonth,
                                              events: events,
                                              shortTitle: events.isEmpty
                                                  ? ''
                                                  : _requestorShortTitle(
                                                      events.first.title,
                                                    ),
                                              palette: palette,
                                              onTap: () => setState(() {
                                                _selectedDay = _dayOnly(date);
                                                if (!inMonth) {
                                                  _focusedMonth = DateTime(
                                                    date.year,
                                                    date.month,
                                                  );
                                                }
                                              }),
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 6, padding, 8),
                          child: _RequestorAgendaHeader(
                            dateLabel: _formatSelectedDate(_selectedDay),
                            eventCount: dayEvents.length,
                          ),
                        ),
                      ),
                      if (dayEvents.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.fromLTRB(padding, 4, padding, 16),
                            child: _searchQuery.trim().isNotEmpty
                                ? MobileEmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'No matching events',
                                    subtitle:
                                        'Try a different search or date.',
                                  )
                                : _CalendarNoEventsEmptyState(
                                    forRequestor: widget.forRequestor,
                                    canPlan: widget.forRequestor &&
                                        _canPlanRequestOnDay(_selectedDay),
                                  ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 16),
                          sliver: SliverList.separated(
                            itemCount: dayEvents.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final event = dayEvents[i];
                              final palette = _requestorChipPalette(event);
                              return _RequestorAgendaEventCard(
                                title: event.title,
                                schedule: _requestorScheduleLabel(event),
                                location: event.location,
                                statusLabel: _requestorStatusLabel(event),
                                statusColor: _requestorStatusColor(event),
                                statusBackground:
                                    _requestorStatusBackground(event),
                                accent: palette.accent,
                                icon: palette.icon,
                                onTap: () => _openEventDetail(context, event),
                              );
                            },
                          ),
                        ),
                      if (widget.forRequestor &&
                          widget.onPlanRequest != null &&
                          _canPlanRequestOnDay(_selectedDay)) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 2, padding, 16),
                            child: SizedBox(
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    widget.onPlanRequest!(_selectedDay),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: Text(
                                  'Plan request for this date',
                                  style: dashText(const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  )),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryAction,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (!widget.forRequestor && upcoming.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 6, padding, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Upcoming Events',
                                    style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
                                  ),
                                ),
                                if (upcoming.length > _upcomingPreviewLimit)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => setState(
                                      () => _showAllUpcoming = !_showAllUpcoming,
                                    ),
                                    child: Text(
                                      _showAllUpcoming ? 'Show less' : 'See all',
                                      style: TextStyle(
                                        color: primaryAction,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                          sliver: SliverList.separated(
                            itemCount: upcomingVisible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final event = upcomingVisible[i];
                              return MemberCalendarUpcomingCard(
                                event: event,
                                forRequestor: widget.forRequestor,
                                onTap: () {
                                  setState(() {
                                    _selectedDay = _dayOnly(event.startDate);
                                    _focusedMonth = DateTime(
                                      event.startDate.year,
                                      event.startDate.month,
                                    );
                                  });
                                  _openEventDetail(context, event);
                                },
                              );
                            },
                          ),
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

  String _formatSelectedDate(DateTime d) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${weekdays[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _CalendarSearchBar extends StatelessWidget {
  const _CalendarSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
    this.accentColor = kMemberButtonPrimary,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search events by name, venue, or tag…',
          hintStyle: memberDashboardMetaStyle.copyWith(fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: accentColor.withValues(alpha: 0.75), size: 22),
          suffixIcon: showClear
              ? IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, color: kIconInactive, size: 20),
                )
              : null,
          filled: true,
          fillColor: kSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _CalendarNoEventsEmptyState extends StatelessWidget {
  const _CalendarNoEventsEmptyState({
    this.forRequestor = false,
    this.canPlan = false,
  });

  final bool forRequestor;
  final bool canPlan;

  @override
  Widget build(BuildContext context) {
    final title = forRequestor
        ? 'Nothing scheduled for this day.'
        : 'No events scheduled';
    final subtitle = forRequestor && canPlan
        ? 'Good time to plan documentation. Use the button below to create a request.'
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kMemberDashboardAccentLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kMemberCyan.withValues(alpha: 0.2)),
            ),
            child: Icon(
              forRequestor && canPlan
                  ? Icons.event_available_outlined
                  : Icons.event_busy_outlined,
              color: kMemberButtonPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: memberDashboardSectionTitleStyle.copyWith(fontSize: 14),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarFilterTabs extends StatelessWidget {
  const _CalendarFilterTabs({
    required this.myAssignmentsOnly,
    required this.onChanged,
    required this.onSearchTap,
    required this.searchActive,
    this.primaryTabLabel = 'My Assignments',
    this.secondaryTabLabel = 'All Events',
    this.accentColor = kAccent,
    this.forRequestor = false,
    this.primaryIcon,
    this.secondaryIcon,
  });

  final bool myAssignmentsOnly;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSearchTap;
  final bool searchActive;
  final String primaryTabLabel;
  final String secondaryTabLabel;
  final Color accentColor;
  final bool forRequestor;
  final IconData? primaryIcon;
  final IconData? secondaryIcon;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: forRequestor ? kSurface : kCyanDim.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(forRequestor ? 14 : 12),
                border: Border.all(
                  color: forRequestor
                      ? kBorder
                      : accentColor.withValues(alpha: 0.1),
                ),
                boxShadow: forRequestor
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(forRequestor ? 4 : 3),
                child: Row(
                  children: [
                    Expanded(
                      child: _CalendarFilterTab(
                        label: primaryTabLabel,
                        icon: primaryIcon,
                        selected: myAssignmentsOnly,
                        accentColor: accentColor,
                        forRequestor: forRequestor,
                        onTap: () => onChanged(true),
                      ),
                    ),
                    Expanded(
                      child: _CalendarFilterTab(
                        label: secondaryTabLabel,
                        icon: secondaryIcon,
                        selected: !myAssignmentsOnly,
                        accentColor: accentColor,
                        forRequestor: forRequestor,
                        onTap: () => onChanged(false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: forRequestor ? kSurface : kCyanDim.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: searchActive
                        ? accentColor.withValues(alpha: 0.35)
                        : (forRequestor
                            ? kBorder
                            : accentColor.withValues(alpha: 0.12)),
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: searchActive ? accentColor : kTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarFilterTab extends StatelessWidget {
  const _CalendarFilterTab({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
    this.icon,
    this.forRequestor = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;
  final bool forRequestor;

  @override
  Widget build(BuildContext context) {
    final selectedFill = forRequestor ? accentColor : kSurface;
    final selectedText = forRequestor ? Colors.white : accentColor;
    final idleText = kTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(forRequestor ? 11 : 9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            vertical: forRequestor ? 10 : 9,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? selectedFill
                : (forRequestor ? Colors.transparent : Colors.transparent),
            borderRadius: BorderRadius.circular(forRequestor ? 11 : 9),
            border: selected && !forRequestor
                ? Border.all(color: accentColor.withValues(alpha: 0.15))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? selectedText : idleText,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: selected ? selectedText : idleText,
                    fontSize: forRequestor ? 12.5 : 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.onTap,
    this.accentColor = kMemberButtonPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: accentColor.withValues(alpha: 0.75), size: 20),
        ),
      ),
    );
  }
}

class _RequestorChipPalette {
  const _RequestorChipPalette({
    required this.accent,
    required this.fill,
    required this.icon,
  });

  final Color accent;
  final Color fill;
  final IconData icon;
}

class _RequestorCalendarDayCell extends StatelessWidget {
  const _RequestorCalendarDayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.inMonth,
    required this.events,
    required this.shortTitle,
    required this.palette,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool inMonth;
  final List<CalendarEvent> events;
  final String shortTitle;
  final _RequestorChipPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.25);
    final hasEvents = events.isNotEmpty && inMonth;
    final extra = hasEvents ? events.length - 1 : 0;
    final dayColor = isSelected
        ? Colors.white
        : !inMonth
            ? kIconInactive.withValues(alpha: 0.65)
            : isToday
                ? kMemberButtonPrimary
                : kTextPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 44 * scale,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        padding: const EdgeInsets.fromLTRB(1.5, 2, 1.5, 2),
        decoration: BoxDecoration(
          color: isSelected
              ? kMemberButtonPrimary
              : !inMonth
                  ? const Color(0xFFF7FAFC)
                  : isToday
                      ? kMemberButtonPrimary.withValues(alpha: 0.1)
                      : kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? kMemberButtonPrimary
                : isToday
                    ? kMemberButtonPrimary.withValues(alpha: 0.35)
                    : kBorder.withValues(alpha: inMonth ? 0.95 : 0.65),
          ),
          boxShadow: inMonth && !isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$day',
              textAlign: TextAlign.center,
              style: dashText(TextStyle(
                color: dayColor,
                fontSize: 11,
                fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                height: 1.0,
              )),
            ),
            if (hasEvents) ...[
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : palette.fill,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  extra > 0 ? '$shortTitle +$extra' : shortTitle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: dashText(TextStyle(
                    color: isSelected ? Colors.white : kTextPrimary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.2,
                  )),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestorAgendaHeader extends StatelessWidget {
  const _RequestorAgendaHeader({
    required this.dateLabel,
    required this.eventCount,
  });

  final String dateLabel;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _requestorAgendaStrip,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCyan.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: kCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: memberDashboardSectionTitleStyle.copyWith(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              eventCount == 0
                  ? 'No events'
                  : '$eventCount event${eventCount == 1 ? '' : 's'}',
              style: dashText(const TextStyle(
                color: kTextSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestorAgendaEventCard extends StatelessWidget {
  const _RequestorAgendaEventCard({
    required this.title,
    required this.schedule,
    required this.location,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackground,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String schedule;
  final String location;
  final String statusLabel;
  final Color statusColor;
  final Color statusBackground;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locationText = location.trim();
    final scheduleText = schedule.trim();

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: memberDashboardCardTitleStyle.copyWith(
                                fontSize: 13.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 92),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: dashText(TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (scheduleText.isNotEmpty)
                            _RequestorAgendaMetaChip(
                              icon: Icons.schedule_rounded,
                              text: scheduleText,
                            ),
                          if (locationText.isNotEmpty)
                            _RequestorAgendaMetaChip(
                              icon: Icons.location_on_outlined,
                              text: locationText,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestorAgendaMetaChip extends StatelessWidget {
  const _RequestorAgendaMetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: requestorMetaIconColor(icon)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({
    required this.onTap,
    this.accentColor = kAccent,
  });

  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accentColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.22)),
          ),
          child: Icon(
            Icons.today_rounded,
            size: 17,
            color: accentColor.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _RequestorCalendarIllustratedHeader extends StatelessWidget {
  const _RequestorCalendarIllustratedHeader({
    required this.subtitle,
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;

    final banner = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final naturalHeight = width / _requestorCalendarHeaderAspect;
        final minHeight = narrow ? 96.0 : 104.0;
        final height = naturalHeight < minHeight ? minHeight : naturalHeight;

        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(_requestorCalendarHeaderRadius),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(_requestorCalendarHeaderRadius),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                const ColoredBox(
                  color: _requestorCalendarHeaderUnderpaint,
                ),
                Image.asset(
                  _requestorCalendarHeaderAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    narrow ? 14 : 16,
                    narrow ? 10 : 12,
                    narrow ? 10 : 12,
                    narrow ? 10 : 12,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: narrow ? 0.56 : 0.52,
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: width * (narrow ? 0.56 : 0.52),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Calendar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(TextStyle(
                                  color: kTextPrimary,
                                  fontSize: narrow ? 22 : 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                )),
                              ),
                              SizedBox(height: narrow ? 4 : 5),
                              Text(
                                subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(TextStyle(
                                  color: kTextSecondary,
                                  fontSize: narrow ? 11.5 : 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 4, padding, 8),
      child: banner,
    );
  }
}
