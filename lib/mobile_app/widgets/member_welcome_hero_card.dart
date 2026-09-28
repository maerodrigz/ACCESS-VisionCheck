import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

/// Premium welcome hero card for the member home dashboard.
class MemberWelcomeHeroCard extends StatelessWidget {
  const MemberWelcomeHeroCard({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String _coverageRole({Challenge? assignment}) {
    final role = assignment?.taskRole?.trim();
    if (role != null && role.isNotEmpty) {
      return _formatTaskRole(role);
    }
    return 'Documentation Member';
  }

  static String _formatTaskRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('video')) return 'Videographer';
    if (r.contains('photo')) return 'Photographer';
    return role[0].toUpperCase() + role.substring(1);
  }

  static String _competencyLevel() {
    final skill = appState.profileSkillLevel?.trim();
    if (skill != null && skill.isNotEmpty) return skill;
    return 'Beginner';
  }

  static String _motivation({required bool hasAssignment}) {
    if (hasAssignment) {
      return 'You have an upcoming documentation assignment. Review the details and prepare your gear.';
    }
    const messages = [
      'Stay ready. New documentation opportunities are posted regularly.',
      'Keep sharpening your skills. Every upload brings you closer to the next level.',
      'Check the calendar for upcoming ACCESS coverage events.',
    ];
    return messages[DateTime.now().day % messages.length];
  }

  static Challenge? _activeAssignment() {
    for (final task in appState.challenges) {
      if (task.completed) continue;
      final status = task.status.toLowerCase();
      if (status == 'cancelled' || status == 'canceled') continue;
      return task;
    }
    return null;
  }

  static CalendarEvent? _calendarEventFor(Challenge assignment) {
    final requestId = assignment.requestId;
    if (requestId != null) {
      for (final event in appState.events) {
        if (event.requestId == requestId) return event;
      }
    }
    for (final event in appState.events) {
      if (event.title == assignment.title) return event;
    }
    return null;
  }

  void _openDetails(BuildContext context, Challenge assignment) {
    final event = _calendarEventFor(assignment);
    if (event != null) {
      showEventDetail(context, event);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
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
                  color: kBorder,
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
                icon: Icons.calendar_today_rounded,
                label: assignment.eventDate!,
              ),
            if (assignment.eventTime != null) ...[
              const SizedBox(height: 6),
              MemberDashboardMetaRow(
                icon: Icons.schedule_rounded,
                label: assignment.eventTime!,
              ),
            ],
            if (assignment.venue != null && assignment.venue!.isNotEmpty) ...[
              const SizedBox(height: 6),
              MemberDashboardMetaRow(
                icon: Icons.location_on_outlined,
                label: assignment.venue!,
              ),
            ],
            if (assignment.taskRole != null) ...[
              const SizedBox(height: 6),
              MemberDashboardMetaRow(
                icon: Icons.badge_outlined,
                label: _formatTaskRole(assignment.taskRole!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final assignment = _activeAssignment();
        final hasAssignment = assignment != null;
        final name = memberDashboardFirstName();
        final coverageRole = _coverageRole(assignment: assignment);
        final competency = _competencyLevel();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            kMobilePagePadding,
            16,
            kMobilePagePadding,
            0,
          ),
          child: MemberDashboardCard(
            showAccentStrip: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, $name!',
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MemberDashboardChip(
                      icon: Icons.camera_alt_outlined,
                      label: coverageRole,
                    ),
                    MemberDashboardChip(
                      icon: Icons.workspace_premium_outlined,
                      label: competency,
                      accent: kMemberDashboardTitle,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _motivation(hasAssignment: hasAssignment),
                  style: memberDashboardBodyStyle,
                ),
                const SizedBox(height: 18),
                if (hasAssignment)
                  _AssignmentPanel(
                    assignment: assignment,
                    onViewDetails: () => _openDetails(context, assignment),
                  )
                else
                  const _EmptyAssignmentState(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssignmentPanel extends StatelessWidget {
  const _AssignmentPanel({
    required this.assignment,
    required this.onViewDetails,
  });

  final Challenge assignment;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final assignedRole = MemberWelcomeHeroCard._formatTaskRole(
      assignment.taskRole ?? 'member',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: memberDashboardInnerPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MemberDashboardIconTile(
                icon: Icons.event_available_rounded,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assignment.title,
                  style: memberDashboardCardTitleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MemberDashboardMetaRow(
            icon: Icons.calendar_today_rounded,
            label: assignment.eventDate ?? 'Date TBA',
          ),
          const SizedBox(height: 8),
          MemberDashboardMetaRow(
            icon: Icons.schedule_rounded,
            label: assignment.eventTime ?? 'Time TBA',
          ),
          const SizedBox(height: 8),
          MemberDashboardMetaRow(
            icon: Icons.location_on_outlined,
            label: assignment.venue?.isNotEmpty == true
                ? assignment.venue!
                : 'Location TBA',
          ),
          const SizedBox(height: 8),
          MemberDashboardMetaRow(
            icon: Icons.badge_outlined,
            label: assignedRole,
          ),
          const SizedBox(height: 16),
          MemberDashboardPrimaryButton(
            label: 'View Details',
            icon: Icons.visibility_outlined,
            onPressed: onViewDetails,
          ),
        ],
      ),
    );
  }
}

class _EmptyAssignmentState extends StatelessWidget {
  const _EmptyAssignmentState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kMemberDashboardAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              color: kMemberDashboardAccent,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No assigned documentation yet',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When an admin assigns you to an event, the schedule and coverage details will appear here.',
            textAlign: TextAlign.center,
            style: memberDashboardBodyStyle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
