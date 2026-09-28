import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

/// Unified statistic / feature card used across the mobile dashboard and
/// profile screens.
///
/// Visual contract:
/// - Background: theme surface
/// - Border: 1px theme border
/// - Radius: 12
/// - Padding: 14 (compact) / 16 (default)
/// - Icon tile: 38×38, primary accent at 12% opacity, radius 10
/// - Single icon color (primary accent) unless an [iconColor] override is
///   supplied (e.g. semantic highlight on success/warning).
/// - Value: 20, w800
/// - Label: 11, w500, secondary text
///
/// Shared card radius for dashboard / profile stat tiles.
const double kAccessCardRadius = 16;

/// Use this widget everywhere — never hand-roll another stat card.
class AccessStatCard extends StatelessWidget {
  const AccessStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    this.iconColor,
    this.compact = false,
    this.subtitle,
    this.dashboardLayout = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Defaults to [kAccent] (app primary). Pass a semantic color sparingly.
  final Color? iconColor;

  /// Tighter vertical padding for dense rows (e.g. 3-up on small phones).
  final bool compact;

  /// Vertical stack (icon → value → label) for equal-height dashboard grids.
  final bool dashboardLayout;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? kMemberCyan;
    final colors = context.colors;
    final radius = BorderRadius.circular(kAccessCardRadius);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tile = Container(
      constraints: dashboardLayout
          ? const BoxConstraints(minHeight: 108)
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: dashboardLayout ? 14 : (compact ? 12 : 14),
        vertical: dashboardLayout ? 14 : (compact ? 12 : 14),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
        boxShadow: dashboardLayout
            ? memberDashboardCardShadows()
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: dashboardLayout
          ? _buildDashboardBody(colors, color)
          : _buildHorizontalBody(colors, color),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: tile,
      ),
    );
  }

  Widget _iconTile(Color color) {
    final size = dashboardLayout ? 40.0 : (compact ? 34.0 : 38.0);
    final iconSize = dashboardLayout ? 22.0 : (compact ? 18.0 : 20.0);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }

  Widget _buildDashboardBody(AccessColors colors, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _iconTile(color),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHorizontalBody(AccessColors colors, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _iconTile(color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: subtitle == null ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Responsive grid of [AccessStatCard]s. Lays out as 2 columns on phones
/// (>=360 px) and 1 column on very narrow screens.
class AccessStatGrid extends StatelessWidget {
  const AccessStatGrid({
    super.key,
    required this.cards,
    this.spacing = 10,
  });

  final List<AccessStatCard> cards;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = w < 340 ? 1 : 2;
        final tileWidth = (w - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: tileWidth, child: c))
              .toList(),
        );
      },
    );
  }
}

/// Small section header used above stat groups — keeps typography consistent
/// across the app.
class AccessSectionHeader extends StatelessWidget {
  const AccessSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Reusable empty-state tile that matches the card design system. Use for
/// "no completed tasks", "no achievements", etc.
class AccessEmptyCard extends StatelessWidget {
  const AccessEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(kAccessCardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kMemberCyan.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kMemberCyan, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
