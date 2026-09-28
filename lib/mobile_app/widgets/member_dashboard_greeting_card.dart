import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

/// Compact greeting strip — name, role, competency. Assignment details live in [MemberCurrentAssignmentHero].
class MemberDashboardGreetingCard extends StatefulWidget {
  const MemberDashboardGreetingCard({super.key});

  @override
  State<MemberDashboardGreetingCard> createState() => _MemberDashboardGreetingCardState();
}

class _MemberDashboardGreetingCardState extends State<MemberDashboardGreetingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _contextLine({required bool hasAssignment, Challenge? assignment}) {
    if (hasAssignment && assignment != null) {
      final role = formatTaskRole(assignment.taskRole ?? 'member');
      return "You're covering ${assignment.title} today as $role.";
    }
    return "No event coverage today. We'll notify you when an admin assigns you.";
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final firstName = memberDashboardFirstName();
        final assignment = memberActiveAssignment();
        final hasAssignment = assignment != null;
        final role = memberDashboardRole(assignment: assignment);
        final level = memberDashboardCompetencyLevel();

        return FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kMemberDashboardPagePadding,
              16,
              kMemberDashboardPagePadding,
              0,
            ),
            child: Container(
              decoration: memberDashboardCardDecoration(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: kMemberDashboardAccent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${memberDashboardGreeting()}, $firstName!',
                          style: dashText(const TextStyle(
                            color: kDashTextPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.35,
                          )),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _HeroBadge(
                                icon: Icons.camera_alt_rounded,
                                iconColor: const Color(0xFF0891B2),
                                label: role,
                                backgroundColor: kMemberDashboardAccentLight,
                                foregroundColor: kMemberDashboardAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _HeroBadge(
                                icon: Icons.workspace_premium_rounded,
                                iconColor: kMemberPrimary,
                                label: level,
                                backgroundColor: kDashAccentCompetency,
                                foregroundColor: kDashAccentCompetencyIcon,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Text(
                            _contextLine(hasAssignment: hasAssignment, assignment: assignment),
                            key: ValueKey(hasAssignment ? assignment.title : 'idle'),
                            style: memberDashboardBodyStyle.copyWith(fontSize: 13, height: 1.45),
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
      },
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                color: foregroundColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              )),
            ),
          ),
        ],
      ),
    );
  }
}
