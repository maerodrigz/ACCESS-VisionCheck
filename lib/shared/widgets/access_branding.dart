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

/// Horizontal logo lockup — matches React admin-web [AccessBrand].
class AccessBrandLockup extends StatelessWidget {
  const AccessBrandLockup({
    super.key,
    this.markSize = 40,
    this.compact = false,
  });

  final double markSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 15.0 : 17.0;
    final subtitleSize = compact ? 13.0 : 15.0;
    final gap = compact ? 10.0 : 12.0;

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AccessRibbonMark(size: markSize),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ACCESS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kCyan,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  height: 1.05,
                ),
              ),
              Text(
                'VisionCheck',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: subtitleSize,
                  fontWeight: FontWeight.w600,
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
        final logo = compact
            ? AccessLogoImage(size: logoSize, circular: true, fit: BoxFit.cover, padding: EdgeInsets.zero, backgroundColor: Colors.white)
            : _brandLogo(logoSize);
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
