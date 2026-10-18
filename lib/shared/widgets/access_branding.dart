import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_logo.dart';

Widget _brandLogo(double size, {bool avatarStyle = false}) => AccessLogoImage(
      size: size,
      avatarStyle: avatarStyle,
      circular: avatarStyle,
      fit: BoxFit.contain,
    );

/// Ribbon A mark — always uses the transparent bundled PNG (React admin parity).
///
/// The web admin sidebar uses [AccessBrandMark] directly, not the server upload,
/// so the home header must not swap in org logos that sit on a white circle.
class AccessRibbonMark extends StatelessWidget {
  const AccessRibbonMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        kAccessBrandMarkAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Circular launcher / org mark — same round icon as the home screen (not a white square).
class AccessLauncherCircleLogo extends StatelessWidget {
  const AccessLauncherCircleLogo({
    super.key,
    required this.size,
    this.showShadow = true,
    this.paddingFraction = 0.03,
  });

  final double size;
  final bool showShadow;
  final double paddingFraction;

  @override
  Widget build(BuildContext context) {
    return AccessOrgSealLogo(
      size: size,
      showShadow: showShadow,
      paddingFraction: paddingFraction,
      preferLauncherForeground: true,
    );
  }
}

/// Circular org seal — full artwork visible ([BoxFit.contain]), no square JPEG matte.
class AccessOrgSealLogo extends StatelessWidget {
  const AccessOrgSealLogo({
    super.key,
    required this.size,
    this.showShadow = true,
    this.paddingFraction = 0.03,
    this.preferLauncherForeground = false,
    this.showWhitePlate = true,
    this.imageFit = BoxFit.contain,
  });

  final double size;
  final bool showShadow;
  /// Insets the raster so the outer ring/text stay inside the circle clip.
  final double paddingFraction;
  /// Splash + launcher parity: adaptive-icon foreground PNG first.
  final bool preferLauncherForeground;
  /// White circle behind the seal (off on login hero so the gradient shows through).
  final bool showWhitePlate;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    final inset = showWhitePlate
        ? (size * paddingFraction).clamp(1.0, 10.0)
        : (size * paddingFraction).clamp(0.0, 6.0);
    final inner = size - inset * 2;

    Widget sealImage() {
      Widget ribbonFallback() => Center(child: AccessRibbonMark(size: inner * 0.88));

      Widget loadAsset(String asset, {required Widget Function() onError}) {
        return Image.asset(
          asset,
          width: inner,
          height: inner,
          fit: imageFit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel:
              'ACCESS, Active Certified Computer-Enhance Student Society, USTP Oroquieta',
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            return ribbonFallback();
          },
          errorBuilder: (_, __, ___) => onError(),
        );
      }

      if (preferLauncherForeground) {
        return loadAsset(
          kAccessLauncherForegroundAsset,
          onError: () => loadAsset(kAccessOrgSealAsset, onError: ribbonFallback),
        );
      }
      return loadAsset(kAccessOrgSealAsset, onError: ribbonFallback);
    }

    final Widget disk;
    if (showWhitePlate) {
      disk = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: Center(child: sealImage()),
            ),
          ),
        ),
      );
    } else {
      disk = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: sealImage(),
          ),
        ),
      );
    }

    if (!showShadow) return disk;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: disk,
    );
  }
}

/// Horizontal logo lockup — matches React admin-web [AccessBrand].
class AccessBrandLockup extends StatelessWidget {
  const AccessBrandLockup({
    super.key,
    this.markSize = 40,
    this.compact = false,
    this.lightBackground = false,
    this.onCyanHeader = false,
  });

  final double markSize;
  final bool compact;

  /// Wordmark colors for light headers (VisionCheck uses primary text).
  final bool lightBackground;

  /// Sign-in / dashboard cyan hero: white ACCESS, primary blue VisionCheck + shadow.
  final bool onCyanHeader;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 15.0 : 17.0;
    final subtitleSize = compact ? 13.0 : 15.0;
    final gap = compact ? 10.0 : 12.0;

    final accessColor = onCyanHeader
        ? Colors.white
        : (lightBackground ? kTextPrimary : kCyan);
    final visionColor = onCyanHeader
        ? kAccent
        : (lightBackground ? kTextPrimary : Colors.white);
    const cyanWordmarkShadows = [
      Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
      Shadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
    ];

