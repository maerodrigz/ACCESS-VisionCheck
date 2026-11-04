import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/mobile_welcome_screen.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

/// Nested stack for Welcome → Sign In / Get Started → registration (mobile, logged out).
class MobileOnboardingNavigator extends StatelessWidget {
  const MobileOnboardingNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MobileAuthConstants.midnightScaffoldColor,
      child: Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const MobileWelcomeScreen(),
          );
        },
      ),
    );
  }
}
