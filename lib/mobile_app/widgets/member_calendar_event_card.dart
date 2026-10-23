import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';

/// Full event card for the selected date section.
class MemberCalendarEventCard extends StatelessWidget {
  const MemberCalendarEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.forRequestor = false,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;
  final bool forRequestor;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool _isPrimaryScopeEvent(CalendarEvent event) {
    return appState.myCalendarEvents.any(
      (e) =>
          (event.id != null && e.id == event.id) ||
          (event.requestId != null && e.requestId == event.requestId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = event.isPast;
    final isMine = _isPrimaryScopeEvent(event);
    final accent = isMine ? kMemberPrimary : kMemberCyan;

    return Material(
      color: kSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(
              color: isMine ? accent.withValues(alpha: 0.35) : kBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: (isMine ? accent : Colors.black).withValues(alpha: isMine ? 0.06 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: isMine ? accent : kMemberCyan.withValues(alpha: 0.45)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: muted ? kSurfaceAlt : accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: muted ? 0.1 : 0.22)),
                      ),
                      child: Icon(
                        isMine
                            ? (forRequestor
                                ? Icons.description_outlined
                                : Icons.assignment_ind_rounded)
                            : Icons.event_note_rounded,
                        color: muted ? kIconInactive : accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: memberDashboardCardTitleStyle.copyWith(
                                    color: muted ? kTextSecondary : kDashTextPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _AssignmentKindPill(assigned: isMine, forRequestor: forRequestor),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _MetaRow(
                            icon: Icons.calendar_today_outlined,
                            text: _formatDate(event.startDate),
                            muted: muted,
                          ),
                          const SizedBox(height: 3),
                          _MetaRow(
                            icon: Icons.schedule_rounded,
                            text: event.timeLabel ?? 'Time TBA',
                            muted: muted,
                          ),
                          if (event.location.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _MetaRow(
                              icon: Icons.location_on_outlined,
                              text: event.location,
                              muted: muted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  }
}

/// Compact card for the upcoming events list.
class MemberCalendarUpcomingCard extends StatelessWidget {
  const MemberCalendarUpcomingCard({
    super.key,
    required this.event,
    this.onTap,
    this.inGroup = false,
    this.forRequestor = false,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;

  /// Legacy grouped list styling; calendar screen uses separate cards.
  final bool inGroup;
  final bool forRequestor;

  @override
  Widget build(BuildContext context) {
    final isMine = appState.myCalendarEvents.any(
      (e) =>
          (event.id != null && e.id == event.id) ||
          (event.requestId != null && e.requestId == event.requestId),
    );
    final accent = isMine ? kAccent : kCyan;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: inGroup ? 14 : 12,
        vertical: inGroup ? 12 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateColumn(date: event.startDate, accent: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                if ((event.timeLabel ?? '').trim().isNotEmpty)
                  _CompactMeta(
                    icon: Icons.schedule_rounded,
                    text: event.timeLabel!.trim(),
                  ),
                if (event.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _CompactMeta(
                    icon: Icons.location_on_outlined,
                    text: event.location.trim(),
                  ),
                ],
                const SizedBox(height: 6),
                _AssignmentKindPill(
                  assigned: isMine,
                  compact: true,
                  forRequestor: forRequestor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: kAccent.withValues(alpha: 0.4), size: 18),
        ],
      ),
    );

    if (inGroup) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      );
    }

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }

}

class _DateColumn extends StatelessWidget {
  const _DateColumn({
    required this.date,
    required this.accent,
  });

  final DateTime date;
  final Color accent;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Column(
        children: [
          Text(
            _months[date.month - 1].toUpperCase(),
            style: dashText(TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            )),
          ),
          Text(
            '${date.day}',
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.5,
            )),
          ),
        ],
      ),
    );
  }
}

class _AssignmentKindPill extends StatelessWidget {
  const _AssignmentKindPill({
    required this.assigned,
    this.compact = false,
    this.forRequestor = false,
  });

  final bool assigned;
  final bool compact;
  final bool forRequestor;

  @override
  Widget build(BuildContext context) {
    final color = assigned ? kAccent : kCyan;
    final bg = assigned ? kBlueDim : kCyanDim;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        assigned
            ? (forRequestor ? 'Your request' : 'Assigned')
            : (forRequestor ? 'Campus' : 'Event'),
        style: dashText(TextStyle(
          color: color,
          fontSize: compact ? 9 : 9.5,
          fontWeight: FontWeight.w700,
        )),
      ),
    );
  }
}

class _CompactMeta extends StatelessWidget {
  const _CompactMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final iconColor = requestorMetaIconColor(icon);
    return Row(
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: memberDashboardBodyStyle.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.text,
    required this.muted,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final iconColor = requestorMetaIconColor(icon, muted: muted);
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 12,
              color: muted ? kIconInactive : kDashTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
