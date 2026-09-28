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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LoginPageTokens.heroGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroGlow(compact: widget.compact),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: widget.compact ? Alignment.center : Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 24 : 56,
                  vertical: widget.compact ? 4 : 0,
                ),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: _brandContent(),
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
    final markSize = widget.compact ? 52.0 : 88.0;
    final titleSize = widget.compact ? 20.0 : 32.0;
    final subtitleSize = widget.compact ? 11.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LoginRibbonMark(size: markSize),
        SizedBox(height: widget.compact ? 10 : 24),
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

/// Crops baked-in PNG fringe so the mark sits cleanly on the dark gradient.
class _LoginRibbonMark extends StatelessWidget {
  const _LoginRibbonMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: Center(
          child: Transform.scale(
            scale: 1.14,
            child: AccessRibbonMark(size: size),
          ),
        ),
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final blob = compact ? 140.0 : 220.0;

    return IgnorePointer(
      child: Stack(
        children: [
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
