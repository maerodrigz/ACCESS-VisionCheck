import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class CompetencyAssessmentPanel extends StatelessWidget {
  const CompetencyAssessmentPanel({
    super.key,
    required this.member,
    this.inDialog = false,
  });

  final CompetencyMember member;
  final bool inDialog;

  static Future<void> show(BuildContext context, CompetencyMember member) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Why is ${member.name} ${member.recommendedLevel.label}?',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),
                CompetencyAssessmentPanel(member: member, inDialog: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = member.assessment;
    return Container(
      padding: inDialog ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: inDialog
          ? null
          : BoxDecoration(
              color: AdminTheme.contentBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminTheme.border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!inDialog) ...[
            Row(
              children: [
                const Expanded(
                  child: Text('Competency Assessment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                TextButton.icon(
                  onPressed: () => CompetencyAssessmentPanel.show(context, member),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('View criteria'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else
            const Text('Competency Assessment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final c in a.criteria) ...[
            _CriterionRow(criterion: c),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.accentBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Recommendation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CompetencyLevelBadge(level: a.recommendedLevel),
                    const SizedBox(width: 10),
                    Text('${a.skillScore.round()}% composite score', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(a.explanation, style: const TextStyle(fontSize: 12, height: 1.45, color: AdminTheme.textPrimary)),
              ],
            ),
          ),
          if (member.levelOverridden) ...[
            const SizedBox(height: 10),
            Text(
              'Administrator override active — current level: ${member.currentLevel.label}',
              style: const TextStyle(fontSize: 11, color: AdminTheme.warning, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({required this.criterion});

  final CompetencyCriterion criterion;

  @override
  Widget build(BuildContext context) {
    final color = criterion.met ? AdminTheme.success : AdminTheme.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(criterion.met ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(criterion.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              Text(criterion.detail, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
