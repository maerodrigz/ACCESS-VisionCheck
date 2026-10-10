import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Requestor home — light dashboard aligned with member mobile UI.
class RequestorHomeScreen extends StatelessWidget {
  const RequestorHomeScreen({
    super.key,
    required this.userName,
    required this.onOpenRequestTab,
    required this.onOpenFeedback,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final String userName;
  final void Function({RequestStatus? filter}) onOpenRequestTab;
  final void Function({int? requestId}) onOpenFeedback;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  Future<void> _openCreateForm(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DocumentationRequestFormScreen()),
    );
    if (created == true) {
      await memberDataController.refreshAll();
    }
  }

  void _openDetails(BuildContext context, ServiceRequest req) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          request: req,
          onViewGallery: RequestorShellNavigation.openGallery,
          onViewFeedback: RequestorShellNavigation.openFeedback,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final requests = appState.serviceRequests;
          final displayName = _requestorDisplayName(userName);
          final syncing = memberDataController.isLoading && requests.isNotEmpty;

          final total = requests.length;
          final pending =
              requests.where((r) => r.requestStatus == RequestStatus.pending).length;
          final approved =
              requests.where((r) => r.requestStatus == RequestStatus.approved).length;
          final completed =
              requests.where((r) => r.requestStatus == RequestStatus.completed).length;

          final recent = _recentRequests(requests);
          final upcoming = _upcomingApprovedRequests(requests);
          final feedbackDue =
              _pendingFeedbackRequests(requests, appState.feedbacks).take(3).toList();

