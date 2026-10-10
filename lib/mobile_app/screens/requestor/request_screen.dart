import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_progress_tracker.dart';
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

  static const _listBottomPadding = 72.0;

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

  bool _showFloatingNewRequest(List<ServiceRequest> all) {
    if (all.isEmpty && _filter == null) return false;
    return all.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RequestsPageHeader(
            onNotificationsTap: widget.onNotificationsTap,
            onProfileTap: widget.onProfileTap,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (context, _) {
                final all = appState.serviceRequests;
                final loading = memberDataController.isLoading && all.isEmpty;
                final syncing = memberDataController.isLoading && all.isNotEmpty;
                final error = memberDataController.error;
                final requests = _filtered(all);
                final showFab = _showFloatingNewRequest(all);

                if (loading) return const RequestListSkeleton();

                if (error != null && all.isEmpty) {
                  return _ErrorState(message: error, onRetry: _reload);
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    RefreshIndicator(
                      color: kAccent,
                      onRefresh: _reload,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          if (syncing)
                            const SliverToBoxAdapter(
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                color: kAccent,
                                backgroundColor: kBorder,
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: _FilterBar(
                              selected: _filter,
                              counts: _statusCounts(all),
                              onSelected: (value) => setState(() => _filter = value),
                            ),
                          ),
                          if (requests.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  mobilePagePaddingOf(context),
                                  4,
                                  mobilePagePaddingOf(context),
                                  0,
                                ),
                                child: Text(
                                  '${requests.length} request${requests.length == 1 ? '' : 's'}',
                                  style: memberDashboardMetaStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          if (requests.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  mobilePagePaddingOf(context),
                                  12,
                                  mobilePagePaddingOf(context),
                                  _listBottomPadding,
                                ),
                                child: Center(
                                  child: _EmptyState(
                                    filter: _filter,
                                    hasAnyRequests: all.isNotEmpty,
                                    onCreate:
                                        _filter == null && all.isEmpty ? _openCreateForm : null,
                                    onClearFilter: _filter != null && all.isNotEmpty
                                        ? () => setState(() => _filter = null)
                                        : null,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                mobilePagePaddingOf(context),
                                10,
                                mobilePagePaddingOf(context),
                                _listBottomPadding + (showFab ? 56 : 0),
                              ),
                              sliver: SliverList.separated(
                                itemCount: requests.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => _RequestListCard(
                                  request: requests[i],
                                  onTap: () => _openDetails(requests[i]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showFab)
                      Positioned(
                        right: mobilePagePaddingOf(context),
                        bottom: 16,
                        child: SafeArea(
                          top: false,
                          child: Material(
                            elevation: 3,
                            shadowColor: kAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            color: kAccent,
                            child: InkWell(
                              onTap: _openCreateForm,
                              borderRadius: BorderRadius.circular(14),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'New Request',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsPageHeader extends StatelessWidget {
  const _RequestsPageHeader({
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return Material(
      color: kSurface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.9))),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, 6, padding, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Requests',
                        style: dashText(const TextStyle(
                          color: kTextPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.15,
                        )),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage and track your documentation requests.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                MemberPageNotificationButton(onTap: onNotificationsTap),
                MemberPageProfileAvatar(onTap: onProfileTap),
              ],
            ),
          ),
        ),
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

  static const _chipHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return SizedBox(
      height: _chipHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
        clipBehavior: Clip.none,
        itemCount: requestStatusFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final (value, label) = requestStatusFilters[index];
          final active = selected == value;
          final count = counts[value] ?? 0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(value),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: _chipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? kAccent : kSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? kAccent : kBorder,
                    width: active ? 1 : 1,
                  ),
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
                        height: 1,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.22)
                              : kAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: active ? Colors.white : kAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
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
    final requestId = request.requestId;

    return Material(
      color: kSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              request.eventName,
                              style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(label: status.label, style: style),
                        ],
                      ),
                      if (requestId != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Request #$requestId',
                          style: memberDashboardMetaStyle.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _MetaRow(
                        icon: Icons.event_rounded,
                        text: formatRequestDate(request.eventDate),
                      ),
                      if (timeLabel != null) ...[
                        const SizedBox(height: 3),
                        _MetaRow(icon: Icons.schedule_rounded, text: timeLabel),
                      ],
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _MetaRow(icon: Icons.location_on_outlined, text: location),
                      ],
                      const SizedBox(height: 10),
                      RequestProgressTracker(request: request, compact: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: kIconInactive,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.style});

  final String label;
  final RequestStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.assignment_outlined, color: kAccent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              emptyStateTitle(filter, hasAnyRequests: hasAnyRequests),
              style: memberDashboardCardTitleStyle.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              emptyStateSubtitle(filter, hasAnyRequests: hasAnyRequests),
              style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Create Request',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
            if (onClearFilter != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onClearFilter,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: const BorderSide(color: kAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text(
                    'Show all requests',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
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
              const Icon(Icons.cloud_off_rounded, color: kRed, size: 40),
              const SizedBox(height: 12),
              Text(
                'Unable to load requests',
                style: memberDashboardCardTitleStyle.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Something went wrong while loading your documentation requests.',
                style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45),
                textAlign: TextAlign.center,
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(color: kTextSecondary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 14),
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
