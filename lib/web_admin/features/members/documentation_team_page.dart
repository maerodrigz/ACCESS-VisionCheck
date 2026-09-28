import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/members/member_models.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/features/members/team_members_repository.dart';
import 'package:access_mobile/web_admin/features/members/widgets/member_admin_dialogs.dart';
import 'package:access_mobile/web_admin/features/members/widgets/team_member_card.dart';
import 'package:access_mobile/web_admin/features/members/widgets/team_member_drawer.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Documentation team management — card-based, no tables.
class DocumentationTeamPage extends StatefulWidget {
  const DocumentationTeamPage({super.key});

  @override
  State<DocumentationTeamPage> createState() => _DocumentationTeamPageState();
}

class _DocumentationTeamPageState extends State<DocumentationTeamPage> {
  final _repo = TeamMembersRepository();
  final _searchController = TextEditingController();

  List<TeamMemberProfile> _all = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  TeamFilterChip _chip = TeamFilterChip.all;
  TeamSortOption _sort = TeamSortOption.name;
  TeamMemberProfile? _selected;
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
    final params = AdminNavigationScope.consumeParams(context, AdminRoute.members);
    if (params == null) return;
    final status = params['statusFilter'] as String?;
    if (status == 'pending') {
      setState(() => _chip = TeamFilterChip.inactive);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.loadTeam();
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
          if (_selected != null) {
            final id = _selected!.id;
            _selected = list.where((m) => m.id == id).firstOrNull ?? _selected;
          }
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

  List<TeamMemberProfile> get _visible => _repo.filterAndSort(
        members: _all,
        chip: _chip,
        search: _search,
        sort: _sort,
      );

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _openProfile(TeamMemberProfile member) {
    setState(() {
      _selected = member;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() => setState(() => _drawerOpen = false);

  Future<void> _deactivate(TeamMemberProfile member) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Deactivate member?',
      message: '${member.name} will lose access until re-approved.',
      confirmLabel: 'Deactivate',
      destructive: true,
      icon: Icons.block,
    );
    if (ok != true) return;
    try {
      await adminApi.setUserStatus(member.id, 'rejected');
      _closeDrawer();
      await _load();
      _toast('Member deactivated');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  AdminMemberRow _toMemberRow(TeamMemberProfile m) => AdminMemberRow(
        id: m.id,
        name: m.name,
        email: m.email,
        role: 'Member',
        status: m.accountStatus,
        skillLevel: m.skillLevel,
        assignedTasks: m.assignedTasks,
        completedTasks: m.completedTasks,
        mediaEvalScore: m.averageQualityScore,
        primaryTaskRole: m.coverageRole == TeamCoverageRole.photographer
            ? 'photographer'
            : m.coverageRole == TeamCoverageRole.videographer
                ? 'videographer'
                : null,
      );

  Future<void> _editMember(TeamMemberProfile member) async {
    final row = _toMemberRow(member);
    await MemberAdminDialogs.showProfile(context, row);
    if (!mounted) return;
    final st = await MemberAdminDialogs.pickStatus(context, member.accountStatus);
    if (st != null && mounted) {
      if (st == 'rejected') {
        final reason = await MemberAdminDialogs.rejectionReason(context, row);
        if (reason != null) {
          await adminApi.setUserStatus(member.id, st, rejectionReason: reason);
          await _load();
        }
      } else {
        await adminApi.setUserStatus(member.id, st);
        await _load();
      }
    }
  }

  Future<void> _showFilterSheet() async {
    final picked = await showModalBottomSheet<TeamFilterChip>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Filter team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            for (final (chip, label) in _FilterChips._chips)
              ListTile(
                title: Text(label),
                trailing: _chip == chip ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
                onTap: () => Navigator.pop(ctx, chip),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _chip = picked);
  }

  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<TeamSortOption>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            for (final opt in TeamSortOption.values)
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

  String _sortLabel(TeamSortOption opt) => switch (opt) {
        TeamSortOption.name => 'Name (A–Z)',
        TeamSortOption.performance => 'Overall performance',
        TeamSortOption.tasksCompleted => 'Tasks completed',
        TeamSortOption.qualityScore => 'Media quality score',
        TeamSortOption.skillLevel => 'Skill level',
      };

  int _chipCount(TeamFilterChip chip) => _all.where((m) => m.matchesChip(chip)).length;

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
                child: _TeamHeader(
                  searchController: _searchController,
                  onSearchChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  onFilter: _showFilterSheet,
                  onSort: _showSortSheet,
                  onRefresh: _load,
                  onAddMember: () {
                    AdminNavigationScope.go(context, AdminRoute.registrationApprovals);
                    _toast('Review pending registrations to add new team members');
                  },
                ),
              ),
              Padding(
                padding: AdminBreakpoints.pagePadding(context).copyWith(top: 12, bottom: 12),
                child: _FilterChips(selected: _chip, onSelected: (c) => setState(() => _chip = c), countFor: _chipCount),
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
              child: GestureDetector(onTap: _closeDrawer, child: Container(color: Colors.black.withValues(alpha: 0.25))),
            ),
          TeamMemberProfileDrawer(
            member: _selected,
            open: _drawerOpen,
            onClose: _closeDrawer,
            onAssignToEvent: () {
              _closeDrawer();
              AdminNavigationScope.go(context, AdminRoute.docRequests);
            },
            onEditMember: _selected == null ? () {} : () => _editMember(_selected!),
            onDeactivate: _selected == null ? () {} : () => _deactivate(_selected!),
            onViewPortfolio: () {
              _closeDrawer();
              AdminNavigationScope.go(context, AdminRoute.mediaRepository);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminTheme.accentBlue));
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
        title: 'No team members found',
        message: 'Adjust filters or approve new member registrations.',
        icon: Icons.groups_outlined,
        actionLabel: 'Refresh',
        onAction: _load,
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
            childAspectRatio: cols == 1 ? 0.78 : 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => TeamMemberCard(member: items[i], onViewProfile: _openProfile),
        );
      },
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilter,
    required this.onSort,
    required this.onRefresh,
    required this.onAddMember,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilter;
  final VoidCallback onSort;
  final VoidCallback onRefresh;
  final VoidCallback onAddMember;

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
                  const Text(
                    'Members',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    breadcrumbsForRoute(AdminRoute.members).join(' › '),
                    style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Monitor photographers and videographers, check availability, and assign coverage.',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              PageHeaderRefreshButton(onPressed: onRefresh),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAddMember,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add Member'),
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search members…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AdminTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminTheme.border)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _OutlineBtn(icon: Icons.filter_list, label: compact ? null : 'Filter', onTap: onFilter),
            const SizedBox(width: 8),
            _OutlineBtn(icon: Icons.sort, label: compact ? null : 'Sort', onTap: onSort),
            if (compact) ...[
              const SizedBox(width: 8),
              FilledButton(onPressed: onAddMember, child: const Icon(Icons.person_add_outlined)),
            ],
          ],
        ),
      ],
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.icon, required this.onTap, this.label});

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
        padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 12, vertical: 12),
        side: const BorderSide(color: AdminTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected, required this.countFor});

  final TeamFilterChip selected;
  final ValueChanged<TeamFilterChip> onSelected;
  final int Function(TeamFilterChip) countFor;

  static const _chips = [
    (TeamFilterChip.all, 'All'),
    (TeamFilterChip.photographers, 'Photographers'),
    (TeamFilterChip.videographers, 'Videographers'),
    (TeamFilterChip.available, 'Available'),
    (TeamFilterChip.assigned, 'Assigned'),
    (TeamFilterChip.inactive, 'Inactive'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (chip, label) in _chips) ...[
            _Chip(label: label, count: countFor(chip), selected: selected == chip, onTap: () => onSelected(chip)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminTheme.accentBlue : AdminTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AdminTheme.accentBlue : AdminTheme.border),
          ),
          child: Row(
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AdminTheme.textPrimary)),
              const SizedBox(width: 6),
              Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? Colors.white70 : AdminTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
