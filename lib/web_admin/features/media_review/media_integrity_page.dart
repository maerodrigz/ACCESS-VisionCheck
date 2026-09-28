import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_repository.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/integrity_alert_card.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/integrity_overview_cards.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/integrity_review_drawer.dart';
import 'package:access_mobile/web_admin/features/media_review/widgets/warning_modal.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Media Integrity Dashboard — detect, review, and respond to potentially AI-generated documentation.
class MediaIntegrityPage extends StatefulWidget {
  const MediaIntegrityPage({super.key});

  @override
  State<MediaIntegrityPage> createState() => _MediaIntegrityPageState();
}

class _MediaIntegrityPageState extends State<MediaIntegrityPage> {
  final _repo = MediaIntegrityRepository();
  final _searchController = TextEditingController();

  IntegrityDashboardData? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  IntegrityAlertStatus? _statusFilter;
  IntegrityAlertLevel? _levelFilter;

  IntegrityAlert? _selectedAlert;
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
          if (_selectedAlert != null) {
            final id = _selectedAlert!.id;
            _selectedAlert = data.alerts.where((a) => a.id == id).firstOrNull ?? _selectedAlert;
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

  List<IntegrityAlert> get _visible {
    final data = _data;
    if (data == null) return [];
    return _repo.filterAlerts(
      alerts: data.alerts,
      search: _search,
      statusFilter: _statusFilter,
      levelFilter: _levelFilter,
    );
  }

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _openReview(IntegrityAlert alert) {
    setState(() {
      _selectedAlert = alert;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() => setState(() => _drawerOpen = false);

  Future<void> _exportReport() async {
    final data = _data;
    if (data == null) return;
    await Clipboard.setData(ClipboardData(text: _repo.buildExportReport(data)));
    _toast('Integrity report copied to clipboard');
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Filter alerts', style: TextStyle(fontWeight: FontWeight.w700))),
            ListTile(
              title: const Text('All statuses'),
              trailing: _statusFilter == null ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _statusFilter = null);
              },
            ),
            for (final s in IntegrityAlertStatus.values)
              ListTile(
                title: Text(s.label),
                trailing: _statusFilter == s ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _statusFilter = s);
                },
              ),
            const Divider(),
            const ListTile(title: Text('Alert level', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final l in IntegrityAlertLevel.values)
              ListTile(
                title: Text('${l.emoji} ${l.label}'),
                trailing: _levelFilter == l ? const Icon(Icons.check, color: AdminTheme.accentBlue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _levelFilter = _levelFilter == l ? null : l);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDismiss() async {
    final alert = _selectedAlert;
    if (alert == null) return;
    await _repo.dismissAlert(alert, notes: alert.adminNotes);
    _closeDrawer();
    await _load();
    _toast('Alert dismissed — no action taken against member');
  }

  Future<void> _handleReject() async {
    final alert = _selectedAlert;
    if (alert == null) return;
    await _repo.confirmViolation(alert, notes: alert.adminNotes);
    _closeDrawer();
    await _load();
    _toast('Submission marked as confirmed violation');
  }

  Future<void> _handleMonitoring() async {
    final alert = _selectedAlert;
    if (alert == null) return;
    await _repo.keepUnderMonitoring(alert);
    _closeDrawer();
    await _load();
    _toast('${alert.memberName} kept under monitoring');
  }

  Future<void> _handleSendWarning() async {
    final alert = _selectedAlert;
    if (alert == null) return;
    final suggested = await _repo.suggestWarningLevel(alert.memberId);
    if (!mounted) return;
    final result = await SendWarningModal.show(context, suggestedLevel: suggested);
    if (result == null) return;
    await _repo.sendWarning(
      alert: alert,
      level: result.level,
      reason: result.reason.isEmpty ? kDefaultWarningReason : result.reason,
      message: result.message,
    );
    _closeDrawer();
    await _load();
    _toast('${result.level.label} sent to ${alert.memberName}');
  }

  @override
  Widget build(BuildContext context) {
    final padding = AdminBreakpoints.pagePadding(context);
    final alerts = _visible;
    final record = _selectedAlert != null ? _data?.memberRecords[_selectedAlert!.memberId] : null;

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Media Integrity',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Protect documentation authenticity — review AI detection flags and verify evidence before any action.',
                                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _data == null ? null : _exportReport,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Export Report'),
                        ),
                        const SizedBox(width: 8),
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
                              hintText: 'Search member, event, role, status, date…',
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
                        OutlinedButton.icon(onPressed: _showFilterSheet, icon: const Icon(Icons.filter_list, size: 18), label: const Text('Filter')),
                      ],
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
                                if (_data != null) IntegrityOverviewCards(stats: _data!.stats),
                                const SizedBox(height: 24),
                                const Text('Review Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Each alert flags potentially AI-generated media. Review evidence manually — the system never penalizes members automatically.',
                                  style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                if (alerts.isEmpty)
                                  const AdminEmptyState(
                                    title: 'No integrity alerts',
                                    message: 'When the AI detection model flags potentially AI-generated photos or videos, they will appear here for administrator review.',
                                    icon: Icons.verified_user_outlined,
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final cols = c.maxWidth >= 1100 ? 2 : 1;
                                      if (cols == 1) {
                                        return Column(
                                          children: [
                                            for (final a in alerts) ...[
                                              IntegrityAlertCard(alert: a, onReview: () => _openReview(a)),
                                              const SizedBox(height: 14),
                                            ],
                                          ],
                                        );
                                      }
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                          childAspectRatio: 0.88,
                                        ),
                                        itemCount: alerts.length,
                                        itemBuilder: (_, i) => IntegrityAlertCard(alert: alerts[i], onReview: () => _openReview(alerts[i])),
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
          IntegrityReviewDrawer(
            alert: _selectedAlert,
            memberRecord: record,
            open: _drawerOpen,
            onClose: _closeDrawer,
            onDismiss: _handleDismiss,
            onSendWarning: _handleSendWarning,
            onReject: _handleReject,
            onKeepMonitoring: _handleMonitoring,
            onNotesChanged: (text) {
              if (_selectedAlert != null) _repo.setAlertNotes(_selectedAlert!.id, text);
            },
          ),
        ],
      ),
    );
  }
}
