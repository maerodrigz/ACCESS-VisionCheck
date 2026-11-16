import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/screens/platform_redirect_screen.dart';
import 'package:access_mobile/shared/screens/vision_login_screen.dart';

/// Routes authenticated users to the correct platform by role.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.adminBuilder,
    required this.memberBuilder,
    this.organizationBuilder,
    this.mobileUnauthenticatedChild,
  });

  final Widget Function(AuthUser user) adminBuilder;
  final Widget Function(AuthUser user) memberBuilder;
  final Widget Function(AuthUser user)? organizationBuilder;

  /// Mobile-only welcome / onboarding stack (nested [Navigator]). Web uses [VisionLoginScreen].
  final Widget? mobileUnauthenticatedChild;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        final user = authController.user;
        if (user == null) {
          if (!kIsWeb && mobileUnauthenticatedChild != null) {
            return mobileUnauthenticatedChild!;
          }
          return const VisionLoginScreen();
        }
        return _routeForRole(user);
      },
    );
  }

  Widget _routeForRole(AuthUser user) {
    if (user.role.isAdmin) {
      if (kIsWeb) return adminBuilder(user);
      return PlatformRedirectScreen(
        user: user,
        expectedPlatform: 'Web Admin (Google Chrome)',
        onLogout: authController.logout,
      );
    }

    if (user.role.isOrganization) {
      final builder = organizationBuilder ?? memberBuilder;
      if (!kIsWeb) return builder(user);
      return PlatformRedirectScreen(
        user: user,
        expectedPlatform: 'Mobile App (Android Emulator)',
        onLogout: authController.logout,
      );
    }

    // Member
    if (!kIsWeb) return memberBuilder(user);
    return PlatformRedirectScreen(
      user: user,
      expectedPlatform: 'Mobile App (Android Emulator)',
      onLogout: authController.logout,
    );
  }
}
