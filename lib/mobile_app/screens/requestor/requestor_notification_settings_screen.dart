import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/sheets/notifications_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Requestor notification preferences — request updates + announcements only.
class RequestorNotificationSettingsScreen extends StatefulWidget {
  const RequestorNotificationSettingsScreen({super.key});

  @override
  State<RequestorNotificationSettingsScreen> createState() =>
      _RequestorNotificationSettingsScreenState();
}

class _RequestorNotificationSettingsScreenState extends State<RequestorNotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _requestUpdates = true;
  bool _systemAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await memberApiService.getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _requestUpdates = prefs['event_calendar'] as bool? ?? true;
        _systemAnnouncements = prefs['system_announcements'] as bool? ?? true;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notification preferences.';
      });
    }
  }

  Future<void> _updatePreference({
    bool? requestUpdates,
    bool? systemAnnouncements,
  }) async {
    if (_saving) return;

    final previous = (
      requestUpdates: _requestUpdates,
      systemAnnouncements: _systemAnnouncements,
    );

    setState(() {
      if (requestUpdates != null) _requestUpdates = requestUpdates;
      if (systemAnnouncements != null) _systemAnnouncements = systemAnnouncements;
      _saving = true;
      _error = null;
    });

    try {
      final updated = await memberApiService.updateNotificationPreferences(
        eventCalendar: requestUpdates,
        systemAnnouncements: systemAnnouncements,
      );
      if (!mounted) return;
      setState(() {
        _requestUpdates = updated['event_calendar'] as bool? ?? _requestUpdates;
        _systemAnnouncements =
            updated['system_announcements'] as bool? ?? _systemAnnouncements;
        _saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _requestUpdates = previous.requestUpdates;
        _systemAnnouncements = previous.systemAnnouncements;
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestUpdates = previous.requestUpdates;
        _systemAnnouncements = previous.systemAnnouncements;
        _saving = false;
        _error = 'Could not save notification preferences.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMemberDashboardBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Settings',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kMemberPrimary),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const _NotificationSettingsSkeleton()
          : RefreshIndicator(
              color: kMemberPrimary,
              onRefresh: _loadPreferences,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  kMemberDashboardPagePadding,
                  12,
                  kMemberDashboardPagePadding,
                  32,
                ),
                children: [
                  const _NotificationSettingsHero(),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    MemberDashboardCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: kRed, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: memberDashboardBodyStyle.copyWith(color: kRed, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('In-app alerts', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Choose which documentation request alerts you receive in the app.',
                    style: memberDashboardSectionSubtitleStyle,
                  ),
                  const SizedBox(height: 12),
                  MemberDashboardCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _PreferenceSwitch(
                          icon: Icons.description_outlined,
                          title: 'Request status updates',
                          description:
                              'When admins approve, reject, or mark your documentation requests complete',
                          value: _requestUpdates,
                          enabled: !_saving,
                          onChanged: (v) => _updatePreference(requestUpdates: v),
                        ),
                        const Divider(height: 1, indent: 56),
                        _PreferenceSwitch(
                          icon: Icons.campaign_outlined,
                          title: 'System announcements',
                          description: 'Platform notices and admin broadcasts for requestors',
                          value: _systemAnnouncements,
                          enabled: !_saving,
                          onChanged: (v) => _updatePreference(systemAnnouncements: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'These settings apply to in-app notifications on your organization account.',
                    style: memberDashboardMetaStyle.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  MemberDashboardCard(
                    child: InkWell(
                      onTap: _saving ? null : () => showNotifications(context),
                      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: kAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'View notification inbox',
                                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'See alerts about your documentation requests',
                                  style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: kTextSecondary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _NotificationSettingsHero extends StatelessWidget {
  const _NotificationSettingsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: kMemberDashboardAccentGradient,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALERTS',
            style: dashText(const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            )),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage request notifications',
            style: dashText(const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.15,
            )),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay informed when ACCESS reviews your events or sends platform updates.',
            style: dashText(TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            )),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsSkeleton extends StatelessWidget {
  const _NotificationSettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        12,
        kMemberDashboardPagePadding,
        32,
      ),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: kSurfaceAlt,
            borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 14,
          width: 100,
          decoration: BoxDecoration(
            color: kSurfaceAlt,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
            border: Border.all(color: kBorder),
          ),
        ),
      ],
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: kMemberPrimary.withValues(alpha: 0.45),
            activeThumbColor: kMemberPrimary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
