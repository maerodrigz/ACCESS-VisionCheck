import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/collapsible_guide_card.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_content_standards_notice.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Collapsible “How It Works” guide for the Member Evaluations page.
class EvaluationHowItWorksGuide extends StatelessWidget {
  const EvaluationHowItWorksGuide({super.key});

  static const _steps = [
    (
      icon: Icons.cloud_upload_rounded,
      title: 'Upload Photo / Video',
      description: 'Select a photo or video to submit for evaluation.',
      accent: Color(0xFF0891B2),
    ),
    (
      icon: Icons.auto_awesome_rounded,
      title: 'AI Analyzes Quality',
      description: 'EfficientNet-B0 scores sharpness, blur, noise, brightness, and more.',
      accent: Color(0xFF7C3AED),
    ),
    (
      icon: Icons.insights_rounded,
      title: 'Get Score & Feedback',
      description: 'View your quality score and friendly tips from Gemini.',
      accent: kAccent,
    ),
    (
      icon: Icons.trending_up_rounded,
      title: 'Improve Your Skills',
      description: 'Apply the feedback, practice, and earn XP as you improve.',
      accent: Color(0xFF16A34A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CollapsibleGuideCard(
      title: 'How It Works',
      subtitle: 'Learn how our AI media evaluation works',
      showSubtitleWhenCollapsed: false,
      darkShell: true,
      children: [
        Text(
          'Learn how our AI media evaluation works',
          style: evalGuideDarkSubtitleStyle,
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _steps.length; i++)
          _GuideStepRow(
            number: i + 1,
            icon: _steps[i].icon,
            title: _steps[i].title,
            description: _steps[i].description,
            accent: _steps[i].accent,
            isLast: i == _steps.length - 1,
          ),
        const SizedBox(height: 12),
        const EvaluationContentStandardsNotice(compact: true, onDarkBackground: true),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kEvalGuideDarkPanel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kEvalGuideDarkBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: kMemberCyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Potentially AI-generated or suspicious media may be flagged for admin review. '
                  'Inappropriate content is handled separately under ACCESS policy.',
                  style: dashText(TextStyle(
                    color: kEvalGuideDarkTextSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  )),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideStepRow extends StatelessWidget {
  const _GuideStepRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.isLast,
  });

  final int number;
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: dashText(const TextStyle(
                    color: kEvalGuideDarkTextPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  )),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: dashText(const TextStyle(
                    color: kEvalGuideDarkTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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
