import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/member_rankings/member_ranking_models.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/participation_status_badge.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/rank_badge.dart';
import 'package:access_mobile/web_admin/features/member_rankings/widgets/skill_level_badge.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

const kRankingRemarkSuggestions = [
  'Media appears authentic.',
  'Ready for advanced assignments.',
  'Continue monitoring.',
  'Encourage participation.',
  'Needs training on lighting and sharpness.',
  'Requires media review.',
];

class MemberRankingDetailsDialog extends StatefulWidget {
  const MemberRankingDetailsDialog({
    super.key,
    required this.row,
    required this.onSave,
  });

  final MemberRankingRow row;
  final Future<void> Function(String remarks) onSave;

  static Future<void> show(
    BuildContext context, {
    required MemberRankingRow row,
    required Future<void> Function(String remarks) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => MemberRankingDetailsDialog(row: row, onSave: onSave),
    );
  }

  @override
  State<MemberRankingDetailsDialog> createState() => _MemberRankingDetailsDialogState();
}

class _MemberRankingDetailsDialogState extends State<MemberRankingDetailsDialog> {
  late final TextEditingController _remarks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remarks = TextEditingController(text: widget.row.adminRemarks ?? '');
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_remarks.text.trim());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    RankBadge(rank: r.rank),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.memberName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SkillLevelBadge(tier: r.skillTier, label: r.skillLevel, skillScore: r.skillScore),
                    ParticipationStatusBadge(status: r.participationStatus),
                  ],
                ),
                const SizedBox(height: 16),
                _scoreBreakdown(r),
                const SizedBox(height: 16),
                _statGrid(r),
                const SizedBox(height: 16),
                _info('AI detection history', r.aiResultSummary),
                _info('Tasks', '${r.completedTasks} of ${r.assignedTasks} completed'),
                _info('Approved uploads', '${r.approvedUploads} of ${r.totalUploads}'),
                _info('Admin evaluation', r.adminEvaluationLabel),
                _info('Last activity', formatLastActivity(r.lastActivity)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.accentCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.accentCyan.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommended action', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(r.recommendedAction, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Admin remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kRankingRemarkSuggestions.map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _remarks.text = s,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remarks,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Notes for this member…'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save remarks'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBreakdown(MemberRankingRow r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Skill score breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 8),
              Tooltip(
                message: kSkillScoreTooltip,
                child: Icon(Icons.info_outline, size: 16, color: AdminTheme.textSecondary.withValues(alpha: 0.8)),
              ),
              const Spacer(),
              Text(
                r.skillScorePercent,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AdminTheme.accentBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _breakdownRow('Media Quality', '70%', r.mediaQualityScore),
          _breakdownRow('Media Integrity', '30%', r.aiAuthenticityScore),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String weight, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('$label ($weight)', style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: AdminTheme.border,
                color: AdminTheme.accentCyan,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${score.round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(MemberRankingRow r) {
    return Row(
      children: [
        Expanded(child: _statBox('Points', '${r.points}')),
        const SizedBox(width: 8),
        Expanded(child: _statBox('Uploads', '${r.uploads}')),
        const SizedBox(width: 8),
        Expanded(child: _statBox('Avg quality', r.qualityPercent)),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}
