import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

/// Reusable collapsible guide card — collapsed by default, tap header to toggle.
class CollapsibleGuideCard extends StatefulWidget {
  const CollapsibleGuideCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.expandLabel = 'View Guide',
    this.collapseLabel = 'Hide Guide',
    this.initiallyExpanded = false,
    this.showSubtitleWhenCollapsed = true,
    this.darkShell = false,
    this.leading,
    this.compact = false,
    this.padding = const EdgeInsets.fromLTRB(
      kMemberDashboardPagePadding,
      16,
      kMemberDashboardPagePadding,
      0,
    ),
  });

  final String title;
  final String subtitle;
  final String expandLabel;
  final String collapseLabel;
  final bool initiallyExpanded;
  final bool showSubtitleWhenCollapsed;
  final bool darkShell;
  final Widget? leading;
  final bool compact;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  State<CollapsibleGuideCard> createState() => _CollapsibleGuideCardState();
}

class _CollapsibleGuideCardState extends State<CollapsibleGuideCard>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 320);

  late bool _expanded;
  late AnimationController _chevronController;
  late Animation<double> _chevronTurns;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _chevronController = AnimationController(vsync: this, duration: _animDuration);
    _chevronTurns = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeInOutCubic),
    );
    if (_expanded) {
      _chevronController.value = 1;
    }
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _chevronController.forward();
      } else {
        _chevronController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = _expanded ? widget.collapseLabel : widget.expandLabel;
    final semanticsLabel = _expanded
        ? '${widget.title}. $actionLabel'
        : '${widget.title}. ${widget.subtitle}. $actionLabel';

    final shellDecoration = widget.darkShell
        ? BoxDecoration(
            gradient: kMemberDarkHeroGradient,
            borderRadius: BorderRadius.circular(kEvalCardRadius),
            border: Border.all(color: kEvalGuideDarkBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(kEvalCardRadius),
            border: Border.all(color: kDashBorder.withValues(alpha: 0.85)),
          );

    final titleStyle = widget.darkShell
        ? evalGuideDarkTitleStyle
        : dashText(TextStyle(
            color: const Color(0xFF1E293B),
            fontSize: widget.compact ? 15 : 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ));
    final subtitleStyle = widget.darkShell
        ? evalGuideDarkSubtitleStyle
        : evalSectionSubtitleStyle.copyWith(fontSize: widget.compact ? 12 : 13);
    final headerPadding = widget.compact
        ? const EdgeInsets.fromLTRB(12, 10, 10, 10)
        : const EdgeInsets.fromLTRB(16, 13, 12, 13);
    final chevronSize = widget.compact ? 22.0 : 26.0;
    final actionFontSize = widget.compact ? 11.0 : 12.0;
    final actionColor = widget.darkShell ? kMemberCyan : kEvalSecondary;
    final dividerColor = widget.darkShell
        ? Colors.white.withValues(alpha: 0.12)
        : kDashBorder.withValues(alpha: 0.9);

    return Padding(
      padding: widget.padding,
      child: DecoratedBox(
        decoration: shellDecoration,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(kEvalCardRadius),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              label: semanticsLabel,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: headerPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.leading != null) ...[
                        widget.leading!,
                        SizedBox(width: widget.compact ? 10 : 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: titleStyle,
                            ),
                            if (widget.showSubtitleWhenCollapsed || _expanded) ...[
                              SizedBox(height: widget.compact ? 2 : 4),
                              Text(
                                widget.subtitle,
                                style: subtitleStyle,
                                maxLines: widget.compact && !_expanded ? 1 : null,
                                overflow: widget.compact && !_expanded
                                    ? TextOverflow.ellipsis
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: widget.compact ? 4 : 8),
                      Text(
                        actionLabel,
                        style: dashText(TextStyle(
                          color: actionColor,
                          fontSize: actionFontSize,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                      const SizedBox(width: 2),
                      RotationTransition(
                        turns: _chevronTurns,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: actionColor,
                          size: chevronSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: _animDuration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: _expanded
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.compact ? 12 : 18,
                        0,
                        widget.compact ? 12 : 18,
                        widget.compact ? 12 : 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Divider(height: 1, color: dividerColor),
                          SizedBox(height: widget.compact ? 10 : 14),
                          ...widget.children,
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        ),
      ),
    );
  }
}