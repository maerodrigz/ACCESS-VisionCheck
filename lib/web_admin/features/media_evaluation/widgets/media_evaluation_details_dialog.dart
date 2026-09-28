import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/media_evaluation_models.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/widgets/ai_result_badge.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/widgets/quality_status_badge.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/widgets/score_progress_bar.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

const kRemarkSuggestions = [
  'Image is clear and acceptable.',
  'Needs better lighting.',
  'Possible AI-generated media. Requires review.',
  'Low sharpness detected.',
];

class MediaEvaluationDetailsDialog extends StatefulWidget {
  const MediaEvaluationDetailsDialog({
    super.key,
    required this.row,
    required this.onSaveRemarks,
  });

  final MediaEvaluationRow row;
  final Future<void> Function(String remarks) onSaveRemarks;

  static Future<void> show(
    BuildContext context, {
    required MediaEvaluationRow row,
    required Future<void> Function(String remarks) onSaveRemarks,
  }) {
    return showDialog(
      context: context,
      builder: (_) => MediaEvaluationDetailsDialog(row: row, onSaveRemarks: onSaveRemarks),
    );
  }

  @override
  State<MediaEvaluationDetailsDialog> createState() => _MediaEvaluationDetailsDialogState();
}

class _MediaEvaluationDetailsDialogState extends State<MediaEvaluationDetailsDialog> {
  late final TextEditingController _remarksController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController(text: widget.row.adminRemarks ?? '');
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSaveRemarks(_remarksController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;

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
                    const Expanded(
                      child: Text(
                        'Evaluation Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow('Media name', row.mediaName),
                _detailRow('Member name', row.memberName),
                _detailRow('Source', row.sourceLabel),
                if (row.fileUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      AdminApiService.mediaUrl(row.fileUrl),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        color: AdminTheme.border.withValues(alpha: 0.3),
                        alignment: Alignment.center,
                        child: const Text('Image unavailable', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (row.criteria.isNotEmpty) ...[
                  Text(
                    'Overall: ${row.overallScore15.toStringAsFixed(1)}/5'
                    '${row.qualityLevel != null ? ' · ${row.qualityLevel}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  if (row.recommendation != null) ...[
                    const SizedBox(height: 4),
                    _detailRow('Recommendation', row.recommendation!),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Criteria scores',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...row.criteria.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              Text('${c.score}/5 ${c.label}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if (c.explanation.isNotEmpty)
                            Text(c.explanation, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  _scoreSection('Sharpness', row.sharpnessScore),
                  _scoreSection('Brightness', row.brightnessScore),
                  _scoreSection('Contrast', row.contrastScore),
                  _scoreSection('Overall score', row.overallScore, bold: true),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('AI result', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 12),
                    AiResultBadge(label: row.aiLabel),
                    const SizedBox(width: 16),
                    const Text('Quality', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 8),
                    QualityStatusBadge(status: row.qualityStatus),
                  ],
                ),
                const SizedBox(height: 8),
                _detailRow('Date evaluated', formatEvaluatedDate(row.evaluatedAt)),
                if (row.adminRemarks != null && row.adminRemarks!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailRow('Gemini / AI feedback', row.adminRemarks!),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Admin remarks',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kRemarkSuggestions.map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _remarksController.text = s,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remarksController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Add feedback or review notes for this media…',
                  ),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _scoreSection(String label, double score, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: AdminTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          ScoreProgressBar(score: score),
        ],
      ),
    );
  }
}
