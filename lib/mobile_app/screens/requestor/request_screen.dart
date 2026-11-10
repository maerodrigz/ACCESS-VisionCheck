import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_feature_purpose.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_progress_tracker.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';

const _requestorRequestsHeaderAsset =
    'assets/images/requestor_requests_header.png';
/// Cropped banner aspect (2102×528), aligned with Calendar header.
const _requestorRequestsHeaderAspect = 2102 / 528;
const _requestorRequestsHeaderUnderpaint = Color(0xFFC9E8F8);
const _requestorRequestsHeaderRadius = 22.0;

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
  bool _archivedOnly = false;

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
    if (_archivedOnly) {
      return sorted.where((r) => r.isRequestorArchived).toList();
    }
    final active = sorted.where((r) => !r.isRequestorArchived);
    if (_filter == null) return active.toList();
    return active.where((r) => r.requestStatus == _filter).toList();
  }

  int _archivedCount(List<ServiceRequest> all) =>
      all.where((r) => r.isRequestorArchived).length;

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
    if (_archivedOnly) return false;
    if (all.isEmpty && _filter == null) return false;
    return all.isNotEmpty;
  }

  void _selectStatusFilter(RequestStatus? value) {
    setState(() {
      _archivedOnly = false;
      _filter = value;
    });
  }

  void _toggleArchivedOnly() {
    setState(() {
      _archivedOnly = !_archivedOnly;
      if (_archivedOnly) _filter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
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
                      color: kRequestorPrimaryAction,
                      onRefresh: _reload,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          const SliverToBoxAdapter(
                            child: _RequestorRequestsIllustratedHeader(),
                          ),
                          if (syncing)
                            const SliverToBoxAdapter(
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                color: kRequestorPrimaryAction,
                                backgroundColor: kBorder,
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: _FilterBar(
                              selected: _archivedOnly ? null : _filter,
                              onSelected: _selectStatusFilter,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _ArchivedEntryChip(
                              selected: _archivedOnly,
                              count: _archivedCount(all),
                              onTap: _toggleArchivedOnly,
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
                                  _archivedOnly
                                      ? '${requests.length} archived request${requests.length == 1 ? '' : 's'}'
                                      : '${requests.length} request${requests.length == 1 ? '' : 's'}',
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
                                    archivedOnly: _archivedOnly,
                                    hasAnyRequests: all.isNotEmpty,
                                    onCreate: !_archivedOnly &&
                                            _filter == null &&
                                            all.isEmpty
                                        ? _openCreateForm
                                        : null,
                                    onClearFilter: _archivedOnly
                                        ? () => setState(() => _archivedOnly = false)
                                        : (_filter != null && all.isNotEmpty
                                            ? () => setState(() => _filter = null)
                                            : null),
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
                            shadowColor: kRequestorPrimaryAction.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            color: kRequestorPrimaryAction,
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
            color: selected ? kRequestorPrimaryAction : Colors.transparent,
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

  static const _iconTile = Color(0xFFEAF3FF);
  static const _cardRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);
    final location = request.location?.trim() ?? '';
    final timeLabel = _eventTimeLabel(request);
    final dateLabel = formatRequestDate(request.eventDate);
    final requestId = request.requestId;
    final accent = status == RequestStatus.pending
        ? kCyan
        : style.color;

    return Material(
      color: kSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(_cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
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
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _iconTile,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: accent,
                    size: 18,
                  ),
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
                              request.eventName,
                              style: memberDashboardCardTitleStyle.copyWith(
                                fontSize: 13.5,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(label: status.label, style: style),
                        ],
                      ),
                      if (requestId != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Request #$requestId',
                          style: memberDashboardMetaStyle.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                      if (request.isRequestorArchived) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 13,
                              color: kAccent.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Archived',
                              style: memberDashboardMetaStyle.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaChip(
                            icon: Icons.event_rounded,
                            text: dateLabel,
                          ),
                          if (timeLabel != null)
                            _MetaChip(
                              icon: Icons.schedule_rounded,
                              text: timeLabel,
                            ),
                          if (location.isNotEmpty)
                            _MetaChip(
                              icon: Icons.location_on_outlined,
                              text: location,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RequestProgressTracker(request: request, compact: true),
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
      constraints: const BoxConstraints(maxWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: dashText(TextStyle(
          color: style.color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        )),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 11.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchivedEntryChip extends StatelessWidget {
  const _ArchivedEntryChip({
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 2, padding, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: selected ? kAccent.withValues(alpha: 0.12) : kSurface,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? kAccent.withValues(alpha: 0.35)
                      : kBorder.withValues(alpha: 0.95),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 15,
                    color: selected ? kAccent : kTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    count > 0 ? 'Archived ($count)' : 'Archived',
                    style: dashText(TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? kAccent : kTextSecondary,
                    )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.hasAnyRequests,
    this.archivedOnly = false,
    this.onCreate,
    this.onClearFilter,
  });

  final RequestStatus? filter;
  final bool hasAnyRequests;
  final bool archivedOnly;
  final VoidCallback? onCreate;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final title = archivedOnly
        ? 'No archived requests'
        : emptyStateTitle(filter, hasAnyRequests: hasAnyRequests);
    final subtitle = archivedOnly
        ? 'Completed and declined requests you archive will appear here.'
        : emptyStateSubtitle(filter, hasAnyRequests: hasAnyRequests);

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
              child: Icon(
                archivedOnly
                    ? Icons.inventory_2_outlined
                    : Icons.assignment_outlined,
                color: kAccent,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: memberDashboardCardTitleStyle.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
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
                    foregroundColor: kRequestorPrimaryAction,
                    side: BorderSide(color: kRequestorPrimaryAction),
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

class _RequestorRequestsIllustratedHeader extends StatelessWidget {
  const _RequestorRequestsIllustratedHeader();

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;

    final banner = LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final naturalHeight = width / _requestorRequestsHeaderAspect;
                // Compact band matching Calendar: short enough for title+subtitle.
                final minHeight = narrow ? 90.0 : 96.0;
                final maxHeight = narrow ? 98.0 : 104.0;
                final height = naturalHeight.clamp(minHeight, maxHeight);
                final textWidthFactor = narrow ? 0.48 : 0.44;

                return Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(_requestorRequestsHeaderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: kCyan.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(_requestorRequestsHeaderRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        const ColoredBox(
                          color: _requestorRequestsHeaderUnderpaint,
                        ),
                        // Preserve aspect: scale to banner height, pin art to the right.
                        Align(
                          alignment: Alignment.centerRight,
                          child: Image.asset(
                            _requestorRequestsHeaderAsset,
                            height: height,
                            fit: BoxFit.fitHeight,
                            alignment: Alignment.centerRight,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                            excludeFromSemantics: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            narrow ? 14 : 16,
                            narrow ? 8 : 10,
                            narrow ? 10 : 12,
                            narrow ? 8 : 10,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: textWidthFactor,
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: width * textWidthFactor,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'My Requests',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: dashText(TextStyle(
                                          color: kTextPrimary,
                                          fontSize: narrow ? 21 : 23,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                          height: 1.08,
                                        )),
                                      ),
                                      SizedBox(height: narrow ? 3 : 4),
                                      Text(
                                        'Manage and track your documentation requests.',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: dashText(TextStyle(
                                          color: kTextSecondary,
                                          fontSize: narrow ? 11 : 12,
                                          fontWeight: FontWeight.w500,
                                          height: 1.28,
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
