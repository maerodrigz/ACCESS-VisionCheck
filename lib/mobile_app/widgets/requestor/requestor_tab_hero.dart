import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';

/// Logo + notification + profile for requestor dark heroes (overflow-safe).
class RequestorHeroTopBar extends StatelessWidget {
  const RequestorHeroTopBar({
    super.key,
    this.onNotifications,
    this.onProfileTap,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: AccessBrandLockup(markSize: 40, compact: true),
        ),
        if (onNotifications != null)
          MemberDarkHeroNotificationButton(onTap: onNotifications),
        if (onProfileTap != null)
          MemberDarkHeroProfileAvatar(onTap: onProfileTap),
      ],
    );
  }
}

/// Dark top hero for requestor tabs — matches member home/gallery header rhythm.
class RequestorTabHero extends StatelessWidget {
  const RequestorTabHero({
    super.key,
    required this.title,
    this.subtitle,
    this.onNotifications,
    this.onProfileTap,
    this.mini = false,
    this.titleFontWeight = FontWeight.w800,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;

  /// Smaller bottom radius/padding (gallery-style mini hero).
  final bool mini;
  final FontWeight titleFontWeight;

  @override
  Widget build(BuildContext context) {
    final bottomRadius =
        mini ? kMemberDarkHeroMiniBottomRadius : kMemberDarkHeroBottomRadius;
    final bottomPad = mini ? 14.0 : 22.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RequestorHeroTopBar(
                onNotifications: onNotifications,
                onProfileTap: onProfileTap,
              ),
              if (title.isNotEmpty) ...[
                SizedBox(height: mini ? 10 : 14),
                Text(
                  title,
                  style: dashText(TextStyle(
                    color: Colors.white,
                    fontSize: mini ? 17 : 20,
                    fontWeight: titleFontWeight,
                    height: 1.2,
                    letterSpacing: -0.2,
                  )),
                ),
              ],
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: dashText(TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
