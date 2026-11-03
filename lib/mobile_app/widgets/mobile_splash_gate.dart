import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

TextStyle _splashText(TextStyle base) => GoogleFonts.inter(textStyle: base);

/// Branded splash on [splash_background.png], then hands off to [AuthGate].
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SplashBackgroundImage(),
            _SplashBrandContent(),
          ],
        ),
      );
    }
    return widget.child;
  }
}

class _SplashBackgroundImage extends StatelessWidget {
  const _SplashBackgroundImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      MobileAuthConstants.splashBackgroundAsset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
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
    final logoSize = (fromWidth < fromHeight ? fromWidth : fromHeight).clamp(104.0, 136.0);
    final titleSize = compact ? 20.0 : 22.0;
    final subtitleSize = compact ? 18.0 : 20.0;
    final logoTitleGap = compact ? 8.0 : 10.0;
    final titleLineGap = compact ? 3.0 : 4.0;
    final taglineSize = compact ? 12.0 : 13.0;

    final taglineStyle = _splashText(TextStyle(
      color: Colors.white.withValues(alpha: 0.94),
      fontSize: taglineSize,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: 0.2,
      shadows: const [
        Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 1)),
      ],
    ));

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final scannerCenterY = h * 0.38;

          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: scannerCenterY,
                child: Transform.translate(
                  offset: Offset(0, -logoSize * 0.85),
                  child: ListenableBuilder(
                    listenable: brandingController,
                    builder: (_, __) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 32 : 40),
                        child: Column(
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
                                  Shadow(
                                    color: Color(0x44000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
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
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              )).copyWith(fontSize: subtitleSize),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Container(
                              width: compact ? 32 : 36,
                              height: 2,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Text(
                              AppConstants.tagline,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: taglineStyle,
                            ),
                            SizedBox(height: compact ? 14 : 18),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: 0.72,
                                color: Colors.white.withValues(alpha: 0.9),
                                backgroundColor: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: compact ? 20 : 28,
                child: _SplashUstpFooter(compact: compact),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashUstpFooter extends StatelessWidget {
  const _SplashUstpFooter({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sealSize = compact ? 34.0 : 40.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AccessOrgSealLogo(
            size: sealSize,
            showShadow: false,
            showWhitePlate: true,
            paddingFraction: 0.03,
          ),
          SizedBox(width: compact ? 8 : 10),
          Flexible(
            child: Text(
              AppConstants.organization,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _splashText(TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: compact ? 11.0 : 12.0,
                fontWeight: FontWeight.w700,
                height: 1.25,
                shadows: const [
                  Shadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              )),
            ),
          ),
        ],
      ),
    );
  }
}
