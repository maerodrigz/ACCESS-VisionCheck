import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_rankings_xp_config.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Upload standards for practice evaluations (quality + appropriate content).
class EvaluationContentStandardsNotice extends StatelessWidget {
  const EvaluationContentStandardsNotice({
    super.key,
    this.compact = false,
    this.onDarkBackground = false,
  });

  final bool compact;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final titleColor = onDarkBackground ? kEvalGuideDarkTextPrimary : kDashTextPrimary;
    final bodyColor = onDarkBackground ? kEvalGuideDarkTextSecondary : kDashTextSecondary.withValues(alpha: 0.95);
    final panelColor = onDarkBackground ? kEvalGuideDarkPanel : kEvalPrimaryLight.withValues(alpha: 0.4);
    final borderColor = onDarkBackground ? kEvalGuideDarkBorder : kBorder;
    final iconColor = onDarkBackground ? kMemberCyan : kAccent;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.policy_outlined,
            size: compact ? 16 : 18,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MemberXpConfig.contentStandardsTitle,
                  style: dashText(TextStyle(
                    color: titleColor,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  )),
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  compact ? MemberXpConfig.contentStandardsSummary : MemberXpConfig.contentStandardsDetail,
                  style: dashText(TextStyle(
                    color: bodyColor,
                    fontSize: compact ? 11 : 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EvaluationContentStandardsCheckbox extends StatelessWidget {
  const EvaluationContentStandardsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.onDarkBackground = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final bgColor = onDarkBackground ? kEvalGuideDarkPanel : kDashCardBg;
    final borderColor = onDarkBackground
        ? (value ? kMemberCyan.withValues(alpha: 0.45) : kEvalGuideDarkBorder)
        : (value ? kEvalPrimary.withValues(alpha: 0.45) : kDashBorder);
    final textStyle = onDarkBackground
        ? evalGuideDarkSubtitleStyle.copyWith(fontSize: 12, height: 1.35)
        : evalBodyStyle.copyWith(fontSize: 12, height: 1.35);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: onDarkBackground ? kMemberCyan : kEvalPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    MemberXpConfig.contentStandardsCheckbox,
                    style: textStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
