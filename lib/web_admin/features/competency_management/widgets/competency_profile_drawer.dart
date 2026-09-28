import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_assessment_panel.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_badges.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/features/members/widgets/team_member_widgets.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class CompetencyProfileDrawer extends StatefulWidget {
  const CompetencyProfileDrawer({
    super.key,
    required this.member,
    required this.open,
    required this.onClose,
    required this.onAssignToEvent,
    required this.onViewPortfolio,
    required this.onEditNotes,
    required this.onUpdateLevel,
    required this.onNotesChanged,
    required this.onShowAssessment,
  });

  final CompetencyMember? member;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onAssignToEvent;
  final VoidCallback onViewPortfolio;
  final VoidCallback onEditNotes;
  final VoidCallback onUpdateLevel;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onShowAssessment;

  @override
  State<CompetencyProfileDrawer> createState() => _CompetencyProfileDrawerState();
}

class _CompetencyProfileDrawerState extends State<CompetencyProfileDrawer> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.member?.adminNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant CompetencyProfileDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member?.id != widget.member?.id) {
      _notesController.text = widget.member?.adminNotes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: widget.open ? 0 : -600,
      width: 580,
      child: Material(
        elevation: 16,
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
                    _Header(onClose: widget.onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                                    backgroundImage: m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
                                    child: m.avatarUrl == null
                                        ? Text(m.initials, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AdminTheme.accentBlue))
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(m.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  TeamCoverageBadge(role: m.profile.coverageRole),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      Column(
                                        children: [
                                          const Text('Current', style: TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                                          CompetencyLevelBadge(level: m.currentLevel, overridden: m.levelOverridden),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          const Text('Recommended', style: TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                                          CompetencyLevelBadge(level: m.recommendedLevel),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TeamAvailabilityIndicator(member: m.profile),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AdminTheme.accentBlue.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('System Recommendation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(m.assessment.explanation, style: const TextStyle(fontSize: 12, height: 1.45, color: AdminTheme.textPrimary)),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: widget.onShowAssessment,
                                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                                    label: Text('Why is this member ${m.recommendedLevel.label}?'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const _SectionTitle('Performance Summary'),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Completed documentation requests', value: '${m.profile.completedTasks}'),
                            _InfoRow(label: 'Average media acceptance rate', value: '${m.mediaAcceptanceRate.round()}%'),
                            _InfoRow(label: 'Events covered', value: '${m.eventsCovered}'),
                            _InfoRow(label: 'Featured photos/videos', value: '${m.featuredMediaCount}'),
                            _InfoRow(label: 'Integrity record', value: m.integritySummary),
                            const SizedBox(height: 10),
                            CompetencyProgressBar(label: 'Overall performance score', value: m.performanceScore),
                            const SizedBox(height: 20),
                            CompetencyAssessmentPanel(member: m),
                            const SizedBox(height: 20),
                            const _SectionTitle('Strengths'),
                            const SizedBox(height: 8),
                            for (final s in m.strengths) _BulletRow(text: s, positive: true),
                            const SizedBox(height: 16),
                            const _SectionTitle('Areas for Improvement'),
                            const SizedBox(height: 8),
                            for (final s in m.areasForImprovement) _BulletRow(text: s, positive: false),
                            const SizedBox(height: 20),
                            const _SectionTitle('Documentation Portfolio'),
                            const SizedBox(height: 8),
                            if (m.profile.portfolio.isEmpty)
                              const Text('No portfolio items yet.', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary))
                            else
                              for (final p in m.profile.portfolio) ...[
                                _PortfolioCard(item: p, onView: widget.onViewPortfolio),
                                const SizedBox(height: 8),
                              ],
                            const SizedBox(height: 16),
                            const _SectionTitle('Training Recommendation'),
                            const SizedBox(height: 8),
                            for (final t in m.trainingRecommendations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $t', style: const TextStyle(fontSize: 12, height: 1.4, color: AdminTheme.textPrimary)),
                              ),
                            const SizedBox(height: 16),
                            const _SectionTitle('Administrator Notes'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesController,
                              maxLines: 4,
                              onChanged: widget.onNotesChanged,
                              decoration: const InputDecoration(hintText: 'Document competency observations and assignment rationale…'),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: widget.onAssignToEvent,
                                  icon: const Icon(Icons.event_available_outlined, size: 18),
                                  label: const Text('Assign to Event'),
                                  style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
                                ),
                                OutlinedButton.icon(
                                  onPressed: widget.onViewPortfolio,
                                  icon: const Icon(Icons.collections_outlined, size: 18),
                                  label: const Text('View Portfolio'),
                                ),
                                OutlinedButton(onPressed: widget.onEditNotes, child: const Text('Edit Notes')),
                                OutlinedButton(onPressed: widget.onUpdateLevel, child: const Text('Update Competency Level')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AdminTheme.border))),
      child: Row(
        children: [
          const Expanded(child: Text('Member Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
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
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(flex: 2, child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(positive ? Icons.check : Icons.circle, size: positive ? 16 : 8, color: positive ? AdminTheme.success : AdminTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35))),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.item, required this.onView});

  final PortfolioWorkItem item;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.eventName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${item.dateLabel} · ${item.photoCount} photos · ${item.videoCount} videos',
                  style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onView, child: const Text('View Portfolio')),
        ],
      ),
    );
  }
}
