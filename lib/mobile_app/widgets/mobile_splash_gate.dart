import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

TextStyle _splashText(TextStyle base) => GoogleFonts.inter(textStyle: base);

/// Branded splash — org seal and wordmark on ACCESS cyan, then hands off to [AuthGate].
class MobileSplashGate extends StatefulWidget {
  const MobileSplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<MobileSplashGate> createState() => _MobileSplashGateState();
}

class _MobileSplashGateState extends State<MobileSplashGate> {
  bool _showSplash = true;
  bool _startedInit = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _startedInit) return;
      _startedInit = true;
      _initSplash();
    });
  }

  Future<void> _initSplash() async {
    await Future.wait([
      authController.waitForInitialization(),
      brandingController.refresh(),
    ]);
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const Material(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: MobileAuthConstants.headerGradient),
          child: _SplashBrandContent(),
        ),
      );
    }
    return widget.child;
  }
}

class _SplashBrandContent extends StatelessWidget {
  const _SplashBrandContent();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 360;
    final fromWidth = media.width * 0.34;
    final fromHeight = media.height > 0 ? media.height * 0.16 : fromWidth;
    final logoSize = math.min(fromWidth, fromHeight).clamp(104.0, 136.0);
    final titleSize = compact ? 20.0 : 22.0;
    final subtitleSize = compact ? 18.0 : 20.0;
    final logoTitleGap = compact ? 8.0 : 10.0;
    final titleLineGap = compact ? 3.0 : 4.0;
    final taglineSize = compact ? 12.0 : 13.0;
    const accessMotto = 'Beyond Documentation, Towards Excellence.';

    return ListenableBuilder(
      listenable: brandingController,
      builder: (_, __) {
        final brandingTagline = brandingController.loginHeroTagline.trim();
        final primaryTagline = brandingTagline.isNotEmpty
            ? brandingTagline
            : AppConstants.tagline;
        final showPrimaryTagline =
            !_isSameAccessMotto(primaryTagline, accessMotto);

        final taglineStyle = _splashText(TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: taglineSize,
          fontWeight: FontWeight.w600,
          height: 1.35,
          shadows: const [
            Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ));

        return SizedBox(
          width: media.width,
          height: media.height,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 32 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AccessOrgSealLogo(
                    size: logoSize,
                    showShadow: true,
                    showWhitePlate: true,
                    paddingFraction: 0.02,
                    preferLauncherForeground: false,
                  ),
                  SizedBox(height: logoTitleGap),
                  Text(
                    'ACCESS',
                    textAlign: TextAlign.center,
                    style: _splashText(const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      height: 1.1,
                      shadows: [
                        Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    )).copyWith(fontSize: titleSize),
                  ),
                  SizedBox(height: titleLineGap),
                  Text(
                    'VisionCheck',
                    textAlign: TextAlign.center,
                    style: _splashText(const TextStyle(
                      color: kAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      height: 1.1,
                      shadows: [
                        Shadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    )).copyWith(fontSize: subtitleSize),
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Container(
                    width: compact ? 32 : 36,
                    height: 2,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  if (showPrimaryTagline) ...[
                    Text(
                      primaryTagline,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: taglineStyle,
                    ),
                    SizedBox(height: compact ? 6 : 8),
                  ],
                  Text(
                    accessMotto,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: taglineStyle,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _isSameAccessMotto(String a, String b) {
  String norm(String s) =>
      s.toLowerCase().replaceAll(',', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return norm(a) == norm(b);
}
