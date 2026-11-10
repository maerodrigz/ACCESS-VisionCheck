import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Requestor Home scroll/page background only (Option 1 ice blue).
const kRequestorHomeBg = Color(0xFFF2F9FD);

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
      color: kRequestorHomeBg,
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
          final declined = _declinedRequests(requests);
          final feedbackCompletion =
              memberDataController.requestorFeedbackCompletion;
          final feedbackDue = requests
              .where(feedbackCompletion.pending)
              .take(3)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (syncing)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: kCyan,
                  backgroundColor: Color(0xFF1E293B),
                ),
              RequestorHomeHeader(
                displayName: displayName,
                onNotifications: onNotificationsTap,
                onProfileTap: onProfileTap,
                showGreeting: false,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: kAccent,
                  displacement: 36,
                  strokeWidth: 2.5,
                  onRefresh: () => memberDataController.refreshAll(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: RequestorHomeGreeting(displayName: displayName),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          kMemberDashboardPagePadding,
                          4,
                          kMemberDashboardPagePadding,
                          56,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _CreateRequestCard(onCreate: () => _openCreateForm(context)),
                            const SizedBox(height: 12),
                            Text(
                              'Request Overview',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your event documentation requests',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: memberDashboardSectionSubtitleStyle.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
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
                              subtitle: 'Track your latest documentation requests',
                              actionLabel: requests.isNotEmpty ? 'View All' : null,
                              onAction: requests.isNotEmpty ? () => onOpenRequestTab() : null,
                            ),
                            const SizedBox(height: 8),
                            if (recent.isEmpty)
                              const _CompactEmptyCard(
                                icon: Icons.inbox_outlined,
                                title: 'No requests yet',
                                message:
                                    'Create a request to start tracking documentation coverage.',
                              )
                            else
                              _RecentRequestsList(
                                requests: recent,
                                onOpen: (req) => _openDetails(context, req),
                              ),
                            if (declined.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const _SectionTitleRow(
                                title: 'Action Required',
                                subtitle: 'Declined requests you can review',
                              ),
                              const SizedBox(height: 8),
                              _ActionRequiredList(
                                requests: declined,
                                onOpen: (req) => _openDetails(context, req),
                              ),
                            ],
                            const SizedBox(height: 16),
                            const _SectionTitleRow(
                              title: 'Upcoming Documentation',
                              subtitle: 'Approved coverage still ahead',
                            ),
                            const SizedBox(height: 8),
                            _UpcomingDocumentationSection(
                              requests: upcoming,
                              onOpen: (req) => _openDetails(context, req),
                            ),
                            const SizedBox(height: 16),
                            const _SectionTitleRow(
                              title: 'Pending Feedback',
                              subtitle: 'Completed coverage waiting on you',
                            ),
                            const SizedBox(height: 8),
                            _PendingFeedbackSection(
                              requests: feedbackDue,
                              statusLabel: (req) => req.requestId == null
                                  ? null
                                  : feedbackCompletion.statusLabel(req.requestId!),
                              onGiveFeedback: (req) =>
                                  onOpenFeedback(requestId: req.requestId),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

List<ServiceRequest> _declinedRequests(List<ServiceRequest> all) {
  final list = all.where((r) => r.requestStatus == RequestStatus.rejected).toList()
    ..sort((a, b) {
      final ad = a.updatedAt ?? a.submissionDate ?? a.eventDate;
      final bd = b.updatedAt ?? b.submissionDate ?? b.eventDate;
      return bd.compareTo(ad);
    });
  return list.take(3).toList();
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

// ── Create request ───────────────────────────────────────────────────────────

class _CreateRequestCard extends StatelessWidget {
  const _CreateRequestCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final iconBox = narrow ? 36.0 : 40.0;

    return MemberDashboardCard(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 14, 12, narrow ? 12 : 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: _overviewTotalBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: kAccent,
                  size: narrow ? 20 : 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need event coverage?',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardCardTitleStyle.copyWith(
                        fontSize: narrow ? 15 : 16,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Schedule your event in advance and request documentation coverage.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: narrow ? 11.5 : 12,
                        height: 1.3,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CoverageChip(
                icon: Icons.photo_camera_outlined,
                label: 'Photo',
                color: kAccent,
                background: _overviewTotalBg,
              ),
              _CoverageChip(
                icon: Icons.videocam_outlined,
                label: 'Video',
                color: kCyan,
                background: kCyanDim,
              ),
              _CoverageChip(
                icon: Icons.groups_outlined,
                label: 'Team',
                color: kGreen,
                background: kGreenDim,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: kMemberButtonPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_rounded, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Create Request',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageChip extends StatelessWidget {
  const _CoverageChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            )),
          ),
        ],
      ),
    );
  }
}

