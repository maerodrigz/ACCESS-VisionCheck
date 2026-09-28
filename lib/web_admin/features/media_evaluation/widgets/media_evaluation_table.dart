import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/media_evaluation_models.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/widgets/ai_result_badge.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/widgets/quality_status_badge.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/widgets/score_progress_bar.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/data_table_card.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef EvaluationRowAction = void Function(MediaEvaluationRow row);

class MediaEvaluationTable extends StatelessWidget {
  const MediaEvaluationTable({
    super.key,
    required this.rows,
    required this.onViewDetails,
    required this.onReviewMedia,
    required this.onArchive,
    required this.onDelete,
    this.canArchive = true,
    this.canDelete = true,
  });

  final List<MediaEvaluationRow> rows;
  final EvaluationRowAction onViewDetails;
  final EvaluationRowAction onReviewMedia;
  final EvaluationRowAction onArchive;
  final EvaluationRowAction onDelete;
  final bool canArchive;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return AdminDataTableTheme(
      child: ResponsiveTableScroll(
        child: DataTable(
            columns: const [
                DataColumn(label: Text('Media Name')),
                DataColumn(label: Text('Member Name')),
                DataColumn(label: Text('Source')),
                DataColumn(label: Text('Sharpness')),
                DataColumn(label: Text('Brightness')),
                DataColumn(label: Text('Contrast')),
                DataColumn(label: Text('Overall Score')),
                DataColumn(label: Text('AI Result')),
                DataColumn(label: Text('Quality Status')),
                DataColumn(label: Text('Date Evaluated')),
                DataColumn(label: Text('Actions')),
              ],
            rows: rows.map((r) => _buildRow(r)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(MediaEvaluationRow r) {
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 160,
            child: Text(
              r.mediaName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
        DataCell(Text(r.memberName, style: const TextStyle(fontSize: 12))),
        DataCell(
          Text(
            r.sourceLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: r.isStandalone ? AdminTheme.accentBlue : AdminTheme.textSecondary,
            ),
          ),
        ),
        DataCell(SizedBox(width: 100, child: ScoreProgressBar(score: r.sharpnessScore, showLabel: true))),
        DataCell(SizedBox(width: 100, child: ScoreProgressBar(score: r.brightnessScore, showLabel: true))),
        DataCell(SizedBox(width: 100, child: ScoreProgressBar(score: r.contrastScore, showLabel: true))),
        DataCell(
          SizedBox(
            width: 110,
            child: ScoreProgressBar(
              score: r.overallScore,
              showLabel: true,
              color: _overallColor(r.overallScore),
            ),
          ),
        ),
        DataCell(AiResultBadge(label: r.aiLabel)),
        DataCell(QualityStatusBadge(status: r.qualityStatus)),
        DataCell(Text(formatEvaluatedDate(r.evaluatedAt), style: const TextStyle(fontSize: 11))),
        DataCell(_ActionButtons(
          onView: () => onViewDetails(r),
          onReview: () => onReviewMedia(r),
          onArchive: canArchive ? () => onArchive(r) : null,
          onDelete: canDelete ? () => onDelete(r) : null,
        )),
      ],
    );
  }

  Color _overallColor(double s) {
    if (s >= 0.8) return AdminTheme.success;
    if (s >= 0.6) return AdminTheme.accentBlue;
    return AdminTheme.warning;
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onView,
    required this.onReview,
    required this.onArchive,
    required this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback onReview;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onView,
          icon: const Icon(Icons.info_outline, size: 20),
          tooltip: 'View details',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: onReview,
          icon: const Icon(Icons.open_in_new, size: 20),
          tooltip: 'Review media',
          visualDensity: VisualDensity.compact,
        ),
        if (onArchive != null)
          IconButton(
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined, size: 20),
            tooltip: 'Archive',
            visualDensity: VisualDensity.compact,
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20, color: AdminTheme.danger),
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
