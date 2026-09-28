import 'package:flutter/material.dart';

/// Unique route ids for every admin page (used by sidebar + content router).
enum AdminRoute {
  dashboard,

  // Documentation Management
  docRequests,
  requestStatus,
  eventCalendar,
  taskAssignments,

  // Media Management
  mediaRepository,
  mediaEvaluation,
  aiDetection,

  // User Management
  registrationApprovals,
  members,
  roles,
  skillClassification,
  rankings,

  // Reports & Analytics
  analyticsDashboard,
  participationReports,
  feedbackReports,

  // System
  notifications,
  systemMonitor,
  branding,
}

class AdminNavLeaf {
  const AdminNavLeaf({
    required this.route,
    required this.label,
    required this.icon,
    this.subtitle,
    this.card = false,
  });

  final AdminRoute route;
  final String label;
  final IconData icon;
  final String? subtitle;
  final bool card;
}

/// Grouped sidebar section with optional uppercase label.
class AdminNavSection {
  const AdminNavSection({this.label, required this.items});

  final String? label;
  final List<AdminNavLeaf> items;
}

/// Workflow-based sidebar — reflects the documentation lifecycle.
const adminSidebarSections = [
  AdminNavSection(
    items: [
      AdminNavLeaf(route: AdminRoute.dashboard, label: 'Dashboard', icon: Icons.home_outlined),
    ],
  ),
  AdminNavSection(
    label: 'OPERATIONS',
    items: [
      AdminNavLeaf(route: AdminRoute.docRequests, label: 'Documentation Requests', icon: Icons.description_outlined),
      AdminNavLeaf(route: AdminRoute.members, label: 'Members', icon: Icons.groups_outlined),
      AdminNavLeaf(route: AdminRoute.mediaRepository, label: 'Media Library', icon: Icons.photo_library_outlined),
      AdminNavLeaf(route: AdminRoute.mediaEvaluation, label: 'Media Integrity', icon: Icons.verified_user_outlined),
    ],
  ),
  AdminNavSection(
    label: 'PERFORMANCE',
    items: [
      AdminNavLeaf(route: AdminRoute.feedbackReports, label: 'Requester Feedback', icon: Icons.star_outline),
      AdminNavLeaf(route: AdminRoute.skillClassification, label: 'Competency Management', icon: Icons.workspace_premium_outlined),
      AdminNavLeaf(route: AdminRoute.analyticsDashboard, label: 'Analytics', icon: Icons.bar_chart_outlined),
    ],
  ),
  AdminNavSection(
    label: 'SYSTEM',
    items: [
      AdminNavLeaf(route: AdminRoute.roles, label: 'Account Management', icon: Icons.manage_accounts_outlined),
    ],
  ),
];

/// Flat list of all sidebar leaves (for iteration helpers).
List<AdminNavLeaf> get adminSidebarLeaves =>
    adminSidebarSections.expand((s) => s.items).toList();

/// Profile menu + off-sidebar routes for breadcrumbs.
const adminProfileMenuItems = [
  AdminNavLeaf(route: AdminRoute.branding, label: 'System Configuration', icon: Icons.settings_outlined),
];

const adminOffSidebarNavItems = [
  AdminNavLeaf(route: AdminRoute.notifications, label: 'Notification Center', icon: Icons.notifications_outlined),
];

/// Combined list for breadcrumb lookup.
List<AdminNavLeaf> get adminFlatNavItems => [
      ...adminSidebarLeaves,
      ...adminOffSidebarNavItems,
      ...adminProfileMenuItems,
    ];

const dashboardNavLeaf = AdminNavLeaf(
  route: AdminRoute.dashboard,
  label: 'Dashboard',
  icon: Icons.home_outlined,
);

/// Whether [current] should highlight the sidebar item for [item].
bool navItemMatchesRoute(AdminRoute item, AdminRoute current) {
  if (item == current) return true;
  return switch (item) {
    AdminRoute.docRequests =>
      current == AdminRoute.requestStatus || current == AdminRoute.taskAssignments,
    AdminRoute.members => current == AdminRoute.registrationApprovals,
    _ => false,
  };
}

AdminNavLeaf? navLeafForRoute(AdminRoute route) {
  for (final leaf in adminFlatNavItems) {
    if (navItemMatchesRoute(leaf.route, route)) return leaf;
  }
  return null;
}

// Legacy grouped structure — kept for any tooling that still references it.
class AdminNavGroup {
  const AdminNavGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<AdminNavLeaf> children;
  final bool initiallyExpanded;
}

const adminNavGroups = <AdminNavGroup>[];

AdminNavGroup? groupContainingRoute(AdminRoute route) => null;

/// @deprecated Use [adminSidebarLeaves] instead.
List<AdminNavLeaf> get adminMainNavItems => adminSidebarLeaves;
