import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/utils/member_media_display_url.dart';

/// Network image for member media (adds JWT for `/api/media/.../stream`).
class MemberNetworkImage extends StatelessWidget {
  const MemberNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final headers = memberMediaImageHeaders(
      url,
      bearerToken: authController.user?.token,
    );
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      headers: headers,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }
}
