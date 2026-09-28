import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_calendar_event_card.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

class CalendarScreen extends StatefulWidget {
  /// When omitted, uses the default member-facing copy.
  final String? subtitle;

  /// Switches the member shell to the Gallery tab (index 3).
  final VoidCallback? onViewGallery;

  /// Opens the member assignments list.
  final VoidCallback? onViewAssignments;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  const CalendarScreen({
    super.key,
    this.subtitle,
    this.onViewGallery,
    this.onViewAssignments,
    this.onNotificationsTap,
    this.onProfileTap,
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
  bool _myCoverageOnly = false;
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
    if (_myCoverageOnly) {
      list = list.where(memberIsAssignedToEvent).toList();
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

  int get _upcomingCount {
    final today = _dayOnly(DateTime.now());
    return _visibleEvents
        .where((e) => e.isUpcoming && !_dayOnly(e.startDate).isBefore(today))
        .length;
  }

  CalendarEvent? get _nextUpcomingEvent {
    final today = _dayOnly(DateTime.now());
    final list = _visibleEvents
        .where((e) => e.isUpcoming && !_dayOnly(e.startDate).isBefore(today))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list.isEmpty ? null : list.first;
  }

  bool _dayHasMyAssignment(DateTime day) =>
      _eventsForDay(day).any(memberIsAssignedToEvent);

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
    final rows = ((startWeekday + daysInMonth) / 7).ceil();

    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([appState, memberDataController]),
            builder: (_, __) {
              final next = _nextUpcomingEvent;
              return _CalendarMiniHero(
                upcomingCount: _upcomingCount,
                nextEvent: next,
                myAssignmentCount: appState.events.where(memberIsAssignedToEvent).length,
                onNextEventTap: next == null
                    ? null
                    : () => showMemberEventDetail(
                          context,
                          next,
                          onViewAssignment: widget.onViewAssignments,
                          onViewGallery: widget.onViewGallery,
                        ),
                onMyAssignmentsTap: widget.onViewAssignments,
                onNotificationsTap: widget.onNotificationsTap,
                onProfileTap: widget.onProfileTap,
              );
            },
          ),
          _CalendarToolbar(
            onSearch: _toggleSearch,
            hasActiveSearch: _hasActiveSearch || _searchExpanded,
            myCoverageOnly: _myCoverageOnly,
            onMyCoverageChanged: (value) => setState(() => _myCoverageOnly = value),
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
                                color: kSurface,
                                borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
                                border: Border.all(color: kBorder),
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
                                          final isSelected = _sameDay(_selectedDay, date);
                                          final isToday = _sameDay(today, date);
                                          final eventsOnDay = _eventsForDay(date);
                                          return Expanded(
                                            child: _CalendarDayCell(
                                              day: dayNum,
                                              isSelected: isSelected,
                                              isToday: isToday,
                                              eventCount: eventsOnDay.length,
                                              hasMyAssignment: _dayHasMyAssignment(date),
                                              onTap: () => setState(() => _selectedDay = date),
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _CalendarLegendDot(color: kCyan, label: 'Event'),
                                      const SizedBox(width: 12),
                                      _CalendarLegendDot(color: kAccent, label: 'Your coverage'),
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
                          padding: EdgeInsets.fromLTRB(padding, 10, padding, 6),
                          child: Row(
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
                                          ? 'No events scheduled'
                                          : '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'} scheduled',
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
                            padding: EdgeInsets.symmetric(horizontal: padding),
                            child: _searchQuery.trim().isNotEmpty
                                ? MobileEmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'No matching events',
                                    subtitle: 'Try a different search or date.',
                                  )
                                : _CalendarNoEventsEmptyState(
                                    onViewGallery: widget.onViewGallery,
                                    onViewAssignments: widget.onViewAssignments,
                                    myCoverageOnly: _myCoverageOnly,
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
                              onTap: () => showMemberEventDetail(
                                context,
                                dayEvents[i],
                                onViewAssignment: widget.onViewAssignments,
                                onViewGallery: widget.onViewGallery,
                              ),
                            ),
                          ),
                        ),
                      if (upcoming.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 8, padding, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Upcoming Events',
                                    style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
                                  ),
                                ),
                                if (upcoming.length > _upcomingPreviewLimit)
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _showAllUpcoming = !_showAllUpcoming,
                                    ),
                                    child: Text(
                                      _showAllUpcoming ? 'Show Less' : 'See All',
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
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                            child: Container(
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
                                border: Border.all(color: kBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (var i = 0; i < upcomingVisible.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: kBorder.withValues(alpha: 0.85),
                                        indent: 14,
                                        endIndent: 14,
                                      ),
                                    MemberCalendarUpcomingCard(
                                      event: upcomingVisible[i],
                                      inGroup: true,
                                      onTap: () {
                                        final event = upcomingVisible[i];
                                        setState(() {
                                          _selectedDay = _dayOnly(event.startDate);
                                          _focusedMonth = DateTime(
                                            event.startDate.year,
                                            event.startDate.month,
                                          );
                                        });
                                        showMemberEventDetail(
                                          context,
                                          event,
                                          onViewAssignment: widget.onViewAssignments,
                                          onViewGallery: widget.onViewGallery,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
          prefixIcon: const Icon(Icons.search_rounded, color: kIconInactive, size: 22),
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
    this.onViewGallery,
    this.onViewAssignments,
    this.myCoverageOnly = false,
  });

  final VoidCallback? onViewGallery;
  final VoidCallback? onViewAssignments;
  final bool myCoverageOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kMemberDashboardAccentLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kMemberCyan.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.event_busy_rounded, color: kAccent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            myCoverageOnly ? 'No assigned coverage on this day' : 'No events on this day',
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            myCoverageOnly
                ? 'Try turning off My coverage or pick another date.'
                : 'Pick another date or swipe the month grid to browse.',
            textAlign: TextAlign.center,
            style: memberDashboardMetaStyle.copyWith(height: 1.4),
          ),
          if (onViewAssignments != null || onViewGallery != null) ...[
            const SizedBox(height: 14),
            if (onViewAssignments != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onViewAssignments,
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('My Assignments'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (onViewGallery != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onViewGallery,
                child: const Text('View event gallery'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.onSearch,
    required this.hasActiveSearch,
    required this.myCoverageOnly,
    required this.onMyCoverageChanged,
  });

  final VoidCallback onSearch;
  final bool hasActiveSearch;
  final bool myCoverageOnly;
  final ValueChanged<bool> onMyCoverageChanged;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('My coverage'),
            selected: myCoverageOnly,
            onSelected: onMyCoverageChanged,
            showCheckmark: false,
            avatar: Icon(
              Icons.assignment_ind_outlined,
              size: 16,
              color: myCoverageOnly ? kAccent : kIconInactive,
            ),
            labelStyle: TextStyle(
              color: myCoverageOnly ? kAccent : kTextSecondary,
              fontWeight: myCoverageOnly ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            selectedColor: kAccent.withValues(alpha: 0.1),
            side: BorderSide(
              color: myCoverageOnly ? kAccent.withValues(alpha: 0.35) : kBorder,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasActiveSearch ? kAccent.withValues(alpha: 0.1) : kSurfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasActiveSearch ? kAccent.withValues(alpha: 0.35) : kBorder,
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: hasActiveSearch ? kAccent : kIconInactive,
                ),
              ),
            ),
          ),
        ],
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
      color: kSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Icon(icon, color: kTextSecondary, size: 20),
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
    required this.eventCount,
    required this.hasMyAssignment,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final int eventCount;
  final bool hasMyAssignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = isSelected
        ? Colors.white
        : (hasMyAssignment ? kAccent : kCyan);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? kAccent
              : isToday
                  ? kAccent.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: kAccent, width: 1.5)
              : hasMyAssignment && !isSelected
                  ? Border.all(color: kAccent.withValues(alpha: 0.35))
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
              ),
            ),
            const SizedBox(height: 2),
            if (eventCount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  eventCount.clamp(0, 3),
                  (_) => Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 3),
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
      color: kAccent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kAccent.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.today_rounded, size: 17, color: kAccent),
        ),
      ),
    );
  }
}

