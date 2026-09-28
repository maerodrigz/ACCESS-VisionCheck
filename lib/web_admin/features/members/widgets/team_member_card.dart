import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/skill_level_badge.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/features/members/widgets/team_member_widgets.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef TeamMemberTap = void Function(TeamMemberProfile member);

class TeamMemberCard extends StatefulWidget {
  const TeamMemberCard({super.key, required this.member, required this.onViewProfile});

  final TeamMemberProfile member;
  final TeamMemberTap onViewProfile;

  @override
  State<TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<TeamMemberCard> {
  bool _hovered = false;

  TeamMemberProfile get m => widget.member;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AdminTheme.surface,
          borderRadius: BorderRadius.circular(AdminTheme.cardRadius),
          border: Border.all(color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.35) : AdminTheme.border),
          boxShadow: _hovered
              ? [BoxShadow(color: AdminTheme.accentBlue.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))]
              : AdminTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeamMemberAvatar(name: m.name, avatarUrl: m.avatarUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
                        const SizedBox(height: 4),
                        TeamCoverageBadge(role: m.coverageRole),
                      ],
                    ),
                  ),
                  SkillLevelBadge(tier: m.skillTier, label: m.skillLevelLabel),
                ],
              ),
              const SizedBox(height: 14),
              TeamAvailabilityIndicator(member: m, compact: true),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'Performance', value: '${m.performanceScore.round()}%')),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(label: 'Tasks done', value: '${m.completedTasks}')),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(label: 'Avg quality', value: m.averageQualityScore > 0 ? '${m.averageQualityScore.round()}%' : '—')),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => widget.onViewProfile(m),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
        ],
      ),
    );
  }
}