    final wordmark = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ACCESS',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accessColor,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.05,
            shadows: onCyanHeader ? cyanWordmarkShadows : null,
          ),
        ),
        Text(
          'VisionCheck',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: visionColor,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
            shadows: onCyanHeader ? cyanWordmarkShadows : null,
          ),
        ),
      ],
    );

    // Fill the hero [Expanded] slot so the wordmark column gets horizontal space.
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AccessOrgSealLogo(size: markSize, showShadow: false),
          SizedBox(width: gap),
          Expanded(child: wordmark),
        ],
      ),
    );
  }
}

enum AccessBrandLayout { horizontal, vertical }

enum AccessBrandTheme { light, dark }

/// Sidebar branding — org logo + ACCESS VisionCheck wordmark on brand gradient.
class AccessSidebarBrand extends StatelessWidget {
  const AccessSidebarBrand({
    super.key,
    this.logoSize = 64,
    this.compact = false,
  });

  final double logoSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: AccessLogoImage(
          size: logoSize,
          circular: true,
          fit: BoxFit.cover,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AccessLogoImage(
          size: logoSize,
          circular: true,
          fit: BoxFit.cover,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACCESS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'VisionCheck',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Responsive branding — logo + configurable system name + subtitle.
class AccessBrandMark extends StatelessWidget {
  const AccessBrandMark({
    super.key,
    this.logoSize = 48,
    this.compact = false,
    this.showTagline = true,
    this.layout = AccessBrandLayout.horizontal,
    this.theme = AccessBrandTheme.dark,
    this.alignment = CrossAxisAlignment.start,
  });

  const AccessBrandMark.iconOnly({super.key, this.logoSize = 42})
      : compact = true,
        showTagline = false,
        layout = AccessBrandLayout.horizontal,
        theme = AccessBrandTheme.dark,
        alignment = CrossAxisAlignment.center;

  final double logoSize;
  final bool compact;
  final bool showTagline;
  final AccessBrandLayout layout;
  final AccessBrandTheme theme;
  final CrossAxisAlignment alignment;

  Color get _titleColor => theme == AccessBrandTheme.dark ? Colors.white : const Color(0xFF0F2744);
  Color get _subtitleColor =>
      theme == AccessBrandTheme.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: brandingController,
      builder: (_, __) {
        final logo = kIsWeb
            ? (compact
                ? AccessLogoImage(
                    size: logoSize,
                    circular: true,
                    fit: BoxFit.cover,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  )
                : _brandLogo(logoSize))
            : AccessOrgSealLogo(size: logoSize, showShadow: !compact);
        if (compact) return logo;

        final textBlock = Column(
          crossAxisAlignment: alignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              brandingController.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _titleColor,
                fontSize: layout == AccessBrandLayout.vertical ? 20 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                height: 1.15,
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Text(
                brandingController.shortTagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _subtitleColor,
                  fontSize: layout == AccessBrandLayout.vertical ? 12 : 10,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ],
        );

        if (layout == AccessBrandLayout.vertical) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              logo,
              const SizedBox(height: 14),
              textBlock,
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            logo,
            const SizedBox(width: 12),
            Flexible(child: textBlock),
          ],
        );
      },
    );
  }
}

/// Compact inline logo + title for page headers and top bars.
class AccessHeaderBrand extends StatelessWidget {
  const AccessHeaderBrand({
    super.key,
    this.title,
    this.logoSize = 40,
    this.theme = AccessBrandTheme.light,
    this.showTagline = true,
    this.titleFontSize = 14,
    this.logoGap = 10,
    this.titleColor,
  });

  final String? title;
  final double logoSize;
  final AccessBrandTheme theme;
  final bool showTagline;
  final double titleFontSize;
  final double logoGap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final titleColor = this.titleColor ??
        (theme == AccessBrandTheme.dark ? Colors.white : const Color(0xFF0F2744));
    final subtitleColor = theme == AccessBrandTheme.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ListenableBuilder(
      listenable: brandingController,
      builder: (_, __) {
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? brandingController.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                height: 1.1,
              ),
            ),
            if (showTagline)
              Text(
                brandingController.shortTagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtitleColor, fontSize: 10, height: 1.2),
              ),
          ],
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _brandLogo(logoSize),
            if (logoGap > 0) SizedBox(width: logoGap),
            Flexible(
              child: Transform.translate(
                offset: Offset(logoGap < 0 ? logoGap : 0, 0),
                child: textBlock,
              ),
            ),
          ],
        );
      },
    );
  }
}
