import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';

/// Branding panel — gradient, ribbon mark, and product identity (no background photo).
class LoginBrandPanel extends StatefulWidget {
  const LoginBrandPanel({super.key, this.compact = false});

  final bool compact;

  @override
  State<LoginBrandPanel> createState() => _LoginBrandPanelState();
}

class _LoginBrandPanelState extends State<LoginBrandPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Compact (phone) sits on the login screen's full-height gradient, so it paints none of its own.
    return DecoratedBox(
      decoration: widget.compact
          ? const BoxDecoration()
          : const BoxDecoration(gradient: LoginPageTokens.heroGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroGlow(compact: widget.compact),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 24 : 56,
                  vertical: widget.compact ? 12 : 0,
                ),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: widget.compact
                        ? FittedBox(fit: BoxFit.scaleDown, child: _brandContent())
                        : _brandContent(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandContent() {
    final sealSize = widget.compact ? 108.0 : 168.0;
    final titleSize = widget.compact ? 20.0 : 32.0;
    final subtitleSize = widget.compact ? 11.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AccessOrgSealLogo(size: sealSize),
        SizedBox(height: widget.compact ? 10 : 20),
        Text(
          'ACCESS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kCyan,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          'VisionCheck',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize + (widget.compact ? 2 : 4),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.05,
          ),
        ),
        SizedBox(height: widget.compact ? 6 : 18),
        Text(
          'Campus Documentation Platform',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: subtitleSize + 1,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow({required this.compact});

  final bool compact;

  Widget _glow(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final blob = compact ? 200.0 : 220.0;

    return IgnorePointer(
      child: Stack(
        children: [
          if (compact) ...[
            Positioned(
              top: -50,
              right: -60,
              child: _glow(blob, LoginPageTokens.heroGlow, 0.26),
            ),
            Positioned(
              top: size.height * 0.08,
              left: -80,
              child: _glow(blob * 1.1, LoginPageTokens.purple, 0.3),
            ),
            Positioned(
              bottom: -40,
              right: size.width * 0.15,
              child: _glow(blob * 0.9, LoginPageTokens.primary, 0.22),
            ),
          ],
          if (!compact)
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: blob,
                height: blob,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      LoginPageTokens.heroGlow.withValues(alpha: 0.22),
                      LoginPageTokens.heroGlow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          if (!compact)
            Positioned(
              bottom: -70,
              left: -50,
              child: Container(
                width: blob * 1.1,
                height: blob * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      LoginPageTokens.primary.withValues(alpha: 0.18),
                      LoginPageTokens.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          if (!compact)
            Positioned(
              top: size.height * 0.12,
              left: size.width * 0.08,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kCyan.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
