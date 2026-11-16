import 'package:flutter/material.dart';
import 'package:access_mobile/shared/screens/member_registration_screen.dart';
import 'package:access_mobile/shared/screens/requestor_type_selection_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_navigation.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_scaffold.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';

/// Onboarding preference: member vs requestor registration entry (no role assignment).
class MobileChooseExperienceScreen extends StatelessWidget {
  const MobileChooseExperienceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileAuthScaffold.signUp(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MobileAuthBackButton(),
          const MobileAuthSectionHeader(
            title: 'Choose Your Experience!',
            subtitle: 'Pick how you will use ACCESS VisionCheck!',
            compact: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'This only guides you to the right registration form. Your account role is '
            'set when an administrator approves your registration.',
            style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 22),
          RegistrationTypeCard(
            title: 'Member',
            subtitle:
                'Analyze media authenticity, explore quality insights, and enhance your skills through hands-on practice!',
            icon: Icons.groups_rounded,
            mobileAuthStyle: true,
            onTap: () => _openMemberRegistration(context),
          ),
          const SizedBox(height: 12),
          RegistrationTypeCard(
            title: 'Requestor',
            subtitle:
                'Request documentation services, track your request status, and share feedback on completed services!',
            icon: Icons.description_rounded,
            mobileAuthStyle: true,
            onTap: () => _openRequestorRegistration(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openMemberRegistration(BuildContext context) async {
    final email = await pushMobileAuthPage<String>(
      context,
      const MemberRegistrationScreen(),
    );
    if (email != null && context.mounted) {
      Navigator.pop(context, email);
    }
  }

  Future<void> _openRequestorRegistration(BuildContext context) async {
    final email = await pushMobileAuthPage<String>(
      context,
      const RequestorTypeSelectionScreen(),
    );
    if (email != null && context.mounted) {
      Navigator.pop(context, email);
    }
  }
}
