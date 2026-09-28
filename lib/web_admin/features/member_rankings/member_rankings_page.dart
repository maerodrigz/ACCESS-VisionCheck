import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/member_rankings/member_ranking_models.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/member_ranking_details_dialog.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/member_ranking_table.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/ranking_filter_bar.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_feature_page.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/layout/pagination_state.dart';
import 'package:access_mobile/web_admin/layout/search_filter_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/utils/admin_toast.dart';

/// Admin Member Rankings — performance, skill, and participation leaderboard.
class MemberRankingsPage extends StatefulWidget {
  const MemberRankingsPage({super.key});

  @override
  State<MemberRankingsPage> createState() => _MemberRankingsPageState();
}

class _MemberRankingsPageState extends State<MemberRankingsPage> {
  List<MemberRankingRow> _allRows = [];
  RankingsSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _showFilters = true;
  DateTime? _lastUpdated;
  final _pagination = PaginationState();
  final _filters = RankingFilters();
  final _nameSearch = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // PostgreSQL member rankings via GET /api/rankings
      final list = await adminApi.rankings();
      Map<String, dynamic> summaryMap = {};
      try {
        summaryMap = await adminApi.rankingsSummary();
      } catch (_) {}
      final rows = list.map(MemberRankingRow.fromMap).toList();
      final display = _rankBySkillScore(rows);

