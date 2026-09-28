import 'package:flutter/material.dart';

/// Shared responsive breakpoints for ACCESS admin web.
abstract final class AdminBreakpoints {
  /// Full sidebar (desktop).
  static const double desktop = 1024;

  /// Collapsible icon rail (tablet).
  static const double tablet = 768;

  static const double sidebarFullWidth = 256;
  static const double sidebarRailWidth = 72;
  static const double drawerWidth = 256;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) => widthOf(context) < tablet;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext context) => widthOf(context) >= desktop;

  /// Drawer on mobile; persistent sidebar on tablet+.
  static bool useDrawer(BuildContext context) => isMobile(context);

  /// Icon-only rail when collapsed (tablet + desktop).
  static bool useSidebarRail(BuildContext context, {required bool collapsed}) =>
      !useDrawer(context) && collapsed;

  static double sidebarWidth(BuildContext context, {required bool collapsed}) {
    if (useDrawer(context)) return 0;
    if (collapsed) return sidebarRailWidth;
    return sidebarFullWidth;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = widthOf(context);
    if (w < 430) return const EdgeInsets.fromLTRB(12, 20, 12, 32);
    if (w < tablet) return const EdgeInsets.fromLTRB(16, 24, 16, 36);
    if (w < desktop) return const EdgeInsets.fromLTRB(16, 16, 16, 24);
    return const EdgeInsets.fromLTRB(20, 16, 20, 28);
  }

  /// Max width for side panels / export dialogs.
  static double panelMaxWidth(BuildContext context, {double desktopMax = 520}) {
    final w = widthOf(context);
    if (w < 430) return w - 24;
    if (w < tablet) return w - 32;
    return desktopMax.clamp(320, desktopMax);
  }

  static double dialogMaxWidth(BuildContext context, {double desktopMax = 560}) {
    final w = widthOf(context);
    if (w < 430) return w * 0.94;
    if (w < tablet) return w * 0.9;
    if (w < desktop) return w * 0.82;
    return desktopMax;
  }

  static int summaryGridColumns(double maxWidth) {
    if (maxWidth >= 1100) return 4;
    if (maxWidth >= 700) return 2;
    return 1;
  }
}

/// Horizontal scroll wrapper — keeps overflow inside the table card.
class ResponsiveTableScroll extends StatefulWidget {
  const ResponsiveTableScroll({
    super.key,
    required this.child,
    this.minTableWidth,
  });

  final Widget child;
  final double? minTableWidth;

  @override
  State<ResponsiveTableScroll> createState() => _ResponsiveTableScrollState();
}

class _ResponsiveTableScrollState extends State<ResponsiveTableScroll> {
  final ScrollController _hCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : AdminBreakpoints.widthOf(context) - 48;
        final minW = widget.minTableWidth ?? (parentW - 8).clamp(320.0, 2400.0);

        return Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minW),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
