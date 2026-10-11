import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

/// Action buttons after a practice evaluation has been saved on the server.
class EvalResultActionBar extends StatelessWidget {
  const EvalResultActionBar({
    super.key,
    required this.onDone,
    required this.onEvaluateAgain,
    this.onDetailedAnalysis,
    this.evaluateAgainLabel,
    this.adminReviewStatus,
    this.compact = false,
  });

  final VoidCallback onDone;
  final VoidCallback onEvaluateAgain;
  final String? evaluateAgainLabel;
  final String? adminReviewStatus;
  final VoidCallback? onDetailedAnalysis;
  final bool compact;

  String get _secondaryLabel {
    if (evaluateAgainLabel != null) return evaluateAgainLabel!;
    final s = (adminReviewStatus ?? '').toLowerCase();
    if (s.contains('reupload')) return 'Re-upload Media';
    if (s.contains('confirmed_ai') || s.contains('verified_ai') || s == 'rejected') {
      return 'Evaluate Again';
    }
    return 'Evaluate Again';
  }

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 6.0 : 10.0;
    final buttonHeight = compact ? 44.0 : 52.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryEvalButton(
          label: 'Back to Practice',
          icon: Icons.check_circle_outline_rounded,
          onPressed: onDone,
          gradient: kEvalHeroGradient,
          shadowAccent: kEvalSecondary,
          height: buttonHeight,
        ),
        SizedBox(height: gap),
        _SecondaryEvalButton(
          label: _secondaryLabel,
          icon: Icons.refresh_rounded,
          onPressed: onEvaluateAgain,
          height: buttonHeight,
        ),
        if (onDetailedAnalysis != null) ...[
          SizedBox(height: gap),
          _SecondaryEvalButton(
            label: 'Detailed Analysis',
            icon: Icons.analytics_outlined,
            onPressed: onDetailedAnalysis,
            accent: kEvalSecondary,
            height: buttonHeight,
          ),
        ],
      ],
    );
  }
}

class _PrimaryEvalButton extends StatelessWidget {
  const _PrimaryEvalButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.gradient,
    this.shadowAccent,
    this.height = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final Color? shadowAccent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled ? kDashBorder : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled || gradient == null
                ? null
                : [
                    BoxShadow(
                      color: (shadowAccent ?? kEvalSecondary).withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: disabled ? kDashTextSecondary : Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: dashText(TextStyle(
                  color: disabled ? kDashTextSecondary : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryEvalButton extends StatelessWidget {
  const _SecondaryEvalButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.accent,
    this.height = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kEvalSecondary;
    final disabled = onPressed == null;

    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: disabled ? kDashTextSecondary : color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: disabled ? kDashTextSecondary : color,
          side: BorderSide(color: disabled ? kDashBorder : color.withValues(alpha: 0.45), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: dashText(TextStyle(fontWeight: FontWeight.w700, fontSize: height <= 48 ? 14 : 16)),
        ),
      ),
    );
  }
}
