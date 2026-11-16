import 'package:flutter/material.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_fixed_background.dart';

/// Welcome / onboarding: fixed [welcome_background.png], scrollable foreground.
class MobileWelcomeScaffold extends StatelessWidget {
  const MobileWelcomeScaffold({
    super.key,
    required this.body,
    this.topInsetFactor = 0.21,
    this.bottomPaddingExtra = 24,
  });

  final Widget body;
  final double topInsetFactor;
  final double bottomPaddingExtra;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.size.height * topInsetFactor;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: MobileAuthConstants.midnightScaffoldColor,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          const MobileAuthFixedBackground(
            assetPath: MobileAuthConstants.welcomeBackgroundAsset,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: topInset),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      bottomPaddingExtra + media.padding.bottom + media.viewInsets.bottom,
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
