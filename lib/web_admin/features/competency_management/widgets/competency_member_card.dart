import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_badges.dart';
import 'package:access_mobile/web_admin/features/members/widgets/team_member_widgets.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef CompetencyMemberTap = void Function(CompetencyMember member);

class CompetencyMemberCard extends StatefulWidget {
  const CompetencyMemberCard({super.key, required this.member, required this.onViewProfile});

  final CompetencyMember member;
  final CompetencyMemberTap onViewProfile;

  @override
  State<CompetencyMemberCard> createState() => _CompetencyMemberCardState();
}

class _CompetencyMemberCardState extends State<CompetencyMemberCard> {
  bool _hovered = false;

  CompetencyMember get m => widget.member;

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
          borderRadius: BorderRadius.circular(18),
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
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                    backgroundImage: m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
                    child: m.avatarUrl == null
                        ? Text(m.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminTheme.accentBlue))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
                        const SizedBox(height: 4),
                        TeamCoverageBadge(role: m.profile.coverageRole),
                      ],
                    ),
                  ),
                  CompetencyLevelBadge(level: m.currentLevel, overridden: m.levelOverridden, compact: true),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'Performance', value: '${m.performanceScore.round()}%')),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(label: 'Acceptance', value: '${m.mediaAcceptanceRate.round()}%')),
                ],
              ),
              const SizedBox(height: 12),
              TeamAvailabilityIndicator(member: m.profile, compact: true),
              if (m.profile.currentAssignment != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Assignment: ${m.profile.currentAssignment!.eventName}',
                  style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              EventRecommendationBadge(recommendation: m.eventRecommendation),
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
