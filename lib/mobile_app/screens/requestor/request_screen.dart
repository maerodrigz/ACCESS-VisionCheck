import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Requestor "My Requests" — track and manage documentation requests.
class RequestScreen extends StatefulWidget {
  const RequestScreen({
    super.key,
    this.initialFilter,
    this.onViewGallery,
    this.onViewFeedback,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  /// Applied once when the screen opens (e.g. from Home stat cards).
  final RequestStatus? initialFilter;

  final VoidCallback? onViewGallery;
  final void Function({int? requestId})? onViewFeedback;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  RequestStatus? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  Future<void> _reload() => memberDataController.refreshAll();

  void _openDetails(ServiceRequest req) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          request: req,
          onViewGallery: widget.onViewGallery,
          onViewFeedback: widget.onViewFeedback,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  List<ServiceRequest> _sorted(List<ServiceRequest> all) {
    final copy = [...all]
      ..sort((a, b) {
        final ad = a.submissionDate ?? a.eventDate;
        final bd = b.submissionDate ?? b.eventDate;
        return bd.compareTo(ad);
      });
    return copy;
  }

  List<ServiceRequest> _filtered(List<ServiceRequest> all) {
    final sorted = _sorted(all);
    if (_filter == null) return sorted;
    return sorted.where((r) => r.requestStatus == _filter).toList();
  }

  Map<RequestStatus?, int> _statusCounts(List<ServiceRequest> all) {
    return {
      null: all.length,
      for (final status in RequestStatus.values)
        status: all.where((r) => r.requestStatus == status).length,
    };
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DocumentationRequestFormScreen()),
    );
    if (created == true && mounted) {
      await memberDataController.refreshAll();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'New request',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestorTabHero(
            title: 'My Requests',
            subtitle:
                'Track documentation requests from submission through approval and completion.',
            onNotifications: widget.onNotificationsTap,
            onProfileTap: widget.onProfileTap,
            mini: true,
          ),
          Expanded(
            child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final all = appState.serviceRequests;
          final loading = memberDataController.isLoading && all.isEmpty;
          final error = memberDataController.error;
          final requests = _filtered(all);

          if (loading) return const RequestListSkeleton();

          if (error != null && all.isEmpty) {
            return _ErrorState(message: error, onRetry: _reload);
          }

          return RefreshIndicator(
            color: kMemberPrimary,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                kMemberDashboardPagePadding,
                14,
                kMemberDashboardPagePadding,
                88,
              ),
              children: [
                _FilterBar(
                  selected: _filter,
                  counts: _statusCounts(all),
                  onSelected: (value) => setState(() => _filter = value),
                ),
                if (requests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${requests.length} request${requests.length == 1 ? '' : 's'}',
                    style: memberDashboardMetaStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (requests.isEmpty)
                  _EmptyState(
                    filter: _filter,
                    hasAnyRequests: all.isNotEmpty,
                    onCreate: _filter == null && all.isEmpty ? _openCreateForm : null,
                    onClearFilter: _filter != null && all.isNotEmpty
                        ? () => setState(() => _filter = null)
                        : null,
                  )
                else
                  ...requests.map(
                    (req) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RequestListCard(
                        request: req,
                        onTap: () => _openDetails(req),
                      ),
                    ),
                  ),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final RequestStatus? selected;
  final Map<RequestStatus?, int> counts;
  final ValueChanged<RequestStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: requestStatusFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final (value, label) = requestStatusFilters[index];
          final active = selected == value;
          final accent = requestFilterAccent(value);
          final tint = requestFilterTint(value);
          final count = counts[value] ?? 0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(value),
              borderRadius: BorderRadius.circular(20),
              splashColor: accent.withValues(alpha: 0.12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? kMemberPrimary : tint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? kMemberPrimary
                        : accent.withValues(alpha: 0.22),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: kMemberPrimary.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: active ? Colors.white : kTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.22)
                              : accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: active ? Colors.white : accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RequestListCard extends StatelessWidget {
  const _RequestListCard({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);
    final location = request.location?.trim();
    final timeLabel = _eventTimeLabel(request);

    return MemberDashboardCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        splashColor: kAccent.withValues(alpha: 0.08),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.eventName,
                    style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.event_rounded,
                    text: formatRequestDate(request.eventDate),
                  ),
                  if (timeLabel != null) ...[
                    const SizedBox(height: 4),
                    _MetaRow(icon: Icons.schedule_rounded, text: timeLabel),
                  ],
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _MetaRow(icon: Icons.location_on_outlined, text: location),
                  ],
                  if (request.submissionDate != null) ...[
                    const SizedBox(height: 4),
                    _MetaRow(
                      icon: Icons.upload_rounded,
                      text: 'Submitted ${formatRequestShortDate(request.submissionDate!)}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: style.color.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: style.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                color: kAccent.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _eventTimeLabel(ServiceRequest request) {
    final start = request.startTime?.trim();
    if (start == null || start.isEmpty) return null;
    final end = request.endTime?.trim();
    if (end != null && end.isNotEmpty) return '$start – $end';
    return start;
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: kIconInactive),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.hasAnyRequests,
    this.onCreate,
    this.onClearFilter,
  });

  final RequestStatus? filter;
  final bool hasAnyRequests;
  final VoidCallback? onCreate;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final accent = requestFilterAccent(filter);

    return MemberDashboardCard(
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Icon(Icons.inbox_rounded, color: accent, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            emptyStateTitle(filter, hasAnyRequests: hasAnyRequests),
            style: memberDashboardCardTitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            emptyStateSubtitle(filter, hasAnyRequests: hasAnyRequests),
            style: memberDashboardBodyStyle,
            textAlign: TextAlign.center,
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 18),
            MemberDashboardPrimaryButton(
              label: 'Create request',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ],
          if (onClearFilter != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onClearFilter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: const BorderSide(color: kAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Show all requests', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kMemberDashboardPagePadding),
        child: MemberDashboardCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: kRed, size: 48),
              const SizedBox(height: 14),
              Text(
                'Unable to Load Requests',
                style: memberDashboardCardTitleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Something went wrong while loading your documentation requests.',
                style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.45),
                textAlign: TextAlign.center,
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: kTextSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              MemberDashboardPrimaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => onRetry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
