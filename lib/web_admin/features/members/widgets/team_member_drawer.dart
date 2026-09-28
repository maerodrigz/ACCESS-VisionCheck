import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/skill_level_badge.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/features/members/widgets/team_member_widgets.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class TeamMemberProfileDrawer extends StatelessWidget {
  const TeamMemberProfileDrawer({
    super.key,
    required this.member,
    required this.open,
    required this.onClose,
    required this.onAssignToEvent,
    required this.onEditMember,
    required this.onDeactivate,
    required this.onViewPortfolio,
  });

  final TeamMemberProfile? member;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onAssignToEvent;
  final VoidCallback onEditMember;
  final VoidCallback onDeactivate;
  final VoidCallback onViewPortfolio;

  @override
  Widget build(BuildContext context) {
    final m = member;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: open ? 0 : -540,
      width: 520,
      child: Material(
        elevation: 16,
        shadowColor: Colors.black26,
        child: Container(
          decoration: const BoxDecoration(
            color: AdminTheme.surface,
            border: Border(left: BorderSide(color: AdminTheme.border)),
          ),
          child: m == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DrawerHeader(onClose: onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  TeamMemberAvatar(name: m.name, avatarUrl: m.avatarUrl, radius: 40, fontSize: 28),
                                  const SizedBox(height: 12),
                                  Text(m.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  TeamCoverageBadge(role: m.coverageRole),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const _SectionTitle('Availability'),
                            const SizedBox(height: 8),
                            TeamAvailabilityIndicator(member: m),
                            const SizedBox(height: 20),
                            const _SectionTitle('Personal information'),
                            const SizedBox(height: 8),
                            _InfoGrid(rows: [
                              ('Email', m.email),
                              ('Contact', m.contactNumber ?? '—'),
                              ('Role', m.coverageRoleLabel),
                              ('Joined', formatTeamDate(m.dateJoined)),
                            ]),
                            const SizedBox(height: 20),
                            const _SectionTitle('Current assignment'),
                            const SizedBox(height: 8),
                            if (m.currentAssignment != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AdminTheme.contentBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AdminTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.currentAssignment!.eventName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${m.currentAssignment!.assignmentRole} · ${m.currentAssignment!.scheduleLabel}',
                                      style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: ${m.currentAssignment!.status}',
                                      style: const TextStyle(fontSize: 11, color: AdminTheme.accentBlue, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Text('No active assignment.', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                            const SizedBox(height: 20),
                            const _SectionTitle('Performance'),
                            const SizedBox(height: 10),
                            TeamPerformanceBar(label: 'Tasks completed', value: m.completedTasks.toDouble(), max: 20),
                            const SizedBox(height: 10),
                            TeamPerformanceBar(label: 'Avg media quality', value: m.averageQualityScore, max: 100, suffix: '%'),
                            const SizedBox(height: 10),
                            TeamPerformanceBar(label: 'On-time submission', value: m.onTimeRate, max: 100, suffix: '%'),
                            const SizedBox(height: 10),
                            TeamPerformanceBar(label: 'AI evaluation rating', value: m.aiRating, max: 100, suffix: '%'),
                            const SizedBox(height: 20),
                            const _SectionTitle('Skill classification'),
                            const SizedBox(height: 8),
                            SkillLevelBadge(tier: m.skillTier, label: m.skillLevelLabel, skillScore: m.performanceScore),
                            const SizedBox(height: 20),
                            const _SectionTitle('Documentation portfolio'),
                            const SizedBox(height: 8),
                            if (m.portfolio.isEmpty)
                              const Text('No portfolio items yet.', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary))
                            else
                              for (final p in m.portfolio) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.contentBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AdminTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.eventName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            Text(p.dateLabel, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                                            Text(
                                              '${p.photoCount} photos · ${p.videoCount} videos',
                                              style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (p.qualityScore > 0)
                                        Text(
                                          '${p.qualityScore.round()}%',
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: AdminTheme.accentBlue),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            const SizedBox(height: 20),
                            const _SectionTitle('AI recommendation'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 18, color: AdminTheme.accentBlue),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      m.aiRecommendation,
                                      style: const TextStyle(fontSize: 13, color: AdminTheme.textPrimary, height: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AdminTheme.border)),
                        color: Color(0xFFFAFBFC),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: onAssignToEvent,
                            icon: const Icon(Icons.event_available_outlined, size: 16),
                            label: const Text('Assign to Event'),
                            style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
                          ),
                          OutlinedButton(onPressed: onEditMember, child: const Text('Edit Member')),
                          OutlinedButton(onPressed: onViewPortfolio, child: const Text('View Portfolio')),
                          OutlinedButton(
                            onPressed: onDeactivate,
                            style: OutlinedButton.styleFrom(foregroundColor: AdminTheme.danger),
                            child: const Text('Deactivate'),
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AdminTheme.border))),
      child: Row(
        children: [
          const Expanded(
            child: Text('Member profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary));
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))),
                Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
      ],
    );
  }
}
