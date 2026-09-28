import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/services/facebook_open_url.dart';
import 'package:access_mobile/web_admin/features/ai_detection/ai_detection_models.dart';
import 'package:access_mobile/web_admin/features/ai_detection/widgets/ai_detection_details_dialog.dart';
import 'package:access_mobile/web_admin/features/ai_detection/widgets/ai_detection_filter_bar.dart';
import 'package:access_mobile/web_admin/features/ai_detection/widgets/ai_detection_result_list.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/media_evaluation_models.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_feature_page.dart';
import 'package:access_mobile/web_admin/layout/admin_route_breadcrumbs.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/layout/pagination_state.dart';
import 'package:access_mobile/web_admin/layout/search_filter_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Admin AI Detection Results — fair review workflow for flagged media.
class AiDetectionResultsPage extends StatefulWidget {
  const AiDetectionResultsPage({super.key});

  @override
  State<AiDetectionResultsPage> createState() => _AiDetectionResultsPageState();
}

class _AiDetectionResultsPageState extends State<AiDetectionResultsPage> {
  List<AiDetectionRow> _allRows = [];
  AiDetectionSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _showFilters = true;
  DateTime? _lastUpdated;
  Timer? _autoRefresh;
  final _pagination = PaginationState();
  final _filters = AiDetectionFilters();
  final _mediaSearch = TextEditingController();
  final _memberSearch = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load(silent: false);
    _autoRefresh = Timer.periodic(const Duration(seconds: 45), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _mediaSearch.dispose();
    _memberSearch.dispose();
    super.dispose();
  }

