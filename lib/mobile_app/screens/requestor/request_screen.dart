import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_feature_purpose.dart';
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
          RequestorFeatureTitleBar(
            title: 'My Requests',
            trailing: [
              MemberPageNotificationButton(onTap: widget.onNotificationsTap),
              MemberPageProfileAvatar(onTap: widget.onProfileTap),
            ],
          ),
          const RequestorFeaturePurposeLine(
            text: 'Manage and track your documentation requests.',
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

                if (loading) {
                  return const RequestListSkeleton();
                }

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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.onSelected,
  });

  final RequestStatus? selected;
  final ValueChanged<RequestStatus?> onSelected;

  static IconData _iconFor(RequestStatus? status) {
    return switch (status) {
      null => Icons.grid_view_rounded,
      RequestStatus.pending => Icons.schedule_rounded,
      RequestStatus.approved => Icons.check_circle_outline_rounded,
      RequestStatus.completed => Icons.done_all_rounded,
      RequestStatus.rejected => Icons.cancel_rounded,
    };
  }

  static Color _iconColorFor(RequestStatus? status) {
    return switch (status) {
      null => kAccent,
      RequestStatus.pending => kYellow,
      RequestStatus.approved => kGreen,
      RequestStatus.completed => kDashStatPurpleIcon,
      RequestStatus.rejected => kRed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    final labelSize = compact ? 10.0 : 11.0;
    final iconSize = compact ? 20.0 : 21.0;

    const barHeight = 64.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 4),
      child: SizedBox(
        height: barHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < requestStatusFilters.length; i++) ...[
                  if (i > 0)
                    _SegmentDivider(
                      visible: selected != requestStatusFilters[i - 1].$1 &&
                          selected != requestStatusFilters[i].$1,
                    ),
                  Expanded(
                    child: _SegmentFilterItem(
                      label: requestStatusFilters[i].$2,
                      icon: _iconFor(requestStatusFilters[i].$1),
                      inactiveIconColor: _iconColorFor(requestStatusFilters[i].$1),
                      selected: selected == requestStatusFilters[i].$1,
                      labelSize: labelSize,
                      iconSize: iconSize,
                      onTap: () => onSelected(requestStatusFilters[i].$1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentDivider extends StatelessWidget {
  const _SegmentDivider({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox(width: 2);
    }
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      color: kBorder.withValues(alpha: 0.85),
    );
  }
}

class _SegmentFilterItem extends StatelessWidget {
  const _SegmentFilterItem({
    required this.label,
    required this.icon,
    required this.inactiveIconColor,
    required this.selected,
    required this.labelSize,
    required this.iconSize,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color inactiveIconColor;
  final bool selected;
  final double labelSize;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: selected ? Colors.white : inactiveIconColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: selected ? Colors.white : kTextSecondary,
                ),
              ),
            ],
          ),
        ),
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
                        iconColor: requestorMetaIconColor(Icons.event_rounded),
                        text: formatRequestDate(request.eventDate),
                      ),
                      if (timeLabel != null) ...[
                        const SizedBox(height: 3),
                        _MetaRow(
                          icon: Icons.schedule_rounded,
                          iconColor: requestorMetaIconColor(Icons.schedule_rounded),
                          text: timeLabel,
                        ),
                      ],
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _MetaRow(
                          icon: Icons.location_on_outlined,
                          iconColor: requestorMetaIconColor(Icons.location_on_outlined),
                          text: location,
                        ),
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
                    color: kAccent.withValues(alpha: 0.45),
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
  const _MetaRow({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
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
                    backgroundColor: kMemberButtonPrimary,
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