          return RefreshIndicator(
            color: kAccent,
            displacement: 36,
            strokeWidth: 2.5,
            onRefresh: () => memberDataController.refreshAll(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (syncing)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: kCyan,
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: RequestorTabHero(
                    title: 'Welcome back, $displayName!',
                    subtitle:
                        'Track your documentation requests and upcoming coverage.',
                    titleFontWeight: FontWeight.w700,
                    onNotifications: onNotificationsTap,
                    onProfileTap: onProfileTap,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kMemberDashboardPagePadding,
                    18,
                    kMemberDashboardPagePadding,
                    56,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _CreateRequestCard(onCreate: () => _openCreateForm(context)),
                      const SizedBox(height: 20),
                      Text(
                        'Request overview',
                        style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      _RequestStatsGrid(
                        total: total,
                        pending: pending,
                        approved: approved,
                        completed: completed,
                        onOpenRequestTab: onOpenRequestTab,
                      ),
                      const SizedBox(height: 22),
                      _SectionTitleRow(
                        title: 'Recent Requests',
                        actionLabel: requests.isNotEmpty ? 'View All' : null,
                        onAction: requests.isNotEmpty ? () => onOpenRequestTab() : null,
                      ),
                      const SizedBox(height: 10),
                      if (recent.isEmpty)
                        const _CompactEmptyCard(
                          icon: Icons.inbox_outlined,
                          title: 'No requests yet',
                          message: 'Create a request to start tracking documentation coverage.',
                        )
                      else
                        ...recent.map(
                          (req) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CompactRequestRow(
                              request: req,
                              onTap: () => _openDetails(context, req),
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      const _SectionTitleRow(title: 'Upcoming Documentation'),
                      const SizedBox(height: 10),
                      if (upcoming.isEmpty)
                        const _CompactEmptyCard(
                          icon: Icons.event_available_outlined,
                          title: 'No upcoming coverage',
                          message:
                              'Approved events with future dates will appear here once scheduled.',
                        )
                      else
                        ...upcoming.map(
                          (req) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _UpcomingEventCard(
                              request: req,
                              calendar: _calendarForRequest(req.requestId),
                              onTap: () => _openDetails(context, req),
                            ),
                          ),
                        ),
                      if (feedbackDue.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const _SectionTitleRow(title: 'Pending Feedback'),
                        const SizedBox(height: 10),
                        ...feedbackDue.map(
                          (req) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FeedbackReminderCard(
                              request: req,
                              onGiveFeedback: () => onOpenFeedback(requestId: req.requestId),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _requestorDisplayName(String sessionName) {
  final profile = appState.profileName.trim();
  if (profile.isNotEmpty) return profile;
  final session = sessionName.trim();
  if (session.isNotEmpty) return session;
  return 'Organization';
}

List<ServiceRequest> _recentRequests(List<ServiceRequest> all) {
  final sorted = [...all]
    ..sort((a, b) {
      final ad = a.submissionDate ?? a.eventDate;
      final bd = b.submissionDate ?? b.eventDate;
      return bd.compareTo(ad);
    });
  return sorted.take(3).toList();
}

List<ServiceRequest> _upcomingApprovedRequests(List<ServiceRequest> all) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final list = all
      .where((r) {
        if (r.requestStatus != RequestStatus.approved) return false;
        final day = DateTime(r.eventDate.year, r.eventDate.month, r.eventDate.day);
        return !day.isBefore(todayDate);
      })
      .toList()
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  return list.take(3).toList();
}

CalendarEvent? _calendarForRequest(int? requestId) {
  if (requestId == null) return null;
  for (final e in appState.events) {
    if (e.requestId == requestId) return e;
  }
  return null;
}

bool _requestHasFeedback(ServiceRequest r, List<EventFeedback> feedbacks) {
  final rid = r.requestId;
  if (rid == null) return false;
  final title = r.eventName;
  return feedbacks.any(
    (f) => f.eventTitle == title || f.eventTitle == 'Request #$rid',
  );
}

List<ServiceRequest> _pendingFeedbackRequests(
  List<ServiceRequest> all,
  List<EventFeedback> feedbacks,
) {
  final list = all
      .where(
        (r) =>
            r.requestStatus == RequestStatus.completed &&
            r.requestId != null &&
            !_requestHasFeedback(r, feedbacks),
      )
      .toList();
  list.sort((a, b) => b.eventDate.compareTo(a.eventDate));
  return list;
}

String? _scheduleLabel(ServiceRequest r, CalendarEvent? cal) {
  final date = formatRequestShortDate(r.eventDate);
  final time = cal?.timeLabel?.trim();
  if (time != null && time.isNotEmpty) return '$date · $time';
  final start = r.startTime?.trim();
  if (start != null && start.isNotEmpty) {
    final end = r.endTime?.trim();
    if (end != null && end.isNotEmpty) return '$date · $start – $end';
    return '$date · $start';
  }
  return date;
}

String? _documentersLabel(CalendarEvent? cal) {
  if (cal == null) return null;
  if (cal.documentationTeam.isNotEmpty) {
    return cal.documentationTeam.join(', ');
  }
  final lead = cal.assignedMemberName?.trim();
  if (lead != null && lead.isNotEmpty) return lead;
  return null;
}

// ── Create request ───────────────────────────────────────────────────────────

class _CreateRequestCard extends StatelessWidget {
  const _CreateRequestCard({required this.onCreate});

  final VoidCallback onCreate;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [kAccent, Color(0xFF0066CC)],
  );

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need event coverage?',
              style: dashText(const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.2,
              )),
            ),
            const SizedBox(height: 4),
            Text(
              'Submit a documentation request for your next event.',
              style: dashText(TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.35,
              )),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: kSurface,
                  foregroundColor: kAccent,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Request',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats grid ───────────────────────────────────────────────────────────────

class _RequestStatsGrid extends StatelessWidget {
  const _RequestStatsGrid({
    required this.total,
    required this.pending,
    required this.approved,
    required this.completed,
    required this.onOpenRequestTab,
  });

  final int total;
  final int pending;
  final int approved;
  final int completed;
  final void Function({RequestStatus? filter}) onOpenRequestTab;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AccessStatCard(
                icon: Icons.description_outlined,
                value: '$total',
                label: 'Total Requests',
                iconColor: kAccent,
                dashboardLayout: true,
                onTap: () => onOpenRequestTab(),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: AccessStatCard(
                icon: Icons.schedule_rounded,
                value: '$pending',
                label: 'Pending',
                iconColor: kYellow,
                dashboardLayout: true,
                onTap: () => onOpenRequestTab(filter: RequestStatus.pending),
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: AccessStatCard(
                icon: Icons.check_circle_outline_rounded,
                value: '$approved',
                label: 'Approved',
                iconColor: kGreen,
                dashboardLayout: true,
                onTap: () => onOpenRequestTab(filter: RequestStatus.approved),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: AccessStatCard(
                icon: Icons.task_alt_rounded,
                value: '$completed',
                label: 'Completed',
                iconColor: kDashStatPurpleIcon,
                dashboardLayout: true,
                onTap: () => onOpenRequestTab(filter: RequestStatus.completed),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Sections ─────────────────────────────────────────────────────────────────

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: kAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _CompactEmptyCard extends StatelessWidget {
  const _CompactEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: memberDashboardCardTitleStyle.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRequestRow extends StatelessWidget {
  const _CompactRequestRow({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);
    return MemberDashboardCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scheduleLabel(request, null) ?? formatRequestShortDate(request.eventDate),
                      style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: style.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({
    required this.request,
    required this.calendar,
    required this.onTap,
  });

  final ServiceRequest request;
  final CalendarEvent? calendar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = (calendar?.location.isNotEmpty == true
            ? calendar!.location
            : request.location?.trim()) ??
        '';
    final documenters = _documentersLabel(calendar);

    return MemberDashboardCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.eventName,
                style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 6),
              _MetaLine(
                icon: Icons.event_rounded,
                text: _scheduleLabel(request, calendar) ?? formatRequestShortDate(request.eventDate),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                _MetaLine(icon: Icons.location_on_outlined, text: location),
              ],
              if (documenters != null) ...[
                const SizedBox(height: 4),
                _MetaLine(icon: Icons.groups_outlined, text: documenters),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackReminderCard extends StatelessWidget {
  const _FeedbackReminderCard({
    required this.request,
    required this.onGiveFeedback,
  });

  final ServiceRequest request;
  final VoidCallback onGiveFeedback;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rate_review_outlined, color: kAccent.withValues(alpha: 0.9), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.eventName,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coverage is complete. Share feedback on the documentation team.',
                  style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: onGiveFeedback,
                    style: FilledButton.styleFrom(
                      foregroundColor: kAccent,
                      backgroundColor: kAccent.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Give Feedback',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kIconInactive),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
