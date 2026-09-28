import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/widgets/access_logo.dart';
import 'package:access_mobile/web_admin/features/system_configuration/system_configuration_models.dart';
import 'package:access_mobile/web_admin/features/system_configuration/system_configuration_repository.dart';
import 'package:access_mobile/web_admin/features/system_configuration/widgets/system_config_cards.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// System Configuration — administrator-only platform settings.
class SystemConfigurationPage extends StatefulWidget {
  const SystemConfigurationPage({super.key});

  @override
  State<SystemConfigurationPage> createState() => _SystemConfigurationPageState();
}

class _SystemConfigurationPageState extends State<SystemConfigurationPage> {
  final _repo = SystemConfigurationRepository();

  SystemConfigurationData? _config;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  late final TextEditingController _orgNameCtrl;
  late final TextEditingController _orgEmailCtrl;
  late final TextEditingController _academicYearCtrl;

  @override
  void initState() {
    super.initState();
    _orgNameCtrl = TextEditingController();
    _orgEmailCtrl = TextEditingController();
    _academicYearCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _orgEmailCtrl.dispose();
    _academicYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _config = config;
          _orgNameCtrl.text = config.organizationName;
          _orgEmailCtrl.text = config.organizationEmail;
          _academicYearCtrl.text = config.academicYear;
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

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _confirmSave() => confirmSaveChanges(context);

  Future<void> _saveConfig(SystemConfigurationData updated, {String? message}) async {
    if (!await _confirmSave()) return;
    setState(() => _busy = true);
    try {
      await _repo.save(updated);
      if (mounted) {
        setState(() {
          _config = updated;
          _busy = false;
        });
        _toast(message ?? 'Settings saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.toString(), success: false);
      }
    }
  }

  void _patch(SystemConfigurationData Function(SystemConfigurationData c) fn) {
    final c = _config;
    if (c == null) return;
    setState(() {
      _config = fn(c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AdminSessionScope.maybeOf(context);
    if (user != null && !user.role.isAdmin) {
      return const _AccessDenied();
    }

    final padding = AdminBreakpoints.pagePadding(context);
    final config = _config;

    return Container(
      color: AdminTheme.contentBg,
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
              : config == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, c) {
                              final wide = c.maxWidth >= 980;
                              return GridView.count(
                                crossAxisCount: wide ? 2 : 1,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: wide ? 0.92 : 0.88,
                                children: [
                                  _organizationCard(config),
                                  _documentationCard(config),
                                  _integrityCard(config),
                                  _notificationCard(config),
                                  _securityCard(config),
                                  _backupCard(config),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Configuration',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
              ),
              SizedBox(height: 6),
              Text(
                'Configure system-wide settings and administrative preferences for ACCESS VisionCheck.',
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        PageHeaderRefreshButton(onPressed: _load),
      ],
    );
  }

  Widget _organizationCard(SystemConfigurationData config) {
    return ConfigCategoryCard(
      icon: Icons.apartment_outlined,
      title: 'Organization Information',
      subtitle: 'Institution identity shown across the platform.',
      primaryActionLabel: 'Edit Information',
      busy: _busy,
      onPrimaryAction: () async {
        if (!await _confirmSave()) return;
        setState(() => _busy = true);
        try {
          await _repo.saveOrganization(
            organizationName: _orgNameCtrl.text.trim(),
            organizationEmail: _orgEmailCtrl.text.trim(),
            academicYear: _academicYearCtrl.text.trim(),
          );
          await _load();
          _toast('Organization information updated');
        } catch (e) {
          _toast(e.toString(), success: false);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListenableBuilder(
            listenable: brandingController,
            builder: (_, __) => Row(
              children: [
                const AccessLogoImage(size: 56),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            await _repo.uploadLogo();
                            _toast('Organization logo updated');
                          } catch (e) {
                            _toast(e.toString(), success: false);
                          }
                        },
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: const Text('Upload Logo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _orgNameCtrl, decoration: const InputDecoration(labelText: 'Organization Name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _orgEmailCtrl, decoration: const InputDecoration(labelText: 'Organization Email', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _academicYearCtrl, decoration: const InputDecoration(labelText: 'Academic Year', border: OutlineInputBorder())),
        ],
      ),
    );
  }

  Widget _documentationCard(SystemConfigurationData config) {
    return ConfigCategoryCard(
      icon: Icons.description_outlined,
      title: 'Documentation Policies',
      subtitle: 'Rules for media uploads and publishing workflows.',
      primaryActionLabel: 'Save Changes',
      busy: _busy,
      onPrimaryAction: () => _saveConfig(config, message: 'Documentation policies saved'),
      child: Column(
        children: [
          ConfigToggleRow(
            label: 'Allow Late Media Uploads',
            subtitle: 'Permit uploads after the event completion window.',
            value: config.allowLateMediaUploads,
            onChanged: (v) => _patch((c) => c.copyWith(allowLateMediaUploads: v)),
          ),
          ConfigNumberField(
            label: 'Maximum Upload Period (Days)',
            value: config.maxUploadPeriodDays,
            suffix: 'days',
            onChanged: (v) => _patch((c) => c.copyWith(maxUploadPeriodDays: v.clamp(1, 90))),
          ),
          ConfigToggleRow(
            label: 'Require Event Album Before Upload',
            subtitle: 'Members must create an album before uploading files.',
            value: config.requireEventAlbumBeforeUpload,
            onChanged: (v) => _patch((c) => c.copyWith(requireEventAlbumBeforeUpload: v)),
          ),
          ConfigToggleRow(
            label: 'Enable Facebook Publishing',
            subtitle: 'Allow administrators to publish approved media to Facebook.',
            value: config.enableFacebookPublishing,
            onChanged: (v) => _patch((c) => c.copyWith(enableFacebookPublishing: v)),
          ),
        ],
      ),
    );
  }

  Widget _integrityCard(SystemConfigurationData config) {
    return ConfigCategoryCard(
      icon: Icons.verified_user_outlined,
      title: 'Media Integrity Settings',
      subtitle: 'AI authenticity detection and review alert behavior.',
      primaryActionLabel: 'Save Changes',
      busy: _busy,
      onPrimaryAction: () => _saveConfig(config, message: 'Media integrity settings saved'),
      child: Column(
        children: [
          ConfigToggleRow(
            label: 'Enable AI Detection',
            subtitle: 'Scan uploaded media for possible AI-generated content.',
            value: config.enableAiDetection,
            onChanged: (v) => _patch((c) => c.copyWith(enableAiDetection: v)),
          ),
          ConfigSliderRow(
            label: 'AI Detection Confidence Threshold',
            value: config.aiConfidenceThreshold,
            onChanged: (v) => _patch((c) => c.copyWith(aiConfidenceThreshold: v)),
          ),
          ConfigToggleRow(
            label: 'Automatically Generate Review Alerts',
            subtitle: 'Create integrity alerts when confidence exceeds the threshold.',
            value: config.autoGenerateReviewAlerts,
            onChanged: (v) => _patch((c) => c.copyWith(autoGenerateReviewAlerts: v)),
          ),
          ConfigToggleRow(
            label: 'Require Manual Verification Before Warning',
            subtitle: 'Administrators must confirm before issuing member warnings.',
            value: config.requireManualVerificationBeforeWarning,
            onChanged: (v) => _patch((c) => c.copyWith(requireManualVerificationBeforeWarning: v)),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(SystemConfigurationData config) {
    return ConfigCategoryCard(
      icon: Icons.notifications_outlined,
      title: 'Notification Preferences',
      subtitle: 'System-wide notification channels for administrators.',
      primaryActionLabel: 'Save Preferences',
      busy: _busy,
      onPrimaryAction: () => _saveConfig(config, message: 'Notification preferences saved'),
      child: Column(
        children: [
          ConfigToggleRow(
            label: 'New Documentation Requests',
            value: config.notifyNewDocumentationRequests,
            subtitle: 'Alert when a requester submits a new request.',
            onChanged: (v) => _patch((c) => c.copyWith(notifyNewDocumentationRequests: v)),
          ),
          ConfigToggleRow(
            label: 'Media Integrity Alerts',
            value: config.notifyMediaIntegrityAlerts,
            subtitle: 'Alert when AI detection flags possible issues.',
            onChanged: (v) => _patch((c) => c.copyWith(notifyMediaIntegrityAlerts: v)),
          ),
          ConfigToggleRow(
            label: 'Requester Feedback',
            value: config.notifyRequesterFeedback,
            subtitle: 'Alert when new feedback is submitted.',
            onChanged: (v) => _patch((c) => c.copyWith(notifyRequesterFeedback: v)),
          ),
          ConfigToggleRow(
            label: 'Facebook Publishing Status',
            value: config.notifyFacebookPublishingStatus,
            subtitle: 'Alert on successful or failed Facebook posts.',
            onChanged: (v) => _patch((c) => c.copyWith(notifyFacebookPublishingStatus: v)),
          ),
          ConfigToggleRow(
            label: 'System Notifications',
            value: config.notifySystemNotifications,
            subtitle: 'Backup, maintenance, and platform health alerts.',
            onChanged: (v) => _patch((c) => c.copyWith(notifySystemNotifications: v)),
          ),
        ],
      ),
    );
  }

  Widget _securityCard(SystemConfigurationData config) {
    return ConfigCategoryCard(
      icon: Icons.security_outlined,
      title: 'Security',
      subtitle: 'Authentication and session policies for all accounts.',
      primaryActionLabel: 'Update Security Settings',
      busy: _busy,
      onPrimaryAction: () => _saveConfig(config, message: 'Security settings updated'),
      child: Column(
        children: [
          ConfigNumberField(
            label: 'Minimum Password Length',
            value: config.minPasswordLength,
            suffix: 'chars',
            onChanged: (v) => _patch((c) => c.copyWith(minPasswordLength: v.clamp(6, 32))),
          ),
          ConfigNumberField(
            label: 'Session Timeout',
            value: config.sessionTimeoutMinutes,
            suffix: 'min',
            onChanged: (v) => _patch((c) => c.copyWith(sessionTimeoutMinutes: v.clamp(5, 480))),
          ),
          ConfigNumberField(
            label: 'Account Lockout Duration',
            value: config.accountLockoutMinutes,
            suffix: 'min',
            onChanged: (v) => _patch((c) => c.copyWith(accountLockoutMinutes: v.clamp(5, 1440))),
          ),
          ConfigToggleRow(
            label: 'Two-Factor Authentication',
            subtitle: config.twoFactorEnabled ? 'Enabled for administrator accounts' : 'Not enabled',
            value: config.twoFactorEnabled,
            onChanged: (v) => _patch((c) => c.copyWith(twoFactorEnabled: v)),
          ),
        ],
      ),
    );
  }

  Widget _backupCard(SystemConfigurationData config) {
    return ConfigCategoryCard(
      icon: Icons.cloud_upload_outlined,
      title: 'Backup & Maintenance',
      subtitle: 'Database backup status and storage monitoring.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConfigReadOnlyRow(label: 'Last Database Backup', value: formatConfigDateTime(config.lastBackupAt)),
          ConfigReadOnlyRow(label: 'Backup Status', value: config.backupStatus),
          ConfigReadOnlyRow(label: 'Storage Usage', value: '${config.storageUsagePercent.round()}% of allocated capacity'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!await _confirmSave()) return;
                        setState(() => _busy = true);
                        try {
                          await _repo.runBackup(config);
                          await _load();
                          _toast('Database backup completed');
                        } catch (e) {
                          _toast(e.toString(), success: false);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('Backup Now'),
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final text = _repo.buildBackupExport(config);
                  await Clipboard.setData(ClipboardData(text: text));
                  _toast('Configuration export copied to clipboard');
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download Backup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: AdminTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Administrator access required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'System Configuration is only available to administrators.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
