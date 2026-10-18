import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Member shell bottom navigation — workflow tabs with Evaluate as the center hero.
///
/// Order: Home · Calendar · **Evaluate** · Gallery · Rankings
/// Profile opens from the header avatar, not the dock.
class MemberBottomNav extends StatelessWidget {
  const MemberBottomNav({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final int selected;
  final ValueChanged<int> onTap;

  static const centerTabIndex = 1;
  /// Fixed content height inside [SafeArea]. Slightly above icon+label stack for text scaling.
  static const barHeight = 68.0;
  static const centerFabSize = 42.0;

  static const _evalFabGradientActive = [
    Color(0xFF0A1628),
    Color(0xFF0C3340),
  ];

  static const _evalFabGradientIdle = [
    Color(0xFF050C1C),
    Color(0xFF0A1628),
  ];

  void _handleTap(int index) {
    HapticFeedback.lightImpact();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AccessColors.of(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: colors.border.withValues(alpha: 0.75)),
          ),
          boxShadow: [
            BoxShadow(
              color: kAccent.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.12,
            child: SizedBox(
              height: barHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                Expanded(
                  child: _MemberSideNavItem(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    active: selected == 0,
                    compact: compact,
                    onTap: () => _handleTap(0),
                  ),
                ),
                Expanded(
                  child: _MemberSideNavItem(
                    label: 'Calendar',
                    icon: Icons.calendar_month_rounded,
                    inactiveIcon: Icons.calendar_month_outlined,
                    active: selected == 2,
                    compact: compact,
                    onTap: () => _handleTap(2),
                  ),
                ),
                Expanded(
                  child: _CenterEvaluateNavItem(
                    active: selected == centerTabIndex,
                    compact: compact,
                    onTap: () => _handleTap(centerTabIndex),
                  ),
                ),
                Expanded(
                  child: _MemberSideNavItem(
                    label: 'Gallery',
                    icon: Icons.photo_library_rounded,
                    inactiveIcon: Icons.photo_library_outlined,
                    active: selected == 3,
                    compact: compact,
                    onTap: () => _handleTap(3),
                  ),
                ),
                Expanded(
                  child: _MemberSideNavItem(
                    label: 'Rankings',
                    icon: Icons.emoji_events_rounded,
                    inactiveIcon: Icons.emoji_events_outlined,
                    active: selected == 5,
                    compact: compact,
                    onTap: () => _handleTap(5),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSideNavItem extends StatelessWidget {
  const _MemberSideNavItem({
    required this.label,
    required this.icon,
    required this.inactiveIcon,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData inactiveIcon;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? kAccent : kIconInactive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 5 : 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: active ? (compact ? 10 : 12) : 8,
                  vertical: active ? 5 : 4,
                ),
                decoration: BoxDecoration(
                  color: active ? kAccent.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  active ? icon : inactiveIcon,
                  color: color,
                  size: compact ? 21 : 22,
                ),
              ),
              SizedBox(height: compact ? 2 : 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 9.5 : 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                  letterSpacing: active ? 0.1 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterEvaluateNavItem extends StatelessWidget {
  const _CenterEvaluateNavItem({
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = active ? kAccent : kIconInactive;
    final fabSize = MemberBottomNav.centerFabSize;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 5 : 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.0 : 0.96,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: active
                          ? MemberBottomNav._evalFabGradientActive
                          : MemberBottomNav._evalFabGradientIdle,
                    ),
                    border: Border.all(
                      color: active
                          ? kCyan.withValues(alpha: 0.55)
                          : kAccent.withValues(alpha: 0.28),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kAccent.withValues(alpha: active ? 0.28 : 0.14),
                        blurRadius: active ? 10 : 6,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: kCyan.withValues(alpha: active ? 0.18 : 0.08),
                        blurRadius: active ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.9),
                    size: compact ? 20 : 21,
                  ),
                ),
              ),
              SizedBox(height: compact ? 2 : 3),
              Text(
                'Evaluate',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: compact ? 9.5 : 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 1,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
