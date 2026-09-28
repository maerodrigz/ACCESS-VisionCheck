import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/event_calendar/event_calendar_models.dart';
import 'package:access_mobile/web_admin/features/event_calendar/widgets/calendar_view_card.dart';
import 'package:access_mobile/web_admin/features/event_calendar/widgets/create_event_dialog.dart';
import 'package:access_mobile/web_admin/features/event_calendar/widgets/event_view_dialog.dart';
import 'package:access_mobile/web_admin/features/event_calendar/widgets/event_filter_bar.dart';
import 'package:access_mobile/web_admin/features/event_calendar/widgets/upcoming_event_list.dart';
import 'package:access_mobile/web_admin/layout/admin_feature_page.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/layout/search_filter_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Professional real-time event calendar for admin documentation scheduling.
class EventCalendarPage extends StatefulWidget {
  const EventCalendarPage({super.key});

  @override
  State<EventCalendarPage> createState() => _EventCalendarPageState();
}

class _EventCalendarPageState extends State<EventCalendarPage> {
  List<CalendarEventItem> _events = [];
  List<(int id, String name)> _members = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefresh;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;

  String _search = '';
  EventStatus? _statusFilter;
  String? _memberFilter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(silent: false);
    _autoRefresh = Timer.periodic(const Duration(seconds: 45), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool silent}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await adminApi.allEvents();
      List<(int, String)> members = [];
      try {
        final users = await adminApi.allUsers();
        members = users
            .where((u) => (u['status'] as String?)?.toLowerCase() == 'approved')
            .map((u) => (u['user_id'] as int? ?? u['id'] as int? ?? 0, u['name'] as String? ?? 'Member'))
            .where((m) => m.$1 > 0)
            .toList();
      } catch (_) {}

      // PostgreSQL event_calendar via GET /api/admin/events
      final items = list.map(CalendarEventItem.fromMap).toList();

      if (mounted) {
        setState(() {
          _events = items;
          _members = members;
          _loading = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _events = [];
          _loading = false;
          if (!silent) _lastUpdated = DateTime.now();
        });
      }
    }
  }

  List<CalendarEventItem> get _filtered {
    return _events.where((e) {
      if (_search.isNotEmpty && !e.title.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      if (_statusFilter != null && e.status != _statusFilter) return false;
      if (_memberFilter != null && e.assignedMemberName != _memberFilter) return false;
      return true;
    }).toList();
  }

  List<CalendarEventItem> get _upcoming {
    final now = DateTime.now();
    return _filtered
        .where((e) => !e.eventDate.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _statusFilter = null;
      _memberFilter = null;
      _searchController.clear();
    });
  }

  Future<void> _createEvent(CalendarEventItem item) async {
    await adminApi.createEvent(item.toApiBody());
    await _load(silent: true);
    _snack('Event created');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openDetails(CalendarEventItem event) {
    EventViewDialog.show(context, event: event);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final memberNames = _events
        .map((e) => e.assignedMemberName)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return AdminFeaturePage(
      title: 'Event Calendar',
      subtitle: 'Monitor documentation events, schedules, and team assignments in real time.',
      breadcrumbs: breadcrumbsForRoute(AdminRoute.eventCalendar),
      lastUpdated: _lastUpdated,
      loading: _loading,
      error: _error,
      errorTitle: 'Unable to load events',
      onRetry: () => _load(silent: false),
      actions: [
        PageHeaderButton(
          label: 'Create Event',
          icon: Icons.add,
          onPressed: () => CreateEventDialog.show(context, onCreate: _createEvent, members: _members),
        ),
        PageHeaderRefreshButton(onPressed: () => _load(silent: false)),
      ],
      filter: SearchFilterCard(
        child: EventFilterBar(
          searchController: _searchController,
          statusFilter: _statusFilter,
          memberFilter: _memberFilter,
          members: memberNames,
          onSearchChanged: (v) => setState(() => _search = v),
          onStatusChanged: (v) => setState(() => _statusFilter = v),
          onMemberChanged: (v) => setState(() => _memberFilter = v),
          onClear: _clearFilters,
        ),
      ),
      body: filtered.isEmpty && !_loading
          ? AdminEmptyState(
              title: 'No events scheduled',
              message: 'Approved documentation requests and created events will appear here.',
              icon: Icons.event_busy_outlined,
              actionLabel: 'Create Event',
              onAction: () => CreateEventDialog.show(context, onCreate: _createEvent, members: _members),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 960;
                final calendar = CalendarViewCard(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  viewMode: _viewMode,
                  events: filtered,
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  }),
                  onPageChanged: (focused) => setState(() => _focusedDay = focused),
                  onViewModeChanged: (mode) => setState(() => _viewMode = mode),
                  onToday: () {
                    final now = DateTime.now();
                    setState(() {
                      _focusedDay = now;
                      _selectedDay = now;
                    });
                  },
                  onEventTap: _openDetails,
                );
                final list = UpcomingEventList(
                  events: _upcoming,
                  onEventTap: _openDetails,
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: calendar),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: list),
                    ],
                  );
                }
                return Column(
                  children: [
                    calendar,
                    const SizedBox(height: 20),
                    list,
                  ],
                );
              },
            ),
    );
  }
}
