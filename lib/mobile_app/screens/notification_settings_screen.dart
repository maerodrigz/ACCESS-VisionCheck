import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/sheets/notifications_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

/// Member notification category preferences (`GET/PATCH /notifications/preferences`).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _evaluationFeedback = true;
  bool _eventCalendar = true;
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
        _evaluationFeedback = prefs['evaluation_feedback'] as bool? ?? true;
        _eventCalendar = prefs['event_calendar'] as bool? ?? true;
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
    bool? evaluationFeedback,
    bool? eventCalendar,
    bool? systemAnnouncements,
  }) async {
    if (_saving) return;

    final previous = (
      evaluationFeedback: _evaluationFeedback,
      eventCalendar: _eventCalendar,
      systemAnnouncements: _systemAnnouncements,
    );

    setState(() {
      if (evaluationFeedback != null) _evaluationFeedback = evaluationFeedback;
      if (eventCalendar != null) _eventCalendar = eventCalendar;
      if (systemAnnouncements != null) _systemAnnouncements = systemAnnouncements;
      _saving = true;
      _error = null;
    });

    try {
      final updated = await memberApiService.updateNotificationPreferences(
        evaluationFeedback: evaluationFeedback,
        eventCalendar: eventCalendar,
        systemAnnouncements: systemAnnouncements,
      );
      if (!mounted) return;
      setState(() {
        _evaluationFeedback = updated['evaluation_feedback'] as bool? ?? _evaluationFeedback;
        _eventCalendar = updated['event_calendar'] as bool? ?? _eventCalendar;
        _systemAnnouncements =
            updated['system_announcements'] as bool? ?? _systemAnnouncements;
        _saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _evaluationFeedback = previous.evaluationFeedback;
        _eventCalendar = previous.eventCalendar;
        _systemAnnouncements = previous.systemAnnouncements;
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _evaluationFeedback = previous.evaluationFeedback;
        _eventCalendar = previous.eventCalendar;
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
          icon: const Icon(Icons.arrow_back_rounded, color: kDashTextPrimary),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: kMemberDashboardAccent),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMemberDashboardAccent))
          : RefreshIndicator(
              color: kMemberDashboardAccent,
              onRefresh: _loadPreferences,
              child: ListView(
                padding: mobileScrollPadding(context, top: 12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kRedDim,
                        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                        border: Border.all(color: kRed.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: kRed, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: dashText(const TextStyle(color: kRed, fontSize: 13, height: 1.35)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const AccessSectionHeader(title: 'In-app alerts'),
                  const SizedBox(height: 12),
                  MemberDashboardCard(
                    showAccentStrip: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _PreferenceSwitch(
                          icon: Icons.insights_outlined,
                          title: 'Evaluation feedback',
                          description:
                              'Milestones, admin review outcomes, integrity alerts, and evaluation updates',
                          value: _evaluationFeedback,
                          enabled: !_saving,
                          onChanged: (v) => _updatePreference(evaluationFeedback: v),
                        ),
                        const Divider(height: 1, indent: 56),
                        _PreferenceSwitch(
                          icon: Icons.event_outlined,
                          title: 'Event & calendar',
                          description: 'Task assignments and event coverage updates',
                          value: _eventCalendar,
                          enabled: !_saving,
                          onChanged: (v) => _updatePreference(eventCalendar: v),
                        ),
                        const Divider(height: 1, indent: 56),
                        _PreferenceSwitch(
                          icon: Icons.campaign_outlined,
                          title: 'System announcements',
                          description: 'Platform alerts and admin announcements',
                          value: _systemAnnouncements,
                          enabled: !_saving,
                          onChanged: (v) => _updatePreference(systemAnnouncements: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'These settings control which in-app notifications ACCESS VisionCheck delivers to your account.',
                    style: memberDashboardMetaStyle.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _InboxLink(
                    enabled: !_saving,
                    onTap: () => showNotifications(context),
                  ),
                ],
              ),
            ),
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
              color: kMemberDashboardAccentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kMemberDashboardAccent, size: 20),
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
            activeTrackColor: kMemberDashboardAccent.withValues(alpha: 0.45),
            activeThumbColor: kMemberDashboardAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _InboxLink extends StatelessWidget {
  const _InboxLink({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(color: kDashBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: kMemberDashboardAccent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('View notification inbox', style: memberDashboardCardTitleStyle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('See alerts you have already received', style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kDashTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
