import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/mobile_choose_experience_screen.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_welcome_scaffold.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';
import 'package:access_mobile/shared/screens/vision_login_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_navigation.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';

/// First-run welcome for logged-out mobile users (after splash).
class MobileWelcomeScreen extends StatelessWidget {
  const MobileWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final compact = w < 360;
    final short = h < 640;
    final topInset = short ? 0.19 : 0.21;

    return MobileWelcomeScaffold(
      topInsetFactor: topInset,
      bottomPaddingExtra: short ? 22 : 28,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WelcomeBrandBlock(compact: compact),
          SizedBox(height: compact ? 14 : 16),
          Text(
            'Explore media authenticity, assess quality, and build confidence in digital content!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kTextSecondary,
              fontSize: compact ? 13 : 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 16 : 20),
          _WelcomeInfoCard(
            compact: compact,
            label: 'MEMBER',
            description:
                'Analyze media authenticity, explore quality insights, and enhance your skills through hands-on practice!',
            icon: Icons.groups_rounded,
          ),
          SizedBox(height: compact ? 10 : 12),
          _WelcomeInfoCard(
            compact: compact,
            label: 'REQUESTOR',
            description:
                'Request documentation services, track your request status, and share feedback on completed services!',
            icon: Icons.fact_check_rounded,
          ),
          SizedBox(height: compact ? 20 : 24),
          MobileAuthGradientButton(
            label: 'Get Started',
            compact: compact,
            onPressed: () => _openGetStarted(context),
          ),
          SizedBox(height: compact ? 12 : 14),
          _WelcomeSignInLink(onSignIn: () => _openSignIn(context)),
        ],
      ),
    );
  }

  Future<void> _openSignIn(BuildContext context) async {
    await pushMobileAuthPage<void>(context, const VisionLoginScreen());
  }

  Future<void> _openGetStarted(BuildContext context) async {
    final registeredEmail = await pushMobileAuthPage<String>(
      context,
      const MobileChooseExperienceScreen(),
    );
    if (!context.mounted) return;
    if (registeredEmail != null && registeredEmail.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration submitted. Sign in after an administrator approves your account.',
          ),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _WelcomeBrandBlock extends StatelessWidget {
  const _WelcomeBrandBlock({required this.compact});

  final bool compact;

  static const _navy = MobileAuthConstants.midnightScaffoldColor;
  static const _cyan = MobileAuthConstants.visionCheckBrightCyan;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 64.0 : 72.0;
    final line1Size = compact ? 18.0 : 20.0;
    final line2Size = compact ? 21.0 : 23.0;
    final taglineSize = compact ? 11.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AccessOrgSealLogo(
          size: logoSize,
          showShadow: true,
          showWhitePlate: true,
          paddingFraction: 0.02,
        ),
        SizedBox(height: compact ? 10 : 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Welcome to ',
              style: TextStyle(
                color: _navy,
                fontSize: line1Size,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                height: 1.15,
              ),
            ),
            Text(
              'ACCESS ',
              style: TextStyle(
                color: _navy,
                fontSize: line1Size,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                height: 1.15,
              ),
            ),
            Text(
              'VisionCheck!',
              style: TextStyle(
                color: _cyan,
                fontSize: line2Size,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        Container(
          width: compact ? 36 : 40,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: LinearGradient(
              colors: [
                _navy.withValues(alpha: 0.15),
                _cyan.withValues(alpha: 0.85),
                _navy.withValues(alpha: 0.15),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          AppConstants.tagline,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _navy.withValues(alpha: 0.78),
            fontSize: taglineSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.18,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _WelcomeSignInLink extends StatelessWidget {
  const _WelcomeSignInLink({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(color: kTextSecondary, fontSize: 13),
        ),
        TextButton(
          onPressed: onSignIn,
          style: TextButton.styleFrom(
            foregroundColor: kCyan,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}

/// Informational only (not tappable).
class _WelcomeInfoCard extends StatelessWidget {
  const _WelcomeInfoCard({
    required this.compact,
    required this.label,
    required this.description,
    required this.icon,
  });

  final bool compact;
  final String label;
  final String description;
  final IconData icon;

  static const _navy = MobileAuthConstants.midnightScaffoldColor;
  static const _cyan = MobileAuthConstants.visionCheckBrightCyan;

  @override
  Widget build(BuildContext context) {
    final minHeight = compact ? 76.0 : 82.0;

    return Semantics(
      container: true,
      label: '$label. $description',
      child: DecoratedBox(
          decoration: BoxDecoration(
            color: kSurface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(MobileAuthConstants.fieldRadius),
            border: Border.all(
              color: _cyan.withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.75),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(MobileAuthConstants.fieldRadius),
                    ),
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 14 : 16,
                        vertical: compact ? 12 : 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: kCyanDim,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _cyan.withValues(alpha: 0.4)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Icon(
                                icon,
                                size: compact ? 22 : 24,
                                color: _navy,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 12 : 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: compact ? 12 : 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.55,
                                  ),
                                ),
                                SizedBox(height: compact ? 4 : 5),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: kTextSecondary,
                                    fontSize: compact ? 12.5 : 13.5,
                                    height: 1.38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