// ── Request overview bento ───────────────────────────────────────────────────

/// Soft blue tile background for total requests (reference bento).
const _overviewTotalBg = Color(0xFFEAF3FF);

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
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _OverviewStatCard(
                  count: total,
                  label: 'Total Requests',
                  detail: 'All submitted requests',
                  icon: Icons.assignment_outlined,
                  iconBackground: _overviewTotalBg,
                  iconColor: kAccent,
                  onTap: () => onOpenRequestTab(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStatCard(
                  count: pending,
                  label: 'Pending',
                  detail: 'Awaiting review',
                  icon: Icons.schedule_rounded,
                  iconBackground: kYellowDim,
                  iconColor: kYellow,
                  onTap: () => onOpenRequestTab(filter: RequestStatus.pending),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _OverviewStatCard(
                  count: approved,
                  label: 'Approved',
                  detail: 'Accepted for coverage',
                  icon: Icons.check_circle_rounded,
                  iconBackground: kGreenDim,
                  iconColor: kGreen,
                  onTap: () => onOpenRequestTab(filter: RequestStatus.approved),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStatCard(
                  count: completed,
                  label: 'Completed',
                  detail: 'Documentation finished',
                  icon: Icons.done_all_rounded,
                  iconBackground: kDashStatPurple,
                  iconColor: kDashStatPurpleIcon,
                  onTap: () => onOpenRequestTab(filter: RequestStatus.completed),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.count,
    required this.label,
    required this.detail,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  final int count;
  final String label;
  final String detail;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final iconBox = narrow ? 30.0 : 32.0;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(narrow ? 10 : 12, 10, narrow ? 10 : 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: narrow ? 16 : 17),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    fontSize: narrow ? 20 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: kTextPrimary,
                    letterSpacing: -0.4,
                  )),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    fontSize: narrow ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: kTextPrimary,
                  )),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(
                    fontSize: narrow ? 10.5 : 11,
                    height: 1.25,
                    color: kTextSecondary,
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

// ── Sections ─────────────────────────────────────────────────────────────────

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardSectionSubtitleStyle.copyWith(fontSize: 12),
                ),
              ],
            ],
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              )),
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

class _RecentRequestsList extends StatelessWidget {
  const _RecentRequestsList({
    required this.requests,
    required this.onOpen,
  });

