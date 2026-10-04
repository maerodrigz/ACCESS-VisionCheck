import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

/// Large tap-friendly action buttons for evaluation result flows.
class EvalResultActionBar extends StatelessWidget {
  const EvalResultActionBar({
    super.key,
    required this.onSave,
    required this.onEvaluateAgain,
    this.onDetailedAnalysis,
    this.isSaving = false,
    this.atLimit = false,
    this.evaluationAlreadySaved = false,
    this.evaluateAgainLabel,
    this.adminReviewStatus,
    this.compact = false,
  });

  final VoidCallback onSave;
  final VoidCallback onEvaluateAgain;
  final String? evaluateAgainLabel;
  final String? adminReviewStatus;
  final VoidCallback? onDetailedAnalysis;
  final bool isSaving;
  final bool atLimit;
  final bool evaluationAlreadySaved;
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
    final gap = compact ? 8.0 : 12.0;
    final buttonHeight = compact ? 48.0 : 56.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryEvalButton(
          label: evaluationAlreadySaved
              ? 'Back to Practice'
              : (atLimit ? 'Daily Limit Reached' : 'Save Evaluation'),
          icon: evaluationAlreadySaved
              ? Icons.check_circle_outline_rounded
              : (atLimit ? Icons.block_rounded : Icons.save_alt_rounded),
          onPressed: isSaving || (!evaluationAlreadySaved && atLimit) ? null : onSave,
          isLoading: isSaving && !evaluationAlreadySaved,
          gradient: atLimit && !evaluationAlreadySaved
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
          backgroundColor: atLimit && !evaluationAlreadySaved ? kDashBorder : null,
          height: buttonHeight,
        ),
        SizedBox(height: gap),
        _SecondaryEvalButton(
          label: _secondaryLabel,
          icon: Icons.refresh_rounded,
          onPressed: isSaving ? null : onEvaluateAgain,
          height: buttonHeight,
        ),
        if (onDetailedAnalysis != null) ...[
          SizedBox(height: gap),
          _SecondaryEvalButton(
            label: 'Detailed Analysis',
            icon: Icons.analytics_outlined,
            onPressed: isSaving ? null : onDetailedAnalysis,
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
    this.isLoading = false,
    this.gradient,
    this.backgroundColor,
    this.height = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient? gradient;
  final Color? backgroundColor;
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
            color: disabled ? (backgroundColor ?? kDashBorder) : backgroundColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled || gradient == null
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              else
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
