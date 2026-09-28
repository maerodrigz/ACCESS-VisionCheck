import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

// ACCESS VisionCheck — Evaluation tab (aligned with member design system)
const kEvalPrimary = kMemberCyan;
const kEvalPrimaryLight = kCyanDim;
const kEvalSecondary = kMemberPrimary;
const kEvalSecondaryLight = kBlueDim;
const kEvalBg = kMemberDashboardBg;
const kEvalHeroRadius = 20.0;
const kEvalCardRadius = kMemberDashboardCardRadius;
const kEvalInnerRadius = kMemberDashboardInnerRadius;

LinearGradient get kEvalHeroGradient => LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        kEvalPrimary.withValues(alpha: 0.95),
        kEvalSecondary.withValues(alpha: 0.92),
      ],
    );

List<BoxShadow> evalHeroShadows = [
  BoxShadow(
    color: kEvalPrimary.withValues(alpha: 0.14),
    blurRadius: 16,
    offset: const Offset(0, 6),
  ),
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

LinearGradient get kEvalSoftGradient => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        kEvalPrimaryLight,
        kEvalSecondaryLight,
      ],
    );

List<BoxShadow> evalCardShadows({Color? tint}) => memberDashboardCardShadows(tint: tint);

BoxDecoration evalCardDecoration({Color? backgroundColor, Color? borderColor}) {
  return memberDashboardCardDecoration(
    backgroundColor: backgroundColor,
    borderColor: borderColor,
  );
}

TextStyle get evalSectionTitleStyle => memberDashboardSectionTitleStyle;

TextStyle get evalSectionSubtitleStyle => memberDashboardSectionSubtitleStyle;

TextStyle get evalCardTitleStyle => memberDashboardCardTitleStyle;

TextStyle get evalBodyStyle => memberDashboardBodyStyle;

/// Dark shell for the evaluations "How It Works" guide (matches member dark hero).
const kEvalGuideDarkTextPrimary = Color(0xFFF8FAFC);
const kEvalGuideDarkTextSecondary = Color(0xFF94A3B8);
const kEvalGuideDarkBorder = Color(0x24FFFFFF);
const kEvalGuideDarkPanel = Color(0x14FFFFFF);

TextStyle get evalGuideDarkTitleStyle => dashText(const TextStyle(
      color: kEvalGuideDarkTextPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ));

TextStyle get evalGuideDarkSubtitleStyle => dashText(const TextStyle(
      color: kEvalGuideDarkTextSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ));
