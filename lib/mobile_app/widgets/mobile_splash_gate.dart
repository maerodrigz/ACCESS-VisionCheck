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
    unawaited(brandingController.refresh());
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const Material(
        color: Colors.white,
        child: SafeArea(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final fromWidth = w * 0.52;
        final fromHeight = h > 0 ? h * 0.26 : fromWidth;
        final logoSize = math.min(fromWidth, fromHeight).clamp(160.0, 204.0);
        final titleSize = compact ? 24.0 : 26.0;
        final logoTitleGap = compact ? 10.0 : 12.0;

        return ListenableBuilder(
          listenable: brandingController,
          builder: (_, __) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 32 : 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccessOrgSealLogo(
                      size: logoSize,
                      showShadow: false,
                      paddingFraction: 0.01,
                      preferLauncherForeground: true,
                    ),
                    SizedBox(height: logoTitleGap),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'ACCESS ',
                            style: _splashText(const TextStyle(
                              color: kTextPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1.15,
                            )).copyWith(fontSize: titleSize),
                          ),
                          TextSpan(
                            text: 'VisionCheck',
                            style: _splashText(const TextStyle(
                              color: kCyan,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.05,
                              height: 1.15,
                            )).copyWith(fontSize: titleSize),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
