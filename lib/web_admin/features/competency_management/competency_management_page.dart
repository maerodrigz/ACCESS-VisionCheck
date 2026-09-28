import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_repository.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_assessment_panel.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_member_card.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_overview_cards.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_profile_drawer.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/update_competency_modal.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Competency Management Dashboard — evaluate photographers and videographers for future assignments.
class CompetencyManagementPage extends StatefulWidget {
  const CompetencyManagementPage({super.key});

  @override
  State<CompetencyManagementPage> createState() => _CompetencyManagementPageState();
}

class _CompetencyManagementPageState extends State<CompetencyManagementPage> {
  final _repo = CompetencyRepository();
  final _searchController = TextEditingController();

  CompetencyDashboardData? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  CompetencyFilterChip _chip = CompetencyFilterChip.all;
  CompetencySortOption _sort = CompetencySortOption.name;

  CompetencyMember? _selected;
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          if (_selected != null) {
            final id = _selected!.id;
            _selected = data.members.where((m) => m.id == id).firstOrNull ?? _selected;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<CompetencyMember> get _visible {
    final data = _data;
    if (data == null) return [];
    return _repo.filterAndSort(
      members: data.members,
      chip: _chip,
      search: _search,
      sort: _sort,
    );
  }

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _openProfile(CompetencyMember member) {
    setState(() {
      _selected = member;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() => setState(() => _drawerOpen = false);

  Future<void> _exportReport() async {
    final data = _data;
    if (data == null) return;
    await Clipboard.setData(ClipboardData(text: _repo.buildExportReport(data)));
    _toast('Competency report copied to clipboard');
  }

  Future<void> _showSortSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sort members', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final s in CompetencySortOption.values)
              ListTile(
                title: Text(s.label),
                trailing: _sort == s ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _sort = s);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdateLevel() async {
    final member = _selected;
    if (member == null) return;
    final result = await UpdateCompetencyModal.show(context, member: member);
    if (result == null) return;
    if (result.useSystemRecommendation) {
      await _repo.clearLevelOverride(member.id);
    } else {
      await _repo.setLevelOverride(member.id, result.level);
    }
    await _load();
    _toast('Competency level updated for ${member.name}');
  }

  Future<void> _saveNotes() async {
    final member = _selected;
    if (member == null) return;
    await _repo.setAdminNotes(member.id, member.adminNotes ?? '');
    _toast('Notes saved');
  }

  @override
  Widget build(BuildContext context) {
    final padding = AdminBreakpoints.pagePadding(context);
    final members = _visible;

    return Container(
      color: AdminTheme.contentBg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: padding.copyWith(bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeader(
                      title: 'Competency Management',
                      subtitle:
                          'Evaluate photographer and videographer competency to assign the most suitable members to future documentation requests.',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _data == null ? null : _exportReport,
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('Export Report', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        PageHeaderRefreshButton(onPressed: _load),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              hintText: 'Search name, role, competency, availability, assignment…',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _search = '');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showSortSheet,
                          icon: const Icon(Icons.sort, size: 18),
                          label: Text(_sort.label, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final chip in CompetencyFilterChip.values) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(chip.label),
                                selected: _chip == chip,
                                onSelected: (_) => setState(() => _chip = chip),
                                selectedColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                                checkmarkColor: AdminTheme.accentBlue,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _chip == chip ? AdminTheme.accentBlue : AdminTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AdminTheme.accentBlue))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: padding.copyWith(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_data != null) CompetencyOverviewCards(stats: _data!.stats),
                                const SizedBox(height: 24),
                                const Text('Team Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                const Text(
                                  'System recommendations assist assignment decisions — administrators may review criteria and override competency levels.',
                                  style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                if (members.isEmpty)
                                  const AdminEmptyState(
                                    title: 'No members match filters',
                                    message: 'Adjust filters or search terms. Approved photographers and videographers appear here.',
                                    icon: Icons.groups_outlined,
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 720 ? 2 : 1;
                                      if (cols == 1) {
                                        return Column(
                                          children: [
                                            for (final m in members) ...[
                                              SizedBox(height: 340, child: CompetencyMemberCard(member: m, onViewProfile: _openProfile)),
                                              const SizedBox(height: 14),
                                            ],
                                          ],
                                        );
                                      }
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cols,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                          childAspectRatio: cols >= 3 ? 0.72 : 0.78,
                                        ),
                                        itemCount: members.length,
                                        itemBuilder: (_, i) => CompetencyMemberCard(member: members[i], onViewProfile: _openProfile),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
              ),
            ],
          ),
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(onTap: _closeDrawer, child: Container(color: Colors.black.withValues(alpha: 0.25))),
            ),
          CompetencyProfileDrawer(
            member: _selected,
            open: _drawerOpen,
            onClose: _closeDrawer,
            onAssignToEvent: () {
              _closeDrawer();
              AdminNavigationScope.go(context, AdminRoute.docRequests);
            },
            onViewPortfolio: () {
              _closeDrawer();
              AdminNavigationScope.go(context, AdminRoute.mediaRepository);
            },
            onEditNotes: _saveNotes,
            onUpdateLevel: _handleUpdateLevel,
            onNotesChanged: (text) {
              if (_selected != null) setState(() => _selected = _selected!.copyWith(adminNotes: text));
            },
            onShowAssessment: () {
              final member = _selected;
              if (member != null) CompetencyAssessmentPanel.show(context, member);
            },
          ),
        ],
      ),
    );
  }
}
