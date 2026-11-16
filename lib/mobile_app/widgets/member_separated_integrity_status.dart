import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Compact three-row strip: AI Risk, Source Provenance, Admin Verification.
/// Display only; does not change review, XP, or scoring rules.
class MemberSeparatedIntegrityStatusStrip extends StatelessWidget {
  const MemberSeparatedIntegrityStatusStrip({
    super.key,
    required this.automated,
    this.adminReviewStatus,
    this.dense = false,
    this.embedded = false,
  });

  final AiDetectionResult automated;
  final String? adminReviewStatus;
  final bool dense;

  /// When true, omit outer card chrome (for nesting inside Media Check).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final status = memberSeparatedIntegrityStatus(
      automated: automated,
      adminReviewStatus: adminReviewStatus,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrity status',
          style: dashText(TextStyle(
            color: kTextSecondary,
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w700,
          )),
        ),
        SizedBox(height: dense ? 8 : 10),
        _StatusRow(
          label: 'AI Risk',
          value: status.aiRiskLabel,
          color: _aiColor(status.aiRiskLabel),
          dense: dense,
        ),
        SizedBox(height: dense ? 6 : 8),
        _StatusRow(
          label: 'Source Provenance',
          value: status.sourceProvenanceLabel,
          color: _provenanceColor(status.sourceProvenanceLabel),
          dense: dense,
        ),
        SizedBox(height: dense ? 6 : 8),
        _StatusRow(
          label: 'Admin Verification',
          value: status.adminVerificationLabel,
          color: _adminColor(status.adminVerificationLabel),
          dense: dense,
        ),
      ],
    );

    if (embedded) return body;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(dense ? 12 : 14, dense ? 10 : 12, dense ? 12 : 14, dense ? 10 : 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: body,
    );
  }

  Color _aiColor(String label) {
    if (label.contains('High')) return kRed;
    if (label == 'Needs Review' || label.contains('unavailable') || label.contains('pending')) {
      return kYellow;
    }
    return kGreen;
  }

  Color _provenanceColor(String label) {
    if (label == 'Device metadata present') return kGreen;
    if (label == 'Unknown') return kTextSecondary;
    return kYellow;
  }

  Color _adminColor(String label) {
    if (label == 'Verified' || label == 'Not required') return kGreen;
    if (label == 'Rejected') return kRed;
    return kYellow;
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
    required this.dense,
  });

  final String label;
  final String value;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: dense ? 118 : 132,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: memberDashboardMetaStyle.copyWith(
              fontSize: dense ? 11 : 11.5,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: color,
                  fontSize: dense ? 11 : 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                )),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