class _CalendarMiniHero extends StatelessWidget {
  const _CalendarMiniHero({
    required this.upcomingCount,
    this.nextEvent,
    required this.myAssignmentCount,
    this.onNextEventTap,
    this.onMyAssignmentsTap,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final int upcomingCount;
  final CalendarEvent? nextEvent;
  final int myAssignmentCount;
  final VoidCallback? onNextEventTap;
  final VoidCallback? onMyAssignmentsTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final headline = upcomingCount == 0
        ? 'No upcoming events'
        : '$upcomingCount upcoming event${upcomingCount == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberDarkHeroMiniBottomRadius),
          bottomRight: Radius.circular(kMemberDarkHeroMiniBottomRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 4, padding, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Your schedule',
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      )),
                    ),
                  ),
                  MemberDarkHeroNotificationButton(onTap: onNotificationsTap),
                  MemberDarkHeroProfileAvatar(onTap: onProfileTap),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                headline,
              style: dashText(const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.2,
              )),
            ),
            const SizedBox(height: 10),
            if (nextEvent != null)
              _CalendarMiniNextEvent(
                event: nextEvent!,
                onTap: onNextEventTap,
              )
            else
              Text(
                'Approved ACCESS events appear on the grid below.',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                  height: 1.35,
                )),
              ),
            if (myAssignmentCount > 0) ...[
              const SizedBox(height: 10),
              _CalendarMiniChip(
                icon: Icons.assignment_ind_outlined,
                label: '$myAssignmentCount assigned to you',
                onTap: onMyAssignmentsTap,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _CalendarMiniNextEvent extends StatelessWidget {
  const _CalendarMiniNextEvent({
    required this.event,
    this.onTap,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = event.location.trim().isNotEmpty
        ? '${event.date} · ${event.location}'
        : event.date;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: kMemberDashboardAccentGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: kAccent.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next up',
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        )),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        )),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        )),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarMiniChip extends StatelessWidget {
  const _CalendarMiniChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(width: 5),
          Text(
            label,
            style: dashText(const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            )),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
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
