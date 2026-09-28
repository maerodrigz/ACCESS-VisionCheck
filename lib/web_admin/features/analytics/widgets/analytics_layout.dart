import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Shared layout tokens — every analytics card uses these.
abstract final class AnalyticsLayout {
  static const gap = 12.0;
  static const cardRadius = 12.0;
  static const cardPadding = EdgeInsets.all(12);
  static const headerGap = 8.0;

  static const rowGap = 12.0;
  static const kpiHeight = 92.0;
  static const middleRowHeight = 240.0;
  static const lowerRowHeight = 248.0;
  static const bottomRowHeight = 180.0;

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AdminTheme.border),
        boxShadow: AdminTheme.cardShadow,
      );

  static TextStyle get cardTitleStyle => const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: AdminTheme.textPrimary,
      );
}

/// Equal-width horizontal gap between grid cells.
Widget analyticsGap({bool vertical = false}) {
  return vertical
      ? const SizedBox(height: AnalyticsLayout.rowGap)
      : const SizedBox(width: AnalyticsLayout.gap);
}

/// One row of equally-stretched children with uniform gap.
class AnalyticsGridRow extends StatelessWidget {
  const AnalyticsGridRow({
    super.key,
    required this.height,
    required this.flexes,
    required this.children,
  });

  final double height;
  final List<int> flexes;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(flexes.length == children.length);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) analyticsGap(),
            Expanded(flex: flexes[i], child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Stacks rows on narrow screens.
class AnalyticsResponsiveBlock extends StatelessWidget {
  const AnalyticsResponsiveBlock({
    super.key,
    required this.wideMinWidth,
    required this.wide,
    required this.narrow,
  });

  final double wideMinWidth;
  final Widget wide;
  final Widget narrow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= wideMinWidth ? wide : narrow,
    );
  }
}
