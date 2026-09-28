import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

/// Full event card for the selected date section.
class MemberCalendarEventCard extends StatelessWidget {
  const MemberCalendarEventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = event.isPast;
    final isMine = memberIsAssignedToEvent(event);
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
                color: (isMine ? accent : Colors.black).withValues(alpha: isMine ? 0.08 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: isMine ? accent : kMemberCyan.withValues(alpha: 0.45)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: muted ? kSurfaceAlt : accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withValues(alpha: muted ? 0.1 : 0.22)),
                      ),
                      child: Icon(
                        isMine ? Icons.assignment_ind_rounded : Icons.event_note_rounded,
                        color: muted ? kIconInactive : accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
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
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(event: event),
                            ],
                          ),
                          if (isMine) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kMemberPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kMemberPrimary.withValues(alpha: 0.22)),
                              ),
                              child: Text(
                                'YOUR COVERAGE',
                                style: dashText(const TextStyle(
                                  color: kMemberPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                )),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            event.tag,
                            style: memberDashboardMetaStyle.copyWith(
                              color: muted ? kIconInactive : accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _MetaRow(
                            icon: Icons.schedule_rounded,
                            text: event.timeLabel ?? 'Time TBA',
                            muted: muted,
                          ),
                          if (event.location.isNotEmpty) ...[
                            const SizedBox(height: 4),
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
}

/// Compact agenda row for the upcoming events list.
class MemberCalendarUpcomingCard extends StatelessWidget {
  const MemberCalendarUpcomingCard({
    super.key,
    required this.event,
    this.onTap,
    this.showDateBadge = true,
    this.inGroup = false,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;
  final bool showDateBadge;
  final bool inGroup;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final isMine = memberIsAssignedToEvent(event);
    final accent = isMine ? kAccent : kCyan;
    final iconBg = isMine ? kBlueDim : kCyanDim;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: inGroup ? 14 : 12,
        vertical: inGroup ? 12 : 11,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDateBadge) ...[
            _DateColumn(date: event.startDate, accent: accent),
            const SizedBox(width: 12),
          ] else ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isMine ? Icons.assignment_ind_outlined : Icons.event_outlined,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(event, includeDate: !showDateBadge),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardBodyStyle.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMine)
            _AgendaPill(
              label: 'Yours',
              color: kAccent,
              background: kBlueDim,
            )
          else if (event.tag.trim().isNotEmpty)
            _AgendaPill(
              label: event.tag,
              color: kCyan,
              background: kCyanDim,
            ),
          Icon(Icons.chevron_right_rounded, color: kIconInactive, size: 18),
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
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }

  String _subtitle(CalendarEvent event, {required bool includeDate}) {
    final parts = <String>[];
    if (includeDate) {
      parts.add(_formatDay(event.startDate));
    }
    final time = event.timeLabel?.trim();
    if (time != null && time.isNotEmpty) parts.add(time);
    final location = event.location.trim();
    if (location.isNotEmpty) parts.add(location);
    return parts.isEmpty ? 'Details TBA' : parts.join(' · ');
  }

  String _formatDay(DateTime date) {
    final weekday = _weekdays[(date.weekday - 1) % 7];
    final month = _months[date.month - 1];
    return '$weekday, $month ${date.day}';
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
      width: 38,
      child: Column(
        children: [
          Text(
            _months[date.month - 1].toUpperCase(),
            style: dashText(TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
          ),
          const SizedBox(height: 1),
          Text(
            '${date.day}',
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.5,
            )),
          ),
        ],
      ),
    );
  }
}

class _AgendaPill extends StatelessWidget {
  const _AgendaPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: dashText(TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        )),
      ),
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
    return Row(
      children: [
        Icon(icon, size: 14, color: muted ? kIconInactive : kTextSecondary),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: event.statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        event.status.toUpperCase(),
        style: TextStyle(
          color: event.statusColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
