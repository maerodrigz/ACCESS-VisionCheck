import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/widgets/access_visioncheck_mark.dart';

/// Bundled fallback when no custom logo is configured on the server.
const String kAccessLogoAsset = 'assets/images/access_logo.png';

/// Ribbon A mark (React admin-web default).
const String kAccessBrandMarkAsset = 'assets/images/access-brand-a.png';

/// Official ACCESS logo — server custom image or bundled [kAccessLogoAsset].
class AccessLogoImage extends StatelessWidget {
  const AccessLogoImage({
    super.key,
    required this.size,
    this.fit,
    this.circular = false,
    this.avatarStyle = false,
    this.padding,
    this.backgroundColor,
  });

  final double size;
  final BoxFit? fit;
  /// When true, clips to a circle (profile avatars). Default false shows full logo.
  final bool circular;
  final bool avatarStyle;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  BoxFit get _fit => fit ?? BoxFit.contain;

  EdgeInsets get _padding =>
      padding ?? EdgeInsets.all(circular || avatarStyle ? 0 : size * 0.06);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: brandingController,
      builder: (_, __) {
        final networkUrl = brandingController.networkLogoUrl;
        final image = networkUrl != null
            ? Image.network(
                networkUrl,
                width: size,
                height: size,
                fit: _fit,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _assetImage(),
              )
            : _assetImage();

        if (circular || avatarStyle) {
          return SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
              ),
              child: ClipOval(
                child: Padding(
                  padding: _padding,
                  child: image,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(size * 0.12),
            ),
            child: Padding(
              padding: _padding,
              child: image,
            ),
          ),
        );
      },
    );
  }

  Widget _assetImage() {
    return Image.asset(
      kAccessBrandMarkAsset,
      width: size,
      height: size,
      fit: _fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => AccessVisionCheckMark(
        size: size,
        showBubbles: false,
      ),
    );
  }
}

/// Neutral placeholder when neither network nor asset logo is available.
class AccessLogoFallback extends StatelessWidget {
  const AccessLogoFallback({
    super.key,
    required this.size,
    this.circular = false,
  });

  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final child = AccessVisionCheckMark(size: size, showBubbles: !circular);

    if (circular) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: ClipOval(child: Center(child: child)),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(size * 0.12),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// @deprecated Use [AccessLogoImage].
class AccessLogo extends StatelessWidget {
  const AccessLogo({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => AccessLogoImage(size: size);
}
