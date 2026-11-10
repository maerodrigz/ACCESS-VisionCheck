import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Generated Gallery banner (ice-blue waves + camera / photos / video).
/// Left zone stays clear for live Flutter title and subtitle.
const kRequestorGalleryHeaderAsset =
    'assets/images/requestor_gallery_header.png';

/// Intrinsic aspect of [kRequestorGalleryHeaderAsset] (2172×724).
const kRequestorGalleryHeaderAspect = 2172 / 724;

const _kGalleryHeaderUnderpaint = Color(0xFFC9F0FD);
const _kGalleryHeaderRadius = 22.0;

/// Requestor Gallery illustrated banner.
///
/// Prefer [includeTopActions] = false under a pinned [RequestorBrandAppBar].
class RequestorGalleryIllustratedHeader extends StatelessWidget {
  const RequestorGalleryIllustratedHeader({
    super.key,
    this.title = 'Gallery',
    this.subtitle = 'Relive your documented events.',
    this.onNotificationsTap,
    this.onProfileTap,
    this.includeTopActions = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final bool includeTopActions;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final banner = _RequestorGalleryHeaderBanner(
      title: title,
      subtitle: subtitle,
      narrow: narrow,
    );

    if (!includeTopActions) {
      return Padding(
        padding: EdgeInsets.fromLTRB(padding, 4, padding, 8),
        child: banner,
      );
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, 2, padding, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                MemberPageNotificationButton(onTap: onNotificationsTap),
                MemberPageProfileAvatar(onTap: onProfileTap),
              ],
            ),
            SizedBox(height: narrow ? 4 : 6),
            banner,
          ],
        ),
      ),
    );
  }
}

class _RequestorGalleryHeaderBanner extends StatelessWidget {
  const _RequestorGalleryHeaderBanner({
    required this.title,
    required this.subtitle,
    required this.narrow,
  });

  final String title;
  final String subtitle;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final naturalHeight = width / kRequestorGalleryHeaderAspect;
        // Match Calendar / My Requests compact band heights.
        final minHeight = narrow ? 90.0 : 96.0;
        final maxHeight = narrow ? 98.0 : 104.0;
        final height = naturalHeight.clamp(minHeight, maxHeight);
        final textWidthFactor = narrow ? 0.50 : 0.46;

        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kGalleryHeaderRadius),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kGalleryHeaderRadius),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                const ColoredBox(color: _kGalleryHeaderUnderpaint),
                Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset(
                    kRequestorGalleryHeaderAsset,
                    height: height,
                    fit: BoxFit.fitHeight,
                    alignment: Alignment.centerRight,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    narrow ? 14 : 16,
                    narrow ? 8 : 10,
                    narrow ? 10 : 12,
                    narrow ? 8 : 10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: textWidthFactor,
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: width * textWidthFactor,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(TextStyle(
                                  color: kTextPrimary,
                                  fontSize: narrow ? 21 : 23,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.08,
                                )),
                              ),
                              SizedBox(height: narrow ? 3 : 4),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(TextStyle(
                                  color: kTextSecondary,
                                  fontSize: narrow ? 11.5 : 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
