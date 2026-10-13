import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';

TextStyle _splashText(TextStyle base) => GoogleFonts.inter(textStyle: base);

/// Branded splash — logo and product name on white, then hands off to [AuthGate].
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
    await authController.waitForInitialization();
    await brandingController.refresh();
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const Material(
        color: Colors.white,
        child: _SplashBrandContent(),
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
    final fromWidth = media.width * 0.44;
    final fromHeight = media.height > 0 ? media.height * 0.22 : fromWidth;
    final logoSize = math.min(fromWidth, fromHeight).clamp(132.0, 172.0);
    final titleSize = compact ? 24.0 : 26.0;
    final subtitleSize = compact ? 22.0 : 24.0;
    final logoTitleGap = compact ? 6.0 : 8.0;
    final titleLineGap = compact ? 4.0 : 6.0;

    return ListenableBuilder(
      listenable: brandingController,
      builder: (_, __) {
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
                    showShadow: false,
                    paddingFraction: 0.01,
                    // Org seal JPG sits tighter than launcher foreground PNG (less transparent pad).
                    preferLauncherForeground: false,
                  ),
                  SizedBox(height: logoTitleGap),
                  Text(
                    'ACCESS',
                    textAlign: TextAlign.center,
                    style: _splashText(const TextStyle(
                      color: kCyan,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      height: 1.1,
                    )).copyWith(fontSize: titleSize),
                  ),
                  SizedBox(height: titleLineGap),
                  Text(
                    'VisionCheck',
                    textAlign: TextAlign.center,
                    style: _splashText(const TextStyle(
                      color: kTextPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.05,
                      height: 1.1,
                    )).copyWith(fontSize: subtitleSize),
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
