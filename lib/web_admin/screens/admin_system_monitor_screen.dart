import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/widgets/access_branded_loading.dart';
import 'package:access_mobile/shared/widgets/access_logo.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_shell_scaffold.dart';

class AdminSystemMonitorScreen extends StatefulWidget {
  const AdminSystemMonitorScreen({super.key});

  @override
  State<AdminSystemMonitorScreen> createState() => _AdminSystemMonitorScreenState();
}

class _AdminSystemMonitorScreenState extends State<AdminSystemMonitorScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await adminApi.systemMonitor();
      if (mounted) setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = _data?['database'] as Map<String, dynamic>?;
    final counts = _data?['table_counts'] as Map<String, dynamic>?;
    final logs = _data?['audit_logs'] as List<dynamic>? ?? [];

    return AdminShellScaffold(
      title: 'System Monitor',
      subtitle: 'API health, PostgreSQL, table counts, audit_logs.',
      actions: [PageHeaderRefreshButton(onPressed: _load, enabled: !_loading)],
      child: _loading
          ? const AccessBrandedLoading(message: 'Loading system status…', logoSize: 64)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatusChip(
                        label: 'API',
                        ok: _data?['api_status'] == 'ok',
                        detail: '${_data?['response_ms'] ?? 0} ms',
                      ),
                      _StatusChip(
                        label: 'PostgreSQL',
                        ok: db?['connected'] == true,
                        detail: db?['name'] as String? ?? '',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('URL: ${_data?['public_url'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  if (db?['error'] != null)
                    Text('DB error: ${db!['error']}', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  const Text('Table counts', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (counts != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: counts.entries
                          .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  const Text('Recent audit log', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...logs.map((raw) {
                    final log = raw as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text(log['action'] as String? ?? ''),
                      subtitle: Text('${log['user_name']} · ${log['description'] ?? ''}'),
                      trailing: Text(
                        (log['created_at'] as String? ?? '').length > 19
                            ? (log['created_at'] as String).substring(0, 19)
                            : log['created_at'] as String? ?? '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AdminTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminTheme.border),
                    ),
                    child: Row(
                      children: [
                        const AccessLogoImage(size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brandingController.appName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                brandingController.shortTagline,
                                style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                brandingController.organization,
                                style: const TextStyle(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok, required this.detail});
  final String label;
  final bool ok;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ok ? Colors.green : Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(ok ? 'OK' : 'FAIL', style: TextStyle(color: ok ? Colors.green : Colors.red)),
          Text(detail, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
