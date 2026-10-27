import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';

/// Split integrity UI: admin verification, AI risk, and camera metadata/provenance.
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

    final adminModel = memberAdminVerificationPanelModel(
      automated: aiDetection,
      adminReviewStatus: adminReviewStatus,
      evaluationResult: evaluationResult,
    );
    if (adminModel != null) {
      children.add(
        _IntegrityPanelCard(
          model: adminModel,
          compact: compact,
          accentColor: _adminAccentColor(adminModel),
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

    if (memberShowCameraMetadataPanel(
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
          accentColor: provModel.colorKind == MemberIntegrityColorKind.green ? kGreen : kYellow,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Color _adminAccentColor(MemberIntegrityPanelModel model) => switch (model.colorKind) {
        MemberIntegrityColorKind.green => kGreen,
        MemberIntegrityColorKind.red => kRed,
        MemberIntegrityColorKind.yellow => kYellow,
        MemberIntegrityColorKind.accent => kAccent,
        _ => kAccent,
      };
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
