import 'package:flutter/material.dart';
import 'package:access_mobile/shared/models/member_milestone.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

/// Congratulatory dialog for a server-awarded milestone.
Future<void> showMemberMilestoneCelebration(
  BuildContext context,
  MemberMilestone milestone,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: milestone.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: milestone.accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(milestone.icon, color: milestone.accentColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Congratulations!',
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                )),
              ),
              const SizedBox(height: 8),
              Text(
                milestone.title,
                textAlign: TextAlign.center,
                style: dashText(TextStyle(
                  color: milestone.accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
              ),
              const SizedBox(height: 10),
              Text(
                milestone.message,
                textAlign: TextAlign.center,
                style: dashText(const TextStyle(
                  color: kTextSecondary,
                  fontSize: 13,
                  height: 1.45,
                )),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: kMobileMinTouch,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: kMemberButtonPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows each unacknowledged milestone in order, then calls [onAcknowledge].
Future<void> celebrateUnacknowledgedMilestones(
  BuildContext context, {
  required List<MemberMilestone> milestones,
  required Future<void> Function(MemberMilestone milestone) onAcknowledge,
}) async {
  for (final milestone in milestones) {
    if (!context.mounted) return;
    await showMemberMilestoneCelebration(context, milestone);
    await onAcknowledge(milestone);
  }
}