  Future<void> _load({required bool silent}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // PostgreSQL ai_detection_results via GET /api/admin/ai-detection
      final list = await adminApi.allAiDetection();
      Map<String, dynamic> summaryMap = {};
      try {
        summaryMap = await adminApi.aiDetectionSummary();
      } catch (_) {}
      final rows = list.map(AiDetectionRow.fromMap).toList();

      if (mounted) {
        setState(() {
          _allRows = rows;
          _summary = summaryMap.isNotEmpty
              ? AiDetectionSummary.fromMap(summaryMap)
              : _summaryFromRows(rows);
          _loading = false;
          _lastUpdated = DateTime.now();
          if (!silent) _pagination.reset();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _allRows = [];
          _summary = const AiDetectionSummary(
            totalScanned: 0,
            humanCount: 0,
            aiGeneratedCount: 0,
            suspiciousCount: 0,
            pendingReviewCount: 0,
          );
          _loading = false;
          _lastUpdated = DateTime.now();
        });
      }
    }
  }

  AiDetectionSummary _summaryFromRows(List<AiDetectionRow> rows) {
    var human = 0, ai = 0, suspicious = 0, pending = 0;
    for (final r in rows) {
      switch (r.aiLabel) {
        case AiResultLabel.human:
          human++;
        case AiResultLabel.aiGenerated:
          ai++;
        case AiResultLabel.suspicious:
          suspicious++;
        default:
          break;
      }
      if (r.reviewStatus == ReviewStatus.pendingReview ||
          r.reviewStatus == ReviewStatus.needsFurtherReview) {
        pending++;
      }
    }
    return AiDetectionSummary(
      totalScanned: rows.length,
      humanCount: human,
      aiGeneratedCount: ai,
      suspiciousCount: suspicious,
      pendingReviewCount: pending,
    );
  }

  List<AiDetectionRow> get _filtered {
    return _allRows.where((r) {
      if (_filters.mediaQuery.isNotEmpty &&
          !r.mediaName.toLowerCase().contains(_filters.mediaQuery.toLowerCase())) {
        return false;
      }
      if (_filters.memberQuery.isNotEmpty &&
          !r.memberName.toLowerCase().contains(_filters.memberQuery.toLowerCase())) {
        return false;
      }
      if (_filters.reviewStatusFilter != null && r.reviewStatus != _filters.reviewStatusFilter) {
        return false;
      }
      if (_filters.aiFilter != null && r.aiLabel != _filters.aiFilter) {
        return false;
      }
      if (_filters.confidenceFilter != null && r.confidenceLevel != _filters.confidenceFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    _filters.mediaQuery = '';
    _filters.memberQuery = '';
    _filters.aiFilter = null;
    _filters.confidenceFilter = null;
    _filters.reviewStatusFilter = null;
    _mediaSearch.clear();
    _memberSearch.clear();
    _pagination.reset();
    setState(() {});
  }

  Future<void> _saveReview(AiDetectionRow row, ReviewStatus status, String remarks) async {
    await adminApi.updateAiDetectionReview(
      row.id,
      reviewStatus: reviewStatusToApi(status),
      adminRemarks: remarks,
    );
    await _load(silent: true);
    _snack('Review saved — member notified');
  }

  Future<List<AiReviewHistoryEntry>> _loadHistory(int aiId) async {
    final list = await adminApi.aiReviewHistory(aiId);
    return list.map(AiReviewHistoryEntry.fromMap).toList();
  }

  Future<void> _archive(AiDetectionRow row) async {
    final ok = await _confirm(
      'Archive "${row.mediaName}"?',
      'Media will be moved to archives.',
      icon: Icons.archive_outlined,
    );
    if (ok != true) return;
    await adminApi.archiveAiDetectionMedia(row.id);
    await _load(silent: true);
    _snack('Media archived');
  }

  Future<void> _reviewMedia(AiDetectionRow row) async {
    final url = AdminApiService.mediaUrl(row.mediaUrl.isNotEmpty ? row.mediaUrl : null);
    if (url.isEmpty) {
      _snack('No media URL available');
      return;
    }
    await openExternalUrl(url);
  }

  void _openDetails(AiDetectionRow row) {
    AiReviewDetailsDialog.show(
      context,
      row: row,
      usingSample: false,
      loadHistory: _loadHistory,
      onSave: (status, remarks) => _saveReview(row, status, remarks),
      onArchive: () => _archive(row),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirm(String title, String body, {IconData icon = Icons.help_outline}) {
    return ConfirmDialog.show(context, title: title, message: body, icon: icon);
  }

  void _exportReport() {
    final buf = StringBuffer(
      'Media,Member,AI Result,Confidence %,Confidence Level,Review Status,Scanned,Remarks\n',
    );
    for (final r in _filtered) {
      buf.writeln(
        '"${r.mediaName}","${r.memberName}",${r.aiLabel.name},'
        '${(r.confidenceScore * 100).round()},${r.confidenceLevel.name},'
        '${r.statusLabel},"${formatScannedDate(r.scannedAt)}",'
        '"${(r.adminRemarks ?? '').replaceAll('"', '""')}"',
      );
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export AI detection report'),
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

  int _statusCount(ReviewStatus s) => _allRows.where((r) => r.reviewStatus == s).length;

  @override
  Widget build(BuildContext context) {
    final session = AdminSessionScope.of(context);
    final filtered = _filtered;
    final pageRows = _pagination.slice(filtered);
    final canExport = session.role.can(AdminCapability.exportData);
    final canArchive = session.role.can(AdminCapability.archiveRecords);

    return AdminFeaturePage(
      title: 'AI Detection Results',
      subtitle:
          'Review flagged media fairly — verify, request reupload, or confirm only after manual check.',
      breadcrumbs: breadcrumbsForRoute(AdminRoute.aiDetection),
      lastUpdated: _lastUpdated,
      loading: _loading,
      error: _error,
      errorTitle: 'Unable to load AI detection results',
      onRetry: () => _load(silent: false),
      actions: [
        PageHeaderButton(
          label: _showFilters ? 'Hide filters' : 'Filter results',
          icon: _showFilters ? Icons.filter_list_off : Icons.filter_list,
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        PageHeaderButton(
          label: 'Export report',
          icon: Icons.download_outlined,
          onPressed: canExport ? _exportReport : null,
          enabled: canExport,
        ),
        PageHeaderRefreshButton(onPressed: () => _load(silent: false)),
      ],
      filter: _showFilters
          ? SearchFilterCard(
              child: AiDetectionFilterBar(
                filters: _filters,
                mediaSearchController: _mediaSearch,
                memberSearchController: _memberSearch,
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
        title: 'Detection results',
        shownCount: pageRows.length,
        totalCount: filtered.length,
        pagination: _pagination,
        rangeLabel: _pagination.rangeLabel(filtered.length),
        onPageChanged: (p) => setState(() => _pagination.page = p),
        onPageSizeChanged: (size) => setState(() {
          _pagination.pageSize = size;
          _pagination.reset();
        }),
        emptyTitle: 'No AI detection results found',
        emptyMessage: 'Scanned media results will appear here after checking.',
        emptyIcon: Icons.smart_toy_outlined,
        emptyActionLabel: _allRows.isEmpty ? 'Refresh' : 'Clear filters',
        onEmptyAction: _allRows.isEmpty ? () => _load(silent: false) : _clearFilters,
        minHeight: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: AiDetectionResultList(
            rows: pageRows,
            onViewDetails: _openDetails,
            onReview: _reviewMedia,
            onQuickAction: _saveReview,
            onConfirm: _confirm,
            onArchive: canArchive ? _archive : null,
          ),
        ),
      ),
    );
  }
}
