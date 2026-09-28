import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Premium brand-gradient sidebar for ACCESS VisionCheck admin.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selectedRoute,
    required this.onRouteSelected,
    this.compact = false,
    this.onCloseDrawer,
    this.showCollapseToggle = false,
    this.sidebarCollapsed = false,
    this.onToggleCollapse,
  });

  final AdminRoute selectedRoute;
  final ValueChanged<AdminRoute> onRouteSelected;
  final bool compact;
  final VoidCallback? onCloseDrawer;
  final bool showCollapseToggle;
  final bool sidebarCollapsed;
  final VoidCallback? onToggleCollapse;

  static const _sidePaddingExpanded = 18.0;
  static const _sidePaddingCompact = 12.0;

  void _select(AdminRoute route) {
    onRouteSelected(route);
    onCloseDrawer?.call();
  }

  double _sectionGap(int index) {
    if (index <= 0) return 0;
    final prev = adminSidebarSections[index - 1];
    final curr = adminSidebarSections[index];
    if (prev.label == null && curr.label != null) {
      return compact ? 14 : 20;
    }
    return compact ? 20 : 30;
  }

  @override
  Widget build(BuildContext context) {
    final sidePadding = compact ? _sidePaddingCompact : _sidePaddingExpanded;

    return Container(
      decoration: BoxDecoration(
        gradient: AdminTheme.sidebarGradient,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AdminTheme.sidebarRadius),
          bottomRight: Radius.circular(AdminTheme.sidebarRadius),
        ),
        boxShadow: AdminTheme.sidebarShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SidebarBrandHeader(
              compact: compact,
              showCollapseToggle: showCollapseToggle,
              sidebarCollapsed: sidebarCollapsed,
              onToggleCollapse: onToggleCollapse,
            ),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 20),
                  children: [
                    for (var i = 0; i < adminSidebarSections.length; i++) ...[
                      if (i > 0) SizedBox(height: _sectionGap(i)),
                      _NavSection(
                        section: adminSidebarSections[i],
                        selectedRoute: selectedRoute,
                        compact: compact,
                        onSelect: _select,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarBrandHeader extends StatelessWidget {
  const _SidebarBrandHeader({
    required this.compact,
    this.showCollapseToggle = false,
    this.sidebarCollapsed = false,
    this.onToggleCollapse,
  });

  final bool compact;
  final bool showCollapseToggle;
  final bool sidebarCollapsed;
  final VoidCallback? onToggleCollapse;

  static final _divider = Divider(
    color: Colors.white.withValues(alpha: 0.10),
    height: 1,
    thickness: 1,
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
        child: Column(
          children: [
            AccessSidebarBrand(compact: true, logoSize: 40),
            if (showCollapseToggle && onToggleCollapse != null) ...[
              const SizedBox(height: 8),
              _CollapseButton(
                sidebarCollapsed: sidebarCollapsed,
                onToggleCollapse: onToggleCollapse!,
              ),
            ],
            const SizedBox(height: 16),
            _divider,
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: AccessSidebarBrand(logoSize: 64),
              ),
              if (showCollapseToggle && onToggleCollapse != null)
                _CollapseButton(
                  sidebarCollapsed: sidebarCollapsed,
                  onToggleCollapse: onToggleCollapse!,
                ),
            ],
          ),
          const SizedBox(height: 20),
          _divider,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({
    required this.sidebarCollapsed,
    required this.onToggleCollapse,
  });

  final bool sidebarCollapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggleCollapse,
      icon: Icon(
        sidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        color: Colors.white.withValues(alpha: 0.85),
        size: 20,
      ),
      tooltip: sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        hoverColor: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.section,
    required this.selectedRoute,
    required this.compact,
    required this.onSelect,
  });

  final AdminNavSection section;
  final AdminRoute selectedRoute;
  final bool compact;
  final ValueChanged<AdminRoute> onSelect;

  static final _sectionLabelStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: Colors.white.withValues(alpha: 0.72),
  );

  static final _menuStyle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section.label != null && !compact) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(section.label!, style: _sectionLabelStyle),
          ),
        ],
        for (final leaf in section.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NavTile(
              icon: leaf.icon,
              label: leaf.label,
              selected: navItemMatchesRoute(leaf.route, selectedRoute),
              onTap: () => onSelect(leaf.route),
              compact: compact,
              menuStyle: _menuStyle,
            ),
          ),
      ],
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.menuStyle,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle menuStyle;
  final bool compact;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  static final _radius = BorderRadius.circular(AdminTheme.sidebarItemRadius);

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: _radius,
        hoverColor: Colors.transparent,
        splashColor: Colors.white.withValues(alpha: 0.10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : (_hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
            borderRadius: _radius,
            boxShadow: selected ? AdminTheme.sidebarActiveShadow : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 0 : 18,
            vertical: 12,
          ),
          child: widget.compact
              ? Center(
                  child: Icon(
                    widget.icon,
                    size: 21,
                    color: selected ? AdminTheme.accentBlue : Colors.white,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 21,
                      color: selected ? AdminTheme.accentBlue : Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: widget.menuStyle.copyWith(
                          color: selected ? AdminTheme.accentBlue : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.compact
          ? Tooltip(message: widget.label, waitDuration: const Duration(milliseconds: 400), child: tile)
          : tile,
    );
  }
}
