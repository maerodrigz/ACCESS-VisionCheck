import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';
import 'package:access_mobile/mobile_app/widgets/shared_widgets.dart';

/// Read-only campus event detail for requestors (planning calendar only).
void showRequestorCampusEventDetail(BuildContext context, CalendarEvent event) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.event_rounded, color: kCyan, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: memberDashboardSectionTitleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Campus event',
                        style: memberDashboardMetaStyle.copyWith(color: kAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: event.date),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.schedule_outlined,
              label: 'Time',
              value: event.timeLabel ?? 'Time TBA',
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.location_on_outlined, label: 'Location', value: event.location),
            ],
            if (event.description.isNotEmpty && event.description != event.location) ...[
              const SizedBox(height: 16),
              Text('Details', style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                event.description,
                style: memberDashboardBodyStyle.copyWith(fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: requestorMetaIconColor(Icons.info_outline_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For planning only. Pick a lighter day on the calendar, then create your request on the Requests tab.',
                      style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: kMemberButtonPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Read-only event detail sheet for members.
void showMemberEventDetail(
  BuildContext context,
  CalendarEvent event, {
  VoidCallback? onViewGallery,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final team = _documentationTeamLabel(event);
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              event.title,
              style: memberDashboardSectionTitleStyle.copyWith(fontSize: 18),
            ),
            if (event.tag.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.tag,
                style: memberDashboardMetaStyle.copyWith(color: kAccent),
              ),
            ],
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: event.date),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.schedule_outlined,
              label: 'Time',
              value: event.timeLabel ?? 'Time TBA',
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.location_on_outlined, label: 'Location', value: event.location),
            ],
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.info_outline_rounded,
              label: 'Status',
              value: '',
              trailing: StatusDot(color: event.statusColor, label: event.status),
            ),
            if (team != null) ...[
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.groups_outlined, label: 'Documentation team', value: team),
            ],
            if (_meaningfulEventDescription(event)) ...[
              const SizedBox(height: 16),
              Text(
                'Notes',
                style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                event.description,
                style: memberDashboardBodyStyle.copyWith(fontSize: 13),
              ),
            ],
            if (onViewGallery != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onViewGallery();
                  },
                  icon: Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: requestorMetaIconColor(Icons.photo_library_outlined),
                  ),
                  label: const Text('View event gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: BorderSide(color: kAccent.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

bool _meaningfulEventDescription(CalendarEvent event) {
  final d = event.description.trim();
  if (d.isEmpty || d == event.location.trim()) return false;
  final lower = d.toLowerCase();
  if (lower.startsWith('calendar entry for ')) return false;
  return true;
}

String? _documentationTeamLabel(CalendarEvent event) {
  if (event.documentationTeam.isNotEmpty) {
    return event.documentationTeam.join(', ');
  }
  final lead = event.assignedMemberName?.trim();
  if (lead != null && lead.isNotEmpty) return lead;
  return null;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: requestorMetaIconColor(icon)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              if (trailing != null)
                trailing!
              else
                Text(
                  value,
                  style: memberDashboardBodyStyle.copyWith(
                    color: kDashTextPrimary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Legacy alias used by older tiles — opens read-only member detail.
void showEventDetail(BuildContext context, CalendarEvent event) =>
    showMemberEventDetail(context, event);
