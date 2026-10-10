import 'package:flutter/material.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';
import 'package:access_mobile/shared/navigation/app_navigator.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/widgets/auth_gate.dart';
import 'package:access_mobile/web_admin/controllers/web_admin_shell.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// ACCESS Sync — Web Admin entry (Google Chrome).
class VisionWebApp extends StatelessWidget {
  const VisionWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: brandingController,
      builder: (_, __) => MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: brandingController.webAdminTitle,
      theme: AdminTheme.materialTheme(),
      home: AuthGate(
        adminBuilder: (user) => WebAdminShell(user: user),
        memberBuilder: (user) => WebAdminShell(user: user), // AuthGate blocks non-admin on web
        organizationBuilder: (user) => WebAdminShell(user: user),
      ),
    ),
    );
  }
}
