import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Split integrity UI: overall review status, AI risk, and camera provenance.
class EvaluationIntegrityPanels extends StatelessWidget {
  const EvaluationIntegrityPanels({
    super.key,
    required this.aiDetection,
    this.adminReviewStatus,
    this.evaluationResult,
    this.compact = false,
    this.minimalAiDetail = false,
  });

  final AiDetectionResult aiDetection;
  final String? adminReviewStatus;
  final PhotoEvaluationResult? evaluationResult;
  final bool compact;
  /// When true, AI panel shows tier, stats, and a short disclaimer only.
  final bool minimalAiDetail;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (memberShowOverallMediaUnderReview(
      automated: aiDetection,
      adminReviewStatus: adminReviewStatus,
    )) {
      children.add(
        _IntegrityPanelCard(
          model: MemberIntegrityPanelModel(
            sectionTitle: 'Overall Evaluation Status',
            tierLabel: 'Media under review',
            detail: memberOverallReviewPanelDetail(result: evaluationResult),
            colorKind: MemberIntegrityColorKind.neutral,
            iconKind: MemberIntegrityIconKind.pending,
          ),
          compact: compact,
          accentColor: kAccent,
        ),
      );
      children.add(SizedBox(height: compact ? 8 : 10));
    }

    final aiModel = memberAiAuthenticityPanelModel(
      automated: aiDetection,
      adminReviewStatus: adminReviewStatus,
    );
    children.add(
      _IntegrityPanelCard(
        model: aiModel,
        compact: compact,
        minimalDetail: minimalAiDetail,
        accentColor: memberIntegrityTierColor(aiModel.tierLabel),
      ),
    );

    if (MemberReviewStatus.isAdminConfirmedHuman(adminReviewStatus)) {
      children.add(SizedBox(height: compact ? 8 : 10));
      children.add(
        _IntegrityPanelCard(
          model: memberCameraProvenanceAdminCompletedPanelModel(),
          compact: compact,
          accentColor: kGreen,
        ),
      );
    } else if (memberShowCameraProvenancePanel(
      automated: aiDetection,
      adminReviewStatus: adminReviewStatus,
    )) {
      children.add(SizedBox(height: compact ? 8 : 10));
      final provModel = memberCameraProvenancePanelModel(
        automated: aiDetection,
        adminReviewStatus: adminReviewStatus,
      );
      children.add(
        _IntegrityPanelCard(
          model: provModel,
          compact: compact,
          accentColor: kYellow,
        ),
      );
    } else if (!memberShowOverallMediaUnderReview(
          automated: aiDetection,
          adminReviewStatus: adminReviewStatus,
        ) &&
        aiDetection.isCameraProvenanceStrong &&
        aiModel.tierLabel == 'Low AI Risk') {
      children.add(SizedBox(height: compact ? 8 : 10));
      children.add(
        _IntegrityPanelCard(
          model: const MemberIntegrityPanelModel(
            sectionTitle: 'Camera Provenance Verification',
            tierLabel: 'Camera metadata verified',
            detail:
                'Original capture metadata met automated provenance checks. '
                'This supports authenticity screening but is not a substitute for officer review when required.',
            colorKind: MemberIntegrityColorKind.green,
            iconKind: MemberIntegrityIconKind.verified,
          ),
          compact: compact,
          accentColor: kGreen,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _IntegrityPanelCard extends StatelessWidget {
  const _IntegrityPanelCard({
    required this.model,
    required this.compact,
    required this.accentColor,
    this.minimalDetail = false,
  });

  final MemberIntegrityPanelModel model;
  final bool compact;
  final Color accentColor;
  final bool minimalDetail;

  @override
  Widget build(BuildContext context) {
    final color = accentColor;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(model.iconKind), size: compact ? 16 : 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.sectionTitle,
                      style: TextStyle(
                        color: kDashTextSecondary,
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.tierLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: minimalDetail ? 14 : (compact ? 15 : 17),
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (model.statsLine != null) ...[
            const SizedBox(height: 8),
            Text(
              model.statsLine!,
              style: TextStyle(
                color: kDashTextSecondary,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          if (!minimalDetail) ...[
            const SizedBox(height: 8),
            Text(
              model.detail,
              style: TextStyle(
                color: kDashTextSecondary,
                fontSize: compact ? 11 : 12,
                height: 1.35,
              ),
            ),
            if (model.evidenceLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Available evidence',
                style: TextStyle(
                  color: kDashTextSecondary,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ...model.evidenceLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: kDashTextSecondary,
                          fontSize: compact ? 11 : 12,
                          height: 1.35,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line,
                          style: TextStyle(
                            color: kDashTextSecondary,
                            fontSize: compact ? 11 : 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Text(
              model.detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kDashTextSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(MemberIntegrityIconKind kind) => switch (kind) {
        MemberIntegrityIconKind.verified => Icons.verified_outlined,
        MemberIntegrityIconKind.warning => Icons.warning_amber_rounded,
        MemberIntegrityIconKind.ai => Icons.smart_toy_outlined,
        MemberIntegrityIconKind.pending => Icons.hourglass_top_rounded,
        MemberIntegrityIconKind.neutral => Icons.info_outline_rounded,
      };
}
