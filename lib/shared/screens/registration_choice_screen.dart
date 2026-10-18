import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/screens/member_registration_screen.dart';
import 'package:access_mobile/shared/screens/requestor_type_selection_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_scaffold.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';
import 'package:access_mobile/shared/copy/mobile_registration_copy.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';

/// Mobile-only: choose member or requestor registration.
class RegistrationChoiceScreen extends StatelessWidget {
  const RegistrationChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kIsWeb) const MobileAuthBackButton(),
        const MobileAuthSectionHeader(
          title: MobileRegistrationCopy.choiceTitle,
          subtitle: MobileRegistrationCopy.choiceSubtitle,
        ),
        const SizedBox(height: 8),
        const Text(
          MobileRegistrationCopy.choiceBody,
          style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 22),
        RegistrationTypeCard(
          title: 'Register as Member',
          subtitle: 'Student photographers, videographers, and editors',
          icon: Icons.groups_rounded,
          mobileAuthStyle: !kIsWeb,
          onTap: () async {
            final email = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const MemberRegistrationScreen()),
            );
            if (email != null && context.mounted) {
              Navigator.pop(context, email);
            }
          },
        ),
        const SizedBox(height: 12),
        RegistrationTypeCard(
          title: 'Register as Requestor',
          subtitle: 'Faculty, staff, and student organizations',
          icon: Icons.description_rounded,
          mobileAuthStyle: !kIsWeb,
          onTap: () async {
            final email = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => const RequestorTypeSelectionScreen(),
              ),
            );
            if (email != null && context.mounted) {
              Navigator.pop(context, email);
            }
          },
        ),
        const SizedBox(height: 24),
        MobileAuthTextLinkRow(
          prompt: 'Already have an account?',
          linkLabel: 'Sign In',
          onLinkTap: () => Navigator.pop(context),
        ),
      ],
    );

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Create Account',
            style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ),
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: body)),
      );
    }

    return MobileAuthScaffold(body: body);
  }
}
