import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_calendar_event_card.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_feature_purpose.dart';

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
  bool _myAssignmentsOnly = false;
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
        if (appState.events.isEmpty) {
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
    var list = appState.events;
    if (_myAssignmentsOnly) {
      list = widget.forRequestor
          ? list.where(requestorOwnsCalendarEvent).toList()
          : list.where(memberHasActiveTaskForEvent).toList();
    }
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

  bool _dayHasMyAssignment(DateTime day) {
    final dayEvents = appState.events.where((e) => _sameDay(e.startDate, day));
    return widget.forRequestor
        ? dayEvents.any(requestorOwnsCalendarEvent)
        : dayEvents.any(memberHasActiveTaskForEvent);
  }

  bool _dayHasGeneralEvent(DateTime day) {
    if (_myAssignmentsOnly) return false;
    final dayEvents = appState.events.where((e) => _sameDay(e.startDate, day));
    return widget.forRequestor
        ? dayEvents.any((e) => !requestorOwnsCalendarEvent(e))
        : dayEvents.any((e) => !memberHasActiveTaskForEvent(e));
  }

  bool _canPlanRequestOnDay(DateTime day) {
    final today = _dayOnly(DateTime.now());
    return !_dayOnly(day).isBefore(today);
  }

  void _openEventDetail(BuildContext context, CalendarEvent event) {
    if (widget.forRequestor) {
      showRequestorCampusEventDetail(context, event);
    } else {
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

    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.forRequestor) ...[
            RequestorFeatureTitleBar(
              title: 'Calendar',
              titleFontSize: 24,
              trailing: [
                MemberPageNotificationButton(onTap: widget.onNotificationsTap),
                MemberPageProfileAvatar(onTap: widget.onProfileTap),
              ],
            ),
            RequestorFeaturePurposeLine(
              text: widget.subtitle ??
                  'Campus events and your documentation schedule.',
            ),
          ] else
            _CalendarPageHeader(
              purpose: widget.subtitle ?? 'Your events and documentation assignments',
              onNotificationsTap: widget.onNotificationsTap,
              onProfileTap: widget.onProfileTap,
            ),
          _CalendarFilterTabs(
            myAssignmentsOnly: _myAssignmentsOnly,
            onChanged: (value) => setState(() => _myAssignmentsOnly = value),
            onSearchTap: _toggleSearch,
            searchActive: _hasActiveSearch || _searchExpanded,
            primaryTabLabel:
                widget.forRequestor ? 'My Requests' : 'My Assignments',
            secondaryTabLabel: 'All Events',
          ),
          if (_searchExpanded)
            _CalendarSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
              showClear: _hasActiveSearch,
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (_, __) {
                final syncing = memberDataController.calendarTabLoading &&
                    appState.events.isEmpty;
                final loadError = memberDataController.calendarTabError;
                if (syncing) {
                  return const MobileLoadingView(message: 'Loading calendar…');
                }
                if (loadError != null && appState.events.isEmpty) {
                  return RefreshIndicator(
                    color: kAccent,
                    onRefresh: memberDataController.refreshCalendarTab,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
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
                  color: kAccent,
                  onRefresh: () => memberDataController.refreshCalendarTab(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
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
                                color: kBlueDim.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
                                border: Border.all(color: kAccent.withValues(alpha: 0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: kMemberCyan.withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
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
                                        child: Text(
                                          '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                                          style: memberDashboardSectionTitleStyle.copyWith(
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                  const SizedBox(height: 4),
                                  ...List.generate(rowCount, (row) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: List.generate(7, (col) {
                                          final dayNum = row * 7 + col - startWeekday + 1;
                                          if (dayNum < 1 || dayNum > daysInMonth) {
                                            return const Expanded(child: SizedBox(height: 40));
                                          }
                                          final date = DateTime(
                                            _focusedMonth.year,
                                            _focusedMonth.month,
                                            dayNum,
                                          );
                                          final isSelected = _sameDay(_selectedDay, date);
                                          final isToday = _sameDay(today, date);
                                          return Expanded(
                                            child: _CalendarDayCell(
                                              day: dayNum,
                                              isSelected: isSelected,
                                              isToday: isToday,
                                              hasMyAssignment: _dayHasMyAssignment(date),
                                              hasGeneralEvent: _dayHasGeneralEvent(date),
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
                                      _CalendarLegendDot(
                                        color: kCyan,
                                        label: widget.forRequestor ? 'Campus' : 'Event',
                                      ),
                                      const SizedBox(width: 12),
                                      _CalendarLegendDot(
                                        color: kAccent,
                                        label: widget.forRequestor ? 'My Request' : 'Assigned',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 8, padding, 10),
                          child: Row(
                            children: [
                              Icon(Icons.event_rounded, size: 17, color: kAccent),
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
                                          ? (widget.forRequestor &&
                                                  _canPlanRequestOnDay(_selectedDay)
                                              ? 'No events — open for planning'
                                              : 'No events scheduled')
                                          : '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
                                      style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (dayEvents.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 4, padding, 16),
                            child: _searchQuery.trim().isNotEmpty
                                ? MobileEmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'No matching events',
                                    subtitle: 'Try a different search or date.',
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
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => MemberCalendarEventCard(
                              event: dayEvents[i],
                              forRequestor: widget.forRequestor,
                              onTap: () => _openEventDetail(context, dayEvents[i]),
                            ),
                          ),
                        ),
                      if (widget.forRequestor &&
                          widget.onPlanRequest != null &&
                          _canPlanRequestOnDay(_selectedDay)) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 4, padding, 12),
                            child: MemberDashboardPrimaryButton(
                              label: 'Plan request for this date',
                              icon: Icons.add_rounded,
                              onPressed: () => widget.onPlanRequest!(_selectedDay),
                            ),
                          ),
                        ),
                      ],
                      if (upcoming.isNotEmpty) ...[
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
                                      style: const TextStyle(
                                        color: kAccent,
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

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
          prefixIcon: Icon(Icons.search_rounded, color: kAccent.withValues(alpha: 0.75), size: 22),
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
            borderSide: const BorderSide(color: kAccent, width: 1.5),
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
    final title = forRequestor && canPlan
        ? 'Nothing scheduled this day'
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
              color: kAccent,
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
  });

  final bool myAssignmentsOnly;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSearchTap;
  final bool searchActive;
  final String primaryTabLabel;
  final String secondaryTabLabel;

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
                color: kBlueDim.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: _CalendarFilterTab(
                        label: primaryTabLabel,
                        selected: myAssignmentsOnly,
                        onTap: () => onChanged(true),
                      ),
                    ),
                    Expanded(
                      child: _CalendarFilterTab(
                        label: secondaryTabLabel,
                        selected: !myAssignmentsOnly,
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
            color: kBlueDim.withValues(alpha: 0.55),
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
                        ? kAccent.withValues(alpha: 0.35)
                        : kAccent.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: searchActive ? kAccent : kTextSecondary,
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? kSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: kAccent.withValues(alpha: 0.15))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? kAccent : kTextSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
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
            border: Border.all(color: kAccent.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: kAccent.withValues(alpha: 0.75), size: 20),
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
    required this.hasMyAssignment,
    required this.hasGeneralEvent,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasMyAssignment;
  final bool hasGeneralEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showDots = hasMyAssignment || hasGeneralEvent;
    final assignedDot = isSelected ? Colors.white : kAccent;
    final generalDot = isSelected ? Colors.white.withValues(alpha: 0.85) : kCyan;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? kAccent.withValues(alpha: 0.88)
              : isToday
                  ? kAccent.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: kAccent.withValues(alpha: 0.45))
              : hasMyAssignment && !isSelected
                  ? Border.all(color: kAccent.withValues(alpha: 0.25))
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isToday
                        ? kAccent
                        : kTextPrimary,
                fontSize: 13,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                height: 1.1,
              ),
            ),
            SizedBox(
              height: 8,
              child: showDots
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasGeneralEvent)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: generalDot, shape: BoxShape.circle),
                          ),
                        if (hasMyAssignment)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: assignedDot, shape: BoxShape.circle),
                          ),
                      ],
                    )
                  : null,
            ),
          ],
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
      color: kAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kAccent.withValues(alpha: 0.22)),
          ),
          child: Icon(Icons.today_rounded, size: 17, color: kAccent.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}

class _CalendarPageHeader extends StatelessWidget {
  const _CalendarPageHeader({
    required this.purpose,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final String purpose;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final titleStyle = dashText(const TextStyle(
      color: kTextPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.15,
    ));

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, 4, padding, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendar', style: titleStyle),
                  const SizedBox(height: 1),
                  Text(
                    purpose,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: memberDashboardMetaStyle.copyWith(fontSize: 13, height: 1.25),
                  ),
                ],
              ),
            ),
            MemberPageNotificationButton(onTap: onNotificationsTap),
            MemberPageProfileAvatar(onTap: onProfileTap),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  const _CalendarLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: memberDashboardMetaStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
