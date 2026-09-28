import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_requests_repository.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/documentation_request_card.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/request_review_drawer.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/widgets/requests_kanban_board.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Modern workflow hub for documentation requests — cards + kanban, review drawer.
class DocumentationRequestsPage extends StatefulWidget {
  const DocumentationRequestsPage({super.key});

  @override
  State<DocumentationRequestsPage> createState() => _DocumentationRequestsPageState();
}

class _DocumentationRequestsPageState extends State<DocumentationRequestsPage> {
  final _repo = DocumentationRequestsRepository();
  final _searchController = TextEditingController();

  List<DocumentationRequestItem> _all = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  RequestFilterTab _filterTab = RequestFilterTab.all;
  RequestViewMode _viewMode = RequestViewMode.cards;
  RequestSortOption _sort = RequestSortOption.newest;
  RequestPriority? _priorityFilter;
  DocumentationRequestItem? _reviewItem;
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRouteIntent();
      _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyRouteIntent() {
    final params = AdminNavigationScope.consumeParams(context, AdminRoute.docRequests) ??
        AdminNavigationScope.consumeParams(context, AdminRoute.requestStatus) ??
        AdminNavigationScope.consumeParams(context, AdminRoute.taskAssignments);
    if (params == null) return;

    final tab = params['docMgmtTab'] as String?;
    final statusFilter = params['statusFilter'] as String?;

    setState(() {
      if (statusFilter != null) {
        _filterTab = filterTabFromString(statusFilter);
      } else if (tab == 'requestStatus') {
        _filterTab = RequestFilterTab.approved;
      } else if (tab == 'taskStatus') {
        _filterTab = RequestFilterTab.approved;
      } else if (tab == 'pendingRequests') {
        _filterTab = RequestFilterTab.pending;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _all = [];
          _loading = false;
        });
      }
    }
  }

  List<DocumentationRequestItem> get _visible => _repo.filterAndSort(
        items: _all,
        tab: _filterTab,
        search: _search,
        sort: _sort,
        priorityFilter: _priorityFilter,
      );

  void _navigate(AdminRoute route, {Map<String, dynamic>? params}) {
    AdminNavigationScope.go(context, route, params: params);
  }

  void _openReview(DocumentationRequestItem item) {
    setState(() {
      _reviewItem = item;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() {
    setState(() => _drawerOpen = false);
  }

  Future<void> _handleAction(DocumentationRequestItem item, String action) async {
    switch (action) {
      case 'review':
      case 'details':
      case 'progress':
        _openReview(item);
      case 'assign':
        _openReview(item);
      case 'reason':
        _openReview(item);
      case 'resubmit':
        final ok = await ConfirmDialog.show(
          context,
          title: 'Resubmit request?',
          message: 'This will move "${item.eventTitle}" back to Pending for review.',
          confirmLabel: 'Resubmit',
          icon: Icons.replay_outlined,
        );
        if (ok == true) {
          await adminApi.setRequestStatus(item.id, 'Pending');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request moved to Pending')));
            await _load();
          }
        }
      case 'archive':
        final ok = await ConfirmDialog.show(
          context,
          title: 'Archive documentation?',
          message: 'This marks the request as archived in your workflow. Media remains in the repository.',
          confirmLabel: 'Archive',
          icon: Icons.archive_outlined,
        );
        if (ok == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request archived')));
        }
    }
  }

  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<RequestSortOption>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final opt in RequestSortOption.values)
              ListTile(
                title: Text(_sortLabel(opt)),
                trailing: _sort == opt ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
                onTap: () => Navigator.pop(ctx, opt),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  Future<void> _showFilterSheet() async {
    final picked = await showModalBottomSheet<RequestPriority?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter by priority', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              title: const Text('All priorities'),
              trailing: _priorityFilter == null ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
              onTap: () => Navigator.pop(ctx, null),
            ),
            for (final p in RequestPriority.values)
              ListTile(
                title: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                trailing: _priorityFilter == p ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    setState(() => _priorityFilter = picked);
  }

  String _sortLabel(RequestSortOption opt) => switch (opt) {
        RequestSortOption.newest => 'Newest first',
        RequestSortOption.oldest => 'Oldest first',
        RequestSortOption.eventDateAsc => 'Event date (soonest)',
        RequestSortOption.eventDateDesc => 'Event date (latest)',
        RequestSortOption.priority => 'Priority',
      };

  int _tabCount(RequestFilterTab tab) => _all.where((i) => i.matchesFilter(tab)).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminTheme.contentBg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AdminBreakpoints.pagePadding(context).copyWith(bottom: 0),
                child: _PageHeader(
                  searchController: _searchController,
                  onSearchChanged: (v) => setState(() => _search = v),
                  onFilter: _showFilterSheet,
                  onSort: _showSortSheet,
                  onRefresh: _load,
                  onNewRequest: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Organizations submit new requests through the member portal.'),
                      ),
                    );
                  },
                  viewMode: _viewMode,
                  onViewModeChanged: (m) => setState(() => _viewMode = m),
                ),
              ),
              Padding(
                padding: AdminBreakpoints.pagePadding(context).copyWith(top: 12, bottom: 12),
                child: _FilterTabs(
                  selected: _filterTab,
                  onSelected: (t) => setState(() => _filterTab = t),
                  countFor: _tabCount,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: AdminBreakpoints.pagePadding(context).copyWith(top: 0),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDrawer,
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
          RequestReviewDrawer(
            item: _reviewItem,
            open: _drawerOpen,
            onClose: _closeDrawer,
            onApproved: () {
              _closeDrawer();
              _load();
            },
            onRejected: () {
              _closeDrawer();
              _load();
            },
            onAssigned: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.accentBlue));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = _visible;
    if (items.isEmpty) {
      return AdminEmptyState(
        title: 'No requests found',
        message: _search.isNotEmpty
            ? 'Try a different search term or filter.'
            : 'Documentation requests from organizations will appear here.',
        icon: Icons.inbox_outlined,
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }

    if (_viewMode == RequestViewMode.kanban) {
      return SingleChildScrollView(
        child: RequestsKanbanBoard(
          items: items,
          onAction: _handleAction,
          onNavigate: _navigate,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1200 ? 3 : c.maxWidth >= 760 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: cols == 1 ? 1.05 : 0.92,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => DocumentationRequestCard(
            item: items[i],
            onAction: _handleAction,
            onNavigate: _navigate,
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilter,
    required this.onSort,
    required this.onRefresh,
    required this.onNewRequest,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilter;
  final VoidCallback onSort;
  final VoidCallback onRefresh;
  final VoidCallback onNewRequest;
  final RequestViewMode viewMode;
  final ValueChanged<RequestViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = AdminBreakpoints.widthOf(context) < AdminBreakpoints.tablet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documentation Requests',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    breadcrumbsForRoute(AdminRoute.docRequests).join(' › '),
                    style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              _ViewToggle(viewMode: viewMode, onChanged: onViewModeChanged),
              const SizedBox(width: 8),
              PageHeaderRefreshButton(onPressed: onRefresh),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onNewRequest,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Request'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (compact) ...[
          Row(
            children: [
              Expanded(child: _ViewToggle(viewMode: viewMode, onChanged: onViewModeChanged)),
              const SizedBox(width: 8),
              PageHeaderRefreshButton(onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search requests, requestors, venues…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AdminTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminTheme.border)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _HeaderIconButton(icon: Icons.filter_list, label: compact ? null : 'Filter', onTap: onFilter),
            const SizedBox(width: 8),
            _HeaderIconButton(icon: Icons.sort, label: compact ? null : 'Sort', onTap: onSort),
            if (compact) ...[
              const SizedBox(width: 8),
              FilledButton(onPressed: onNewRequest, child: const Icon(Icons.add)),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap, this.label});

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: label != null ? Text(label!) : const SizedBox.shrink(),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminTheme.textPrimary,
        padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 12, vertical: 12),
        side: const BorderSide(color: AdminTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.viewMode, required this.onChanged});

  final RequestViewMode viewMode;
  final ValueChanged<RequestViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            icon: Icons.grid_view_rounded,
            label: 'Cards',
            selected: viewMode == RequestViewMode.cards,
            onTap: () => onChanged(RequestViewMode.cards),
          ),
          _ToggleChip(
            icon: Icons.view_kanban_outlined,
            label: 'Kanban',
            selected: viewMode == RequestViewMode.kanban,
            onTap: () => onChanged(RequestViewMode.kanban),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminTheme.accentBlue.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? AdminTheme.accentBlue : AdminTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AdminTheme.accentBlue : AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.onSelected,
    required this.countFor,
  });

  final RequestFilterTab selected;
  final ValueChanged<RequestFilterTab> onSelected;
  final int Function(RequestFilterTab) countFor;

  static const _tabs = [
    (RequestFilterTab.all, 'All'),
    (RequestFilterTab.pending, 'Pending'),
    (RequestFilterTab.approved, 'Approved'),
    (RequestFilterTab.rejected, 'Rejected'),
    (RequestFilterTab.completed, 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (tab, label) in _tabs) ...[
            _FilterTabChip(
              label: label,
              count: countFor(tab),
              selected: selected == tab,
              onTap: () => onSelected(tab),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterTabChip extends StatelessWidget {
  const _FilterTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminTheme.accentBlue : AdminTheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: selected ? 0 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AdminTheme.accentBlue : AdminTheme.border),
            boxShadow: selected ? null : AdminTheme.cardShadow,
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.2) : AdminTheme.contentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AdminTheme.textSecondary,
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
