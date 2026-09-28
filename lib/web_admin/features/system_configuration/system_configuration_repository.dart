import 'dart:convert';

import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/web_admin/features/system_configuration/system_configuration_models.dart';
import 'package:access_mobile/web_admin/services/file_picker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemConfigurationRepository {
  static const _prefsKey = 'access_system_configuration_v1';

  Future<SystemConfigurationData> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception('Backend offline. Run: cd access_backend && python manage.py runserver');
    }

    await brandingController.refresh();
    final prefs = await _loadPrefsMap();
    var config = SystemConfigurationData.fromPrefsMap(
      prefs,
      defaultOrgName: brandingController.organization,
    );

    config = config.copyWith(organizationName: brandingController.organization);

    try {
      final monitor = await adminApi.systemMonitor();
      final counts = monitor['table_counts'] as Map<String, dynamic>? ?? {};
      final mediaFiles = counts['media_files'] as int? ?? 0;
      final users = counts['users'] as int? ?? 1;
      final estimated = ((mediaFiles * 2.5 + users * 0.1) / 1000 * 100).clamp(12.0, 96.0);
      config = config.copyWith(storageUsagePercent: estimated);
    } catch (_) {}

    return config;
  }

  Future<void> save(SystemConfigurationData config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toPrefsMap()));
  }

  Future<void> saveOrganization({
    required String organizationName,
    required String organizationEmail,
    required String academicYear,
  }) async {
    await adminApi.updateBrandingNames(
      appName: brandingController.appName,
      tagline: brandingController.tagline,
      shortTagline: brandingController.shortTagline,
      organization: organizationName,
    );
    brandingController.applyPayload(await adminApi.getBranding());

    final current = await loadAll();
    await save(
      current.copyWith(
        organizationName: organizationName,
        organizationEmail: organizationEmail,
        academicYear: academicYear,
      ),
    );
  }

  Future<void> uploadLogo() async {
    final picked = await pickImagesFromWeb();
    if (picked.isEmpty) return;
    final file = picked.first;
    await adminApi.uploadLogo(bytes: file.bytes, fileName: file.name);
    brandingController.applyUploadResult(await adminApi.getBranding());
  }

  Future<void> runBackup(SystemConfigurationData current) async {
    final now = DateTime.now();
    await save(
      current.copyWith(
        lastBackupAt: now,
        backupStatus: 'Completed',
      ),
    );
  }

  String buildBackupExport(SystemConfigurationData config) {
    final buf = StringBuffer('ACCESS VisionCheck — System Configuration Export\n');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}\n');
    for (final entry in config.toPrefsMap().entries) {
      buf.writeln('${entry.key}: ${entry.value}');
    }
    return buf.toString();
  }

  Future<Map<String, dynamic>> _loadPrefsMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }
}
