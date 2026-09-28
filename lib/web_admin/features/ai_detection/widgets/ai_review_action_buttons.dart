import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/ai_detection/ai_detection_models.dart';

typedef AiReviewQuickPick = void Function(ReviewStatus status, String exampleRemarks, String actionLabel);

class AiReviewActionButtons extends StatelessWidget {
  const AiReviewActionButtons({
    super.key,
    required this.onQuickPick,
    required this.onConfirm,
    this.compact = false,
  });

  final AiReviewQuickPick onQuickPick;
  final Future<bool?> Function(String title, String message, {IconData icon}) onConfirm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionSpec>[
      _ActionSpec(
        icon: Icons.verified_user_outlined,
        label: 'Verify as Human',
        tooltip: 'Mark as verified human-made media',
        status: ReviewStatus.verifiedHuman,
        remarks: 'Verified as human-made media.',
      ),
      _ActionSpec(
        icon: Icons.smart_toy_outlined,
        label: 'Confirm AI',
        tooltip: 'Confirm as AI-generated (affects ranking)',
        status: ReviewStatus.confirmedAiGenerated,
        remarks: 'Confirmed AI-generated content.',
        needsConfirm: true,
        confirmTitle: 'Confirm as AI-generated?',
        confirmMessage:
            'Are you sure you want to confirm this media as AI-generated? This may affect the member\'s ranking and authenticity score.',
      ),
      _ActionSpec(
        icon: Icons.warning_amber_outlined,
        label: 'Suspicious',
        tooltip: 'Mark as suspicious / needs further review',
        status: ReviewStatus.needsFurtherReview,
        remarks: 'Possible AI-generated media. Requires manual verification.',
      ),
      _ActionSpec(
        icon: Icons.upload_outlined,
        label: 'Request Reupload',
        tooltip: 'Ask member to reupload original media',
        status: ReviewStatus.reuploadRequested,
        remarks: 'Please reupload the original photo or video.',
      ),
      _ActionSpec(
        icon: Icons.report_outlined,
        label: 'Accept Warning',
        tooltip: 'Accept with warning after manual review',
        status: ReviewStatus.acceptedWithWarning,
        remarks: 'Accepted with warning after manual review.',
        needsConfirm: true,
        confirmTitle: 'Accept with warning?',
        confirmMessage: 'Accept this media with a warning note after manual review?',
      ),
      _ActionSpec(
        icon: Icons.block_outlined,
        label: 'Reject',
        tooltip: 'Reject media after review',
        status: ReviewStatus.rejected,
        remarks: 'Rejected after AI review.',
        needsConfirm: true,
        confirmTitle: 'Reject media?',
        confirmMessage: 'Reject this media after AI review? The member will be notified.',
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 4,
        children: actions
            .map(
              (a) => IconButton(
                onPressed: () => _run(context, a),
                icon: Icon(a.icon, size: 20),
                tooltip: a.tooltip,
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map(
            (a) => OutlinedButton.icon(
              onPressed: () => _run(context, a),
              icon: Icon(a.icon, size: 16),
              label: Text(a.label, style: const TextStyle(fontSize: 11)),
            ),
          )
          .toList(),
    );
  }

  Future<void> _run(BuildContext context, _ActionSpec spec) async {
    if (spec.needsConfirm) {
      final ok = await onConfirm(
        spec.confirmTitle!,
        '${spec.confirmMessage!} You may add optional feedback, then tap Save review. This dialog stays open until then.',
        icon: spec.status == ReviewStatus.rejected ? Icons.block : Icons.warning_amber_outlined,
      );
      if (ok != true) return;
    }
    onQuickPick(spec.status, spec.remarks, spec.label);
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.status,
    required this.remarks,
    this.needsConfirm = false,
    this.confirmTitle,
    this.confirmMessage,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final ReviewStatus status;
  final String remarks;
  final bool needsConfirm;
  final String? confirmTitle;
  final String? confirmMessage;
}