  final List<ServiceRequest> requests;
  final ValueChanged<ServiceRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: kBorder),
            _RecentRequestRow(
              request: requests[i],
              onTap: () => onOpen(requests[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentRequestRow extends StatelessWidget {
  const _RecentRequestRow({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);
    final date = formatRequestShortDate(request.eventDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: narrow ? 32 : 34,
                  height: narrow ? 32 : 34,
                  decoration: BoxDecoration(
                    color: _overviewTotalBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event_rounded,
                    color: kAccent,
                    size: narrow ? 16 : 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardCardTitleStyle.copyWith(
                          fontSize: narrow ? 13 : 14,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(
                          fontSize: narrow ? 11 : 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(TextStyle(
                        color: style.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      )),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: kTextSecondary.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _homeSectionCardDecoration() {
  return BoxDecoration(
    color: kSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: kBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

class _Phase5EmptyCard extends StatelessWidget {
  const _Phase5EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _homeSectionCardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _overviewTotalBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kAccent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingDocumentationSection extends StatelessWidget {
  const _UpcomingDocumentationSection({
    required this.requests,
    required this.onOpen,
  });

  final List<ServiceRequest> requests;
  final ValueChanged<ServiceRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _Phase5EmptyCard(
        icon: Icons.event_available_outlined,
        title: 'No upcoming coverage',
        message: 'Approved events with future dates will appear here once scheduled.',
      );
    }

    final nearest = requests.first;
    final rest = requests.skip(1).toList();
    return Container(
      decoration: _homeSectionCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _UpcomingFeaturedCard(
            request: nearest,
            calendar: _calendarForRequest(nearest.requestId),
            onTap: () => onOpen(nearest),
          ),
          for (final req in rest) ...[
            const Divider(height: 1, thickness: 1, color: kBorder),
            _UpcomingCompactRow(
              request: req,
              calendar: _calendarForRequest(req.requestId),
              onTap: () => onOpen(req),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingFeaturedCard extends StatelessWidget {
  const _UpcomingFeaturedCard({
    required this.request,
    required this.calendar,
    required this.onTap,
  });

  final ServiceRequest request;
  final CalendarEvent? calendar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final location = (calendar?.location.isNotEmpty == true
            ? calendar!.location
            : request.location?.trim()) ??
        '';
    final when = _scheduleLabel(request, calendar) ?? formatRequestShortDate(request.eventDate);
    final style = RequestStatusStyle.forStatus(request.requestStatus);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 10 : 12, 12, narrow ? 8 : 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: narrow ? 32 : 36,
                height: narrow ? 32 : 36,
                decoration: BoxDecoration(
                  color: _overviewTotalBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_rounded, color: kAccent, size: narrow ? 16 : 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardCardTitleStyle.copyWith(
                        fontSize: narrow ? 14 : 15,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MetaLine(icon: Icons.schedule_rounded, iconColor: kAccent, text: when),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _MetaLine(
                        icon: Icons.location_on_outlined,
                        iconColor: kCyan,
                        text: location,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _StatusBadge(
                label: request.requestStatus.label,
                color: style.color,
                background: style.background,
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: kTextSecondary.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCompactRow extends StatelessWidget {
  const _UpcomingCompactRow({
    required this.request,
    required this.calendar,
    required this.onTap,
  });

  final ServiceRequest request;
  final CalendarEvent? calendar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = _scheduleLabel(request, calendar) ?? formatRequestShortDate(request.eventDate);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 16, color: kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13, height: 1.2),
                      ),
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.2),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: kTextSecondary.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingFeedbackSection extends StatelessWidget {
  const _PendingFeedbackSection({
    required this.requests,
    required this.statusLabel,
    required this.onGiveFeedback,
  });

  final List<ServiceRequest> requests;
  final String? Function(ServiceRequest request) statusLabel;
  final ValueChanged<ServiceRequest> onGiveFeedback;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _Phase5EmptyCard(
        icon: Icons.rate_review_outlined,
        title: 'No feedback due',
        message: 'Finished documentation will show here when your response is still needed.',
      );
    }

    return Container(
      decoration: _homeSectionCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: kBorder),
            _FeedbackReminderRow(
              request: requests[i],
              statusLabel: statusLabel(requests[i]),
              onGiveFeedback: () => onGiveFeedback(requests[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackReminderRow extends StatelessWidget {
  const _FeedbackReminderRow({
    required this.request,
    required this.onGiveFeedback,
    this.statusLabel,
  });

  final ServiceRequest request;
  final VoidCallback onGiveFeedback;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final due = (statusLabel == null || statusLabel == 'Complete')
        ? 'Share feedback on the documentation.'
        : statusLabel!;
    final when = formatRequestShortDate(request.updatedAt ?? request.eventDate);

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 10 : 12, 10, narrow ? 10 : 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kGreenDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.rate_review_outlined, color: kGreen, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.eventName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 13, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  '$when · $due',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onGiveFeedback,
            style: FilledButton.styleFrom(
              backgroundColor: kMemberButtonPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Give Feedback',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRequiredList extends StatelessWidget {
  const _ActionRequiredList({
    required this.requests,
    required this.onOpen,
  });

  final List<ServiceRequest> requests;
  final ValueChanged<ServiceRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _homeSectionCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: kBorder),
            _ActionRequiredRow(
              request: requests[i],
              onTap: () => onOpen(requests[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRequiredRow extends StatelessWidget {
  const _ActionRequiredRow({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reason = request.rejectionReason?.trim();
    final detail = (reason != null && reason.isNotEmpty)
        ? reason
        : 'Review the decline and reschedule if the event should move.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kRedDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.error_outline_rounded, color: kRed, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 13, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'View request',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dashText(const TextStyle(
                  color: kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: kTextSecondary.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: dashText(TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        )),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.iconColor = kIconInactive,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
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
