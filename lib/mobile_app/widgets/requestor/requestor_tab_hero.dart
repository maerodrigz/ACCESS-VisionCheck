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
          child: AccessBrandLockup(
            markSize: 40,
            compact: true,
            onCyanHeader: true,
          ),
        ),
        if (onNotifications != null)
          MemberDarkHeroNotificationButton(onTap: onNotifications, onCyanHero: true),
        if (onProfileTap != null)
          MemberDarkHeroProfileAvatar(onTap: onProfileTap, onCyanHero: true),
      ],
    );
  }
}

/// Cyan top hero for requestor tabs — matches member home and sign-in header.
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
        gradient: kMemberDashboardHeroGradient,
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
                  style: memberCyanHeroTitleTextStyle(
                    fontSize: mini ? 17 : 20,
                    fontWeight: titleFontWeight,
                  ),
                ),
              ],
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: memberCyanHeroSubtitleTextStyle(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
