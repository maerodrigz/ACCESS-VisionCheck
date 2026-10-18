import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/shared/widgets/login/login_brand_panel.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/auth_wave_painter.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

/// Upper hero: gradient, org seal, ACCESS VisionCheck, tagline. No background photo.
class MobileAuthHeader extends StatelessWidget {
  const MobileAuthHeader({
    super.key,
    this.compact = false,
    this.minimal = false,
  });

  final bool compact;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: MobileAuthConstants.headerGradient)),
        const _MobileAuthHeroGlow(),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              minimal ? 4 : (compact ? 2 : 10),
              18,
              compact ? 46 : 52,
            ),
            child: minimal ? _minimalTitle() : (compact ? _signInBrandRow() : _registrationBrandColumn()),
          ),
        ),
        const Positioned(left: 0, right: 0, bottom: 0, child: AuthWaveDivider()),
      ],
    );
  }

  Widget _minimalTitle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ListenableBuilder(
        listenable: brandingController,
        builder: (context, _) {
          final wordmark = loginWordmarkLines(brandingController.appName);
          return Text(
            '${wordmark.title} ${wordmark.subtitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }

  /// Sign-in: seal + wordmark + tagline in one row (fits short header, no clipping).
  Widget _signInBrandRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ListenableBuilder(
        listenable: brandingController,
        builder: (context, _) {
          final wordmark = loginWordmarkLines(brandingController.appName);
          final heroTagline = brandingController.loginHeroTagline;
          final taglineText =
              heroTagline.isNotEmpty ? heroTagline : MobileAuthConstants.tagline;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AccessOrgSealLogo(
                size: 58,
                showShadow: true,
                showWhitePlate: true,
                paddingFraction: 0.03,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WordmarkLine(
                      title: wordmark.title,
                      subtitle: wordmark.subtitle,
                      titleSize: 18,
                      subtitleSize: 22,
                      onCyanHeader: true,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      taglineText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        shadows: const [
                          Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _registrationBrandColumn() {
    return Center(
      child: ListenableBuilder(
        listenable: brandingController,
        builder: (context, _) {
          final wordmark = loginWordmarkLines(brandingController.appName);
          final heroTagline = brandingController.loginHeroTagline;
          final taglineText =
              heroTagline.isNotEmpty ? heroTagline : MobileAuthConstants.tagline;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccessOrgSealLogo(
                size: 72,
                showShadow: true,
                showWhitePlate: true,
                paddingFraction: 0.03,
              ),
              const SizedBox(height: 12),
              _WordmarkLine(
                title: wordmark.title,
                subtitle: wordmark.subtitle,
                titleSize: 24,
                subtitleSize: 28,
                center: true,
                onCyanHeader: true,
              ),
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  taglineText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WordmarkLine extends StatelessWidget {
  const _WordmarkLine({
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.subtitleSize,
    this.center = false,
    this.onCyanHeader = false,
  });

  final String title;
  final String subtitle;
  final double titleSize;
  final double subtitleSize;
  final bool center;
  final bool onCyanHeader;

  @override
  Widget build(BuildContext context) {
    final align = center ? WrapAlignment.center : WrapAlignment.start;
    final titleColor = onCyanHeader ? Colors.white : kCyan;
    final subtitleColor = onCyanHeader ? kAccent : Colors.white;

    return Wrap(
      alignment: align,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 0,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            height: 1.0,
            shadows: onCyanHeader
                ? const [Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.0,
            shadows: onCyanHeader
                ? const [Shadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
        ),
      ],
    );
  }
}

class _MobileAuthHeroGlow extends StatelessWidget {
  const _MobileAuthHeroGlow();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    Widget blob(double size, Color color, double alpha) {
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

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -40, right: -30, child: blob(160, Colors.white, 0.12)),
          Positioned(top: 24, left: -50, child: blob(140, Colors.white, 0.1)),
          Positioned(bottom: 16, right: w * 0.05, child: blob(100, const Color(0xFF00B0D8), 0.25)),
        ],
      ),
    );
  }
}