      if (mounted) {
        setState(() {
          _allRows = display;
          _summary = summaryMap.isNotEmpty
              ? RankingsSummary.fromMap(summaryMap)
              : _summaryFromRows(display);
          _loading = false;
          _lastUpdated = DateTime.now();
          _pagination.reset();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _allRows = [];
          _summary = const RankingsSummary(
            totalRanked: 0,
            topPerformerName: '—',
            topPerformerPoints: 0,
            mostActiveUploaderName: '—',
            mostActiveUploads: 0,
            needsImprovementCount: 0,
          );
          _loading = false;
          _lastUpdated = DateTime.now();
        });
      }
    }
  }

  List<MemberRankingRow> _rankBySkillScore(List<MemberRankingRow> rows) {
    final sorted = [...rows]..sort((a, b) => b.skillScore.compareTo(a.skillScore));
    return sorted.asMap().entries.map((e) => e.value.copyWith(rank: e.key + 1)).toList();
  }

  RankingsSummary _summaryFromRows(List<MemberRankingRow> rows) {
    if (rows.isEmpty) {
      return const RankingsSummary(
        totalRanked: 0,
        topPerformerName: '—',
        topPerformerPoints: 0,
        mostActiveUploaderName: '—',
        mostActiveUploads: 0,
        needsImprovementCount: 0,
      );
    }
    final top = rows.reduce((a, b) => a.points >= b.points ? a : b);
    final most = rows.reduce((a, b) => a.uploads >= b.uploads ? a : b);
    final needs = rows.where((r) =>
        r.participationStatus == ParticipationStatus.needsTraining ||
        r.participationStatus == ParticipationStatus.inactive).length;
    return RankingsSummary(
      totalRanked: rows.length,
      topPerformerName: top.memberName,
      topPerformerPoints: top.points,
      mostActiveUploaderName: most.memberName,
      mostActiveUploads: most.uploads,
      needsImprovementCount: needs,
    );
  }

  List<MemberRankingRow> get _filtered {
    var list = _allRows.where((r) {
      if (_filters.nameQuery.isNotEmpty &&
          !r.memberName.toLowerCase().contains(_filters.nameQuery.toLowerCase())) {
        return false;
      }
      if (_filters.skillFilter != null && r.skillTier != _filters.skillFilter) return false;
      if (_filters.statusFilter != null && r.participationStatus != _filters.statusFilter) {
        return false;
      }
      return true;
    }).toList();

    list = switch (_filters.sort) {
      RankingSort.points => list..sort((a, b) => b.points.compareTo(a.points)),
      RankingSort.uploads => list..sort((a, b) => b.uploads.compareTo(a.uploads)),
      RankingSort.averageQuality =>
        list..sort((a, b) => b.averageQualityScore.compareTo(a.averageQualityScore)),
      RankingSort.lastActivity => list
        ..sort((a, b) {
          final ad = a.lastActivity ?? DateTime(1970);
          final bd = b.lastActivity ?? DateTime(1970);
          return bd.compareTo(ad);
        }),
      RankingSort.skillScore => list..sort((a, b) => b.skillScore.compareTo(a.skillScore)),
      RankingSort.rank => list..sort((a, b) => a.rank.compareTo(b.rank)),
    };
    return list;
  }

  int get _maxPoints => _allRows.fold<int>(0, (m, r) => r.points > m ? r.points : m);
  int get _maxUploads => _allRows.fold<int>(0, (m, r) => r.uploads > m ? r.uploads : m);

  void _clearFilters() {
    _filters.nameQuery = '';
    _filters.skillFilter = null;
    _filters.statusFilter = null;
    _filters.sort = RankingSort.rank;
    _nameSearch.clear();
    _pagination.reset();
    setState(() {});
  }

  Future<void> _saveRemarks(MemberRankingRow row, String remarks) async {
    await adminApi.updateRankingRemarks(row.id, remarks);
    await _load();
    _snack('Remarks saved');
  }

  void _snack(String msg) => AdminToast.show(context, msg);

  void _exportReport() {
    final buf = StringBuffer(
      'Rank,Member,Skill,Points,Uploads,Avg Quality,AI Summary,Status,Last Activity,Remarks\n',
    );
    for (final r in _filtered) {
      buf.writeln(
        '${r.rank},"${r.memberName}",${r.skillLevel},${r.points},${r.uploads},'
        '${r.qualityPercent},"${r.aiResultSummary}",${r.participationStatus.name},'
        '"${formatLastActivity(r.lastActivity)}","${(r.adminRemarks ?? '').replaceAll('"', '""')}"',
      );
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export ranking report'),
        content: SizedBox(
          width: AdminBreakpoints.panelMaxWidth(ctx),
          child: SelectableText(buf.toString(), style: const TextStyle(fontSize: 11)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: buf.toString()));
              Navigator.pop(ctx);
              _snack('Report copied to clipboard');
            },
            child: const Text('Copy CSV'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AdminSessionScope.of(context);
    final filtered = _filtered;
    final pageRows = _pagination.slice(filtered);
    final canExport = session.role.can(AdminCapability.exportData);

    return AdminFeaturePage(
      title: 'Member Rankings',
      subtitle: 'Monitor member rankings, skills, and participation progress.',
      breadcrumbs: breadcrumbsForRoute(AdminRoute.rankings),
      lastUpdated: _lastUpdated,
      loading: _loading,
      error: _error,
      errorTitle: 'Unable to load member rankings',
      onRetry: _load,
      actions: [
        PageHeaderButton(
          label: _showFilters ? 'Hide filters' : 'Filter members',
          icon: _showFilters ? Icons.filter_list_off : Icons.filter_list,
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        PageHeaderButton(
          label: 'Export report',
          icon: Icons.download_outlined,
          onPressed: canExport ? _exportReport : null,
          enabled: canExport,
        ),
        PageHeaderRefreshButton(onPressed: _load),
      ],
      filter: _showFilters
          ? SearchFilterCard(
              child: RankingFilterBar(
                filters: _filters,
                nameController: _nameSearch,
                visible: true,
                onChanged: () {
                  _pagination.reset();
                  setState(() {});
                },
                onClear: _clearFilters,
              ),
            )
          : null,
      body: DataTableCard(
        title: 'Member leaderboard',
        shownCount: pageRows.length,
        totalCount: filtered.length,
        pagination: _pagination,
        rangeLabel: _pagination.rangeLabel(filtered.length),
        onPageChanged: (p) => setState(() => _pagination.page = p),
        onPageSizeChanged: (size) => setState(() {
          _pagination.pageSize = size;
          _pagination.reset();
        }),
        emptyTitle: 'No ranked members found',
        emptyMessage: 'Members will appear here once they earn points.',
        emptyIcon: Icons.leaderboard_outlined,
        emptyActionLabel: _allRows.isEmpty ? 'Refresh' : 'Clear filters',
        onEmptyAction: _allRows.isEmpty ? _load : _clearFilters,
        minHeight: 280,
        child: MemberRankingTable(
          rows: pageRows,
          maxPoints: _maxPoints > 0 ? _maxPoints : 1,
          maxUploads: _maxUploads > 0 ? _maxUploads : 1,
          onViewDetails: (r) => MemberRankingDetailsDialog.show(
            context,
            row: r,
            onSave: (remarks) => _saveRemarks(r, remarks),
          ),
        ),
      ),
    );
  }
}
