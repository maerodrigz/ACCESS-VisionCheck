import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Gap between the title bar and the purpose line (keep modest).
const kRequestorPurposeTopGap = 6.0;
const kRequestorPurposeBottomGap = 8.0;

TextStyle requestorFeatureTitleStyle({double fontSize = 22}) {
  return dashText(TextStyle(
    color: kTextPrimary,
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    letterSpacing: fontSize >= 24 ? -0.4 : -0.3,
    height: 1.15,
  ));
}

TextStyle get requestorFeaturePurposeStyle => memberDashboardMetaStyle.copyWith(
      fontSize: 12,
      height: 1.35,
      color: kTextSecondary,
    );

/// Top bar only: feature name + notification/profile actions.
class RequestorFeatureTitleBar extends StatelessWidget {
  const RequestorFeatureTitleBar({
    super.key,
    required this.title,
    this.titleFontSize = 22,
    this.trailing = const [],
    this.lightBand = true,
  });

  final String title;
  final double titleFontSize;
  final List<Widget> trailing;

  /// Light header band (requests/feedback). Calendar/gallery use [lightBand: false].
  final bool lightBand;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final row = Padding(
      padding: EdgeInsets.fromLTRB(padding, 6, padding, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: requestorFeatureTitleStyle(fontSize: titleFontSize),
            ),
          ),
          ...trailing,
        ],
      ),
    );

    if (!lightBand) {
      return SafeArea(bottom: false, child: row);
    }

    return Material(
      color: kSurface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.9))),
        ),
        child: SafeArea(bottom: false, child: row),
      ),
    );
  }
}

/// Purpose copy — always **below** [RequestorFeatureTitleBar], not inside it.
class RequestorFeaturePurposeLine extends StatelessWidget {
  const RequestorFeaturePurposeLine({
    super.key,
    required this.text,
    this.padding,
  });

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final horizontal = mobilePagePaddingOf(context);
    return ColoredBox(
      color: kBg,
      child: Padding(
        padding: padding ??
            EdgeInsets.fromLTRB(
              horizontal,
              kRequestorPurposeTopGap,
              horizontal,
              kRequestorPurposeBottomGap,
            ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: requestorFeaturePurposeStyle,
          ),
        ),
      ),
    );
  }
}
