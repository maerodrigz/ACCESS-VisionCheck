import 'package:access_mobile/web_admin/navigation/admin_routes.dart';

/// Breadcrumb segments for each admin route.
List<String> breadcrumbsForRoute(AdminRoute route) {
  if (route == AdminRoute.dashboard) return const ['Dashboard'];

  final leaf = navLeafForRoute(route);
  if (leaf != null) return ['Dashboard', leaf.label];

  return ['Dashboard', _fallbackLabel(route)];
}

String _fallbackLabel(AdminRoute route) {
  return route.name
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
      .trim()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
