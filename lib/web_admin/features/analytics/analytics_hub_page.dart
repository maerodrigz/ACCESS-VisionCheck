import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/web_admin/features/analytics/analytics_compute.dart';
import 'package:access_mobile/web_admin/features/analytics/analytics_models.dart';
import 'package:access_mobile/web_admin/features/analytics/widgets/analytics_dashboard_panel.dart';
import 'package:access_mobile/web_admin/features/analytics/widgets/analytics_panels.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/config/admin_permissions.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/utils/admin_toast.dart';

/// Analytics hub — dashboard-first layout matching the reference mockup.
class AnalyticsHubPage extends StatefulWidget {
  const AnalyticsHubPage({super.key});

  @override
  State<AnalyticsHubPage> createState() => _AnalyticsHubPageState();
}

class _AnalyticsHubPageState extends State<AnalyticsHubPage> {
  AnalyticsTab _tab = AnalyticsTab.overview;
  AnalyticsSnapshot? _data;
  bool _loading = true;
  String? _error;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  bool get _isDashboardOnly => _tab == AnalyticsTab.overview;

  @override
  void initState() {
    super.initState();
    final (start, end) = currentMonthRange();
    _rangeStart = start;
    _rangeEnd = end;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRouteIntent());
    _load();
  }

  void _applyRouteIntent() {
    final params = AdminNavigationScope.consumeParams(context, AdminRoute.analyticsDashboard) ??
        AdminNavigationScope.consumeParams(context, AdminRoute.participationReports) ??
        AdminNavigationScope.consumeParams(context, AdminRoute.feedbackReports);
    if (params == null) return;

    setState(() {
      if (params['analyticsTab'] != null) {
        _tab = analyticsTabFromString(params['analyticsTab'] as String?);
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await AnalyticsSnapshot.fetch();
      if (mounted) {
        setState(() {
          _data = snapshot;
          _loading = false;
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      builder: (context, child) => Theme(data: AdminTheme.materialTheme(), child: child!),
    );
    if (picked != null && mounted) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
    }
  }

  void _exportReport() {
    if (_data == null) return;
    final csv = buildAnalyticsExportCsv(_data!, _rangeStart, _rangeEnd);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export analytics report'),
        content: SizedBox(
          width: AdminBreakpoints.panelMaxWidth(ctx),
          child: SelectableText(csv, style: const TextStyle(fontSize: 11)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.pop(ctx);
              AdminToast.show(context, 'Report copied to clipboard');
            },
            child: const Text('Copy CSV'),
          ),
        ],
      ),
    );
  }

  void _viewAllActivity() {
    AdminNavigationScope.go(context, AdminRoute.docRequests);
  }

  @override
  Widget build(BuildContext context) {
    final session = AdminSessionScope.of(context);
    final canExport = session.role.can(AdminCapability.exportData);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AdminBreakpoints.pagePadding(context).copyWith(bottom: 0, top: 8),
            child: PageHeader(
              title: _isDashboardOnly ? 'Analytics Dashboard' : analyticsTabLabel(_tab),
              subtitle: _isDashboardOnly
                  ? 'Overview of system performance and multimedia documentation insights'
                  : 'Detailed ${analyticsTabLabel(_tab).toLowerCase()} metrics from your database.',
              breadcrumbs: const [],
              lastUpdated: null,
              actions: [
                if (_isDashboardOnly) ...[
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(formatMonthRange(_rangeStart, _rangeEnd), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: canExport && _data != null ? _exportReport : null,
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
                ],
                PageHeaderRefreshButton(onPressed: _load),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: AdminBreakpoints.pagePadding(context).copyWith(top: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AdminTheme.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: AdminBreakpoints.pagePadding(context).copyWith(top: 8),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? const Center(child: Text('No analytics data'))
                      : _panelFor(_data!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelFor(AnalyticsSnapshot data) {
    if (_tab == AnalyticsTab.overview) {
      return AnalyticsDashboardPanel(
        data: data,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        onViewAllActivity: _viewAllActivity,
      );
    }
    return switch (_tab) {
      AnalyticsTab.participation => AnalyticsParticipationPanel(data: data),
      AnalyticsTab.events => AnalyticsEventsPanel(data: data),
      AnalyticsTab.rankings => AnalyticsRankingsPanel(data: data),
      AnalyticsTab.feedback => AnalyticsFeedbackPanel(data: data),
      AnalyticsTab.media => AnalyticsMediaPanel(data: data),
      AnalyticsTab.overview => AnalyticsDashboardPanel(data: data, rangeStart: _rangeStart, rangeEnd: _rangeEnd),
    };
  }
}
