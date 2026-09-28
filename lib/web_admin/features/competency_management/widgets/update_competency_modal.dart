import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/features/competency_management/widgets/competency_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class UpdateCompetencyResult {
  const UpdateCompetencyResult({required this.level, required this.useSystemRecommendation});

  final CompetencyLevel level;
  final bool useSystemRecommendation;
}

class UpdateCompetencyModal {
  UpdateCompetencyModal._();

  static Future<UpdateCompetencyResult?> show(
    BuildContext context, {
    required CompetencyMember member,
  }) {
    var selected = member.currentLevel;
    var useSystem = false;

    return showDialog<UpdateCompetencyResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Competency Level', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'System recommends ${member.recommendedLevel.label}',
                  style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final level in CompetencyLevel.values)
                  RadioListTile<CompetencyLevel>(
                    value: level,
                    groupValue: selected,
                    onChanged: (v) => setLocal(() {
                      selected = v!;
                      useSystem = false;
                    }),
                    title: Row(
                      children: [
                        CompetencyLevelBadge(level: level, compact: true),
                        if (level == member.recommendedLevel) ...[
                          const SizedBox(width: 8),
                          const Text('(system)', style: TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                        ],
                      ],
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                CheckboxListTile(
                  value: useSystem,
                  onChanged: (v) => setLocal(() {
                    useSystem = v ?? false;
                    if (useSystem) selected = member.recommendedLevel;
                  }),
                  title: const Text('Use system recommendation', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Removes administrator override', style: TextStyle(fontSize: 11)),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, UpdateCompetencyResult(level: selected, useSystemRecommendation: useSystem)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
