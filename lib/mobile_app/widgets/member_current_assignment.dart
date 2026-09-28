import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';
import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

/// Primary assignment card on member home — single source for event details and actions.
class MemberCurrentAssignmentHero extends StatelessWidget {
  const MemberCurrentAssignmentHero({super.key});

  void _openDetails(BuildContext context, Challenge assignment) {
    final event = calendarEventForAssignment(assignment);
    if (event != null) {
      showEventDetail(context, event);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: kDashCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kDashBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              assignment.title,
              style: memberDashboardCardTitleStyle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            if (assignment.eventDate != null)
              MemberDashboardMetaRow(
                icon: Icons.calendar_today_outlined,
                label: assignment.eventDate!,
              ),
            if (assignment.eventTime != null) ...[
              const SizedBox(height: 6),
              MemberDashboardMetaRow(
                icon: Icons.schedule_rounded,
                label: assignment.eventTime!,
              ),
            ],
            if (assignment.venue?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              MemberDashboardMetaRow(
                icon: Icons.location_on_outlined,
                label: assignment.venue!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending_acceptance':
        return 'Awaiting your response';
      case 'assigned':
        return 'New assignment';
      case 'in_progress':
        return 'In progress';
      default:
        return 'Active coverage';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final assignment = memberActiveAssignment();
        if (assignment == null) return const SizedBox.shrink();

        final role = formatTaskRole(assignment.taskRole ?? 'member');
        final status = assignment.status.toLowerCase();
        final needsResponse = status == 'pending_acceptance' || status == 'assigned';

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            kMemberDashboardPagePadding,
            14,
            kMemberDashboardPagePadding,
            0,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
              gradient: kMemberDashboardAccentGradient,
              boxShadow: [
                BoxShadow(
                  color: kMemberDashboardAccent.withValues(alpha: 0.26),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -24,
                  child: IgnorePointer(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Icon(
                    Icons.event_available_rounded,
                    size: 52,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(kMemberDashboardCardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: Text(
                              'TODAY\'S ASSIGNMENT',
                              style: dashText(const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              )),
                            ),
                          ),
                          const Spacer(),
                          if (needsResponse)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A).withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Action needed',
                                style: dashText(const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                )),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        assignment.title,
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.35,
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusLabel(status),
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                      const SizedBox(height: 14),
                      _HeroMeta(icon: Icons.calendar_today_outlined, label: assignment.eventDate ?? 'Date TBA'),
                      const SizedBox(height: 7),
                      _HeroMeta(icon: Icons.schedule_rounded, label: assignment.eventTime ?? 'Time TBA'),
                      const SizedBox(height: 7),
                      _HeroMeta(
                        icon: Icons.location_on_outlined,
                        label: assignment.venue?.isNotEmpty == true ? assignment.venue! : 'Location TBA',
                      ),
                      const SizedBox(height: 7),
                      _HeroMeta(icon: Icons.badge_outlined, label: role),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openDetails(context, assignment),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View Details'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: kMemberDashboardAccent,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                            ),
                            textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.92),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            needsResponse ? 'Review in My Assignments' : 'All assignments',
                            style: dashText(const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white70,
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: dashText(TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )),
          ),
        ),
      ],
    );
  }
}

/// Shown when the member has no active assignment.
class MemberDashboardWelcomeCard extends StatelessWidget {
  const MemberDashboardWelcomeCard({super.key, this.onViewCalendar});

  final VoidCallback? onViewCalendar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        if (memberActiveAssignment() != null) return const SizedBox.shrink();

        const messages = [
          'Stay ready. New documentation opportunities are posted regularly.',
          'Keep sharpening your skills. Every upload brings you closer to the next level.',
          'Check the calendar for upcoming ACCESS coverage events.',
        ];
        final message = messages[DateTime.now().day % messages.length];

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            kMemberDashboardPagePadding,
            14,
            kMemberDashboardPagePadding,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(kMemberDashboardCardPadding),
            decoration: memberDashboardCardDecoration(
              backgroundColor: kDashCardBg,
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: kMemberDashboardAccentLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kMemberDashboardAccent.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.event_busy_outlined,
                    color: kMemberDashboardAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No assigned documentation yet',
                  textAlign: TextAlign.center,
                  style: memberDashboardCardTitleStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: memberDashboardBodyStyle.copyWith(fontSize: 13, height: 1.45),
                ),
                if (onViewCalendar != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onViewCalendar,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('View Calendar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kMemberPrimary,
                        side: BorderSide(color: kMemberPrimary.withValues(alpha: 0.35)),
                        minimumSize: const Size.fromHeight(kMobileMinTouch),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                        ),
                        textStyle: dashText(const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
