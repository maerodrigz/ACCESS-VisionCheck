import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/collapsible_guide_card.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_content_standards_notice.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Collapsible “How It Works” guide for the Member Evaluations page.
class EvaluationHowItWorksGuide extends StatelessWidget {
  const EvaluationHowItWorksGuide({super.key});

  static const _steps = [
    (
      icon: Icons.cloud_upload_rounded,
      title: 'Choose Photo or Video',
      description: 'Pick a file and confirm it meets ACCESS content standards.',
      accent: Color(0xFF0891B2),
    ),
    (
      icon: Icons.play_circle_outline_rounded,
      title: 'Start AI Evaluation',
      description: 'Tap Start to upload. This counts as one of your daily practice submissions.',
      accent: Color(0xFF7C3AED),
    ),
    (
      icon: Icons.auto_awesome_rounded,
      title: 'Server Analysis',
      description: 'ACCESS scores quality and integrity on the server (EfficientNet-B0 and PROBE).',
      accent: kAccent,
    ),
    (
      icon: Icons.insights_rounded,
      title: 'View Results',
      description: 'See your score, mentor tips from Gemini, and any admin review status.',
      accent: Color(0xFF16A34A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CollapsibleGuideCard(
      title: 'How It Works',
      subtitle: 'Learn how media evaluation works.',
      showSubtitleWhenCollapsed: false,
      compact: true,
      expandLabel: 'Guide',
      collapseLabel: 'Hide',
      darkShell: false,
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        8,
        kMemberDashboardPagePadding,
        0,
      ),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: kCyanDim,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kAccent.withValues(alpha: 0.14)),
        ),
        child: const Icon(Icons.menu_book_rounded, color: kAccent, size: 17),
      ),
      children: [
        for (var i = 0; i < _steps.length; i++)
          _GuideStepRow(
            number: i + 1,
            icon: _steps[i].icon,
            title: _steps[i].title,
            description: _steps[i].description,
            accent: _steps[i].accent,
            isLast: i == _steps.length - 1,
          ),
        const SizedBox(height: 8),
        const EvaluationContentStandardsNotice(compact: true),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
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
                  style: dashText(const TextStyle(
                    color: kTextSecondary,
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
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: dashText(const TextStyle(
                    color: kTextPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  )),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: dashText(const TextStyle(
                    color: kTextSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.32,
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
