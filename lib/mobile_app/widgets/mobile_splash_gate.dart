import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/shared/widgets/login/login_brand_panel.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_backgrounds.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

/// Light widget splash, then hands off to [AuthGate].
class MobileSplashGate extends StatefulWidget {
  const MobileSplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<MobileSplashGate> createState() => _MobileSplashGateState();
}

class _MobileSplashGateState extends State<MobileSplashGate> {
  static const _minSplashDisplay = Duration(seconds: 3);

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
    final visibleAt = DateTime.now();
    await Future.wait([
      authController.waitForInitialization(),
      brandingController.refresh(),
    ]);
    if (mounted) {
      await precacheMobileAuthBackgrounds(context);
    }
    final remaining = _minSplashDisplay - DateTime.now().difference(visibleAt);
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const Material(
        color: kBg,
        child: _SplashLightView(),
      );
    }
    return widget.child;
  }
}

class _SplashLightView extends StatelessWidget {
  const _SplashLightView();

  static const _navy = MobileAuthConstants.midnightScaffoldColor;
  static const _cyan = MobileAuthConstants.visionCheckBrightCyan;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < 360;
    final short = media.size.height < 640;
    final logoSize = compact ? (short ? 88.0 : 96.0) : 104.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                kBg,
                kCyanDim,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -media.size.height * 0.08,
          right: -media.size.width * 0.2,
          child: IgnorePointer(
            child: Container(
              width: media.size.width * 0.72,
              height: media.size.width * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCyan.withValues(alpha: 0.14),
                    kCyan.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: media.size.height * 0.28,
          child: const CustomPaint(painter: _SplashBottomWavePainter()),
        ),
        SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ListenableBuilder(
                    listenable: brandingController,
                    builder: (_, __) {
                      final wordmark = loginWordmarkLines(brandingController.appName);
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 28 : 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AccessOrgSealLogo(
                              size: logoSize,
                              showShadow: true,
                              showWhitePlate: true,
                              paddingFraction: 0.02,
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Text(
                              wordmark.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _navy,
                                fontSize: compact ? 22 : 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: compact ? 2 : 4),
                            Text(
                              wordmark.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _cyan,
                                fontSize: compact ? 22 : 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Container(
                              width: compact ? 36 : 42,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                gradient: LinearGradient(
                                  colors: [
                                    _navy.withValues(alpha: 0.12),
                                    _cyan.withValues(alpha: 0.75),
                                    _navy.withValues(alpha: 0.12),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Text(
                              AppConstants.tagline,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _navy.withValues(alpha: 0.72),
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.15,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: compact ? 22 : 26),
                            const _SplashLoadingIndicator(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  0,
                  compact ? 20 : 28,
                  compact ? 10 : 14,
                ),
                child: _SplashUstpFooter(compact: compact),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplashBottomWavePainter extends CustomPainter {
  const _SplashBottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final softCyan = Paint()..color = kCyan.withValues(alpha: 0.22);
    final path = Path()
      ..moveTo(0, h * 0.35)
      ..quadraticBezierTo(w * 0.28, h * 0.05, w * 0.58, h * 0.28)
      ..quadraticBezierTo(w * 0.86, h * 0.48, w, h * 0.22)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, softCyan);

    final front = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.34, h * 0.22, w * 0.64, h * 0.42)
      ..quadraticBezierTo(w * 0.9, h * 0.58, w, h * 0.38)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = kCyan.withValues(alpha: 0.12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SplashLoadingIndicator extends StatelessWidget {
  const _SplashLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.25,
          color: MobileAuthConstants.visionCheckBrightCyan,
          backgroundColor: kCyan.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _SplashUstpFooter extends StatelessWidget {
  const _SplashUstpFooter({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 32.0 : 36.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AccessOrgSealLogo(
          size: markSize,
          showShadow: false,
          showWhitePlate: false,
          paddingFraction: 0.02,
        ),
        SizedBox(width: compact ? 8 : 10),
        Flexible(
          child: Text(
            AppConstants.organization,
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MobileAuthConstants.midnightScaffoldColor.withValues(alpha: 0.82),
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
