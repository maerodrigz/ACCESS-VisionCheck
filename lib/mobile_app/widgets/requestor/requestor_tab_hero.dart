import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';

/// Requestor Home header palette (Option 1 — minimal white + greeting card).
const _kRequestorHeaderNavy = Color(0xFF103E56);
const _kRequestorHeaderCyan = Color(0xFF08B6D5);
const _kRequestorHeaderMuted = Color(0xFF607487);

/// Full greeting banner artwork (gradient + waves + camera/calendar).
/// Fully opaque rectangle; [ClipRRect] owns the rounded corners.
const kRequestorGreetingBackgroundAsset =
    'assets/images/requestor_greeting_background.png';

/// Intrinsic aspect ratio of [kRequestorGreetingBackgroundAsset] (1234×439).
const kRequestorGreetingBackgroundAspect = 1234 / 439;

/// Soft cyan underpaint so any decode/AA gap never shows page white.
const kRequestorGreetingUnderpaint = Color(0xFFC9F0FD);

/// Greeting card corner radius (matches Design 3 soft pill card).
const kRequestorGreetingCardRadius = 22.0;

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

/// Pinned transparent bar: ACCESS seal + VisionCheck wordmark + optional actions.
///
/// Use on every Requestor tab so branding stays over the shared sky background
/// while illustrated feature banners scroll with page content.
class RequestorBrandAppBar extends StatelessWidget {
  const RequestorBrandAppBar({
    super.key,
    this.onNotifications,
    this.onProfileTap,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final logoSize = narrow ? 38.0 : 42.0;
    final sidePad = narrow ? 16.0 : kMemberDashboardPagePadding;

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(sidePad, 6, sidePad, 10),
          child: _RequestorHomeAppBar(
            logoSize: logoSize,
            onNotifications: onNotifications,
            onProfileTap: onProfileTap,
          ),
        ),
      ),
    );
  }
}

/// Transparent brand bar + pastel greeting card for Requestor Home only.
///
/// Does not replace [RequestorTabHero] used by other requestor surfaces.
class RequestorHomeHeader extends StatelessWidget {
  const RequestorHomeHeader({
    super.key,
    required this.displayName,
    this.onNotifications,
    this.onProfileTap,
    this.showGreeting = true,
  });

  final String displayName;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;

  /// When false, only the pinned logo, notification, and profile bar is built.
  final bool showGreeting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RequestorBrandAppBar(
          onNotifications: onNotifications,
          onProfileTap: onProfileTap,
        ),
        if (showGreeting) RequestorHomeGreeting(displayName: displayName),
      ],
    );
  }
}

/// Greeting banner that scrolls with the Requestor Home body.
class RequestorHomeGreeting extends StatelessWidget {
  const RequestorHomeGreeting({super.key, required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final sidePad = narrow ? 16.0 : kMemberDashboardPagePadding;

    return Padding(
      padding: EdgeInsets.fromLTRB(sidePad, narrow ? 10 : 12, sidePad, 12),
      child: _RequestorGreetingCard(displayName: displayName),
    );
  }
}

class _RequestorGreetingCard extends StatelessWidget {
  const _RequestorGreetingCard({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final nameSize = narrow ? 19.0 : 21.0;
    final name = displayName.trim().isEmpty ? 'Organization' : displayName.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRequestorGreetingCardRadius),
        boxShadow: [
          BoxShadow(
            color: _kRequestorHeaderCyan.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRequestorGreetingCardRadius),
        child: AspectRatio(
          aspectRatio: kRequestorGreetingBackgroundAspect,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // One artwork layer, same clip as the card. Fill matches the asset aspect.
              const ColoredBox(color: kRequestorGreetingUnderpaint),
              Image.asset(
                kRequestorGreetingBackgroundAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
              // Live copy in the left clear zone; keep camera/calendar free.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 14 : 16,
                  narrow ? 10 : 12,
                  narrow ? 10 : 12,
                  narrow ? 10 : 12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: narrow ? 0.54 : 0.50,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${memberDashboardGreeting()},',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: _kRequestorHeaderNavy.withValues(alpha: 0.78),
                            fontSize: narrow ? 11.5 : 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          )),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$name!',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: _kRequestorHeaderNavy,
                            fontSize: nameSize,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            letterSpacing: -0.25,
                          )),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Request and track your event documentation.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: _kRequestorHeaderNavy.withValues(alpha: 0.78),
                            fontSize: narrow ? 11 : 12,
                            fontWeight: FontWeight.w400,
                            height: 1.22,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestorHomeAppBar extends StatelessWidget {
  const _RequestorHomeAppBar({
    required this.logoSize,
    this.onNotifications,
    this.onProfileTap,
  });

  final double logoSize;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _RequestorHomeBrandLockup(markSize: logoSize),
        ),
        if (onNotifications != null) ...[
          _RequestorHomeIconButton(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications_rounded,
            onTap: onNotifications,
          ),
          const SizedBox(width: 2),
        ],
        if (onProfileTap != null)
          _RequestorHomeProfileAvatar(onTap: onProfileTap),
      ],
    );
  }
}

class _RequestorHomeBrandLockup extends StatelessWidget {
  const _RequestorHomeBrandLockup({required this.markSize});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final titleSize = compact ? 14.0 : 15.0;
    final subtitleSize = compact ? 13.0 : 14.0;

    return Row(
      children: [
        AccessOrgSealLogo(size: markSize, showShadow: false),
        SizedBox(width: compact ? 8 : 10),
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
                  color: _kRequestorHeaderNavy,
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
                  color: _kRequestorHeaderNavy,
                  fontSize: subtitleSize,
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

class _RequestorHomeIconButton extends StatelessWidget {
  const _RequestorHomeIconButton({
    required this.icon,
    required this.activeIcon,
    this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final VoidCallback? onTap;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final badgeCount = appState.unreadCount;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kMobileMinTouch,
              height: kMobileMinTouch,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        color: _kRequestorHeaderCyan.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _kRequestorHeaderCyan.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        badgeCount > 0 ? activeIcon : icon,
                        size: 20,
                        color: badgeCount > 0
                            ? _kRequestorHeaderNavy
                            : _kRequestorHeaderMuted,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF139CD9),
                            shape: BoxShape.circle,
                            border: Border.all(color: kSurface, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 9 ? '9+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RequestorHomeProfileAvatar extends StatelessWidget {
  const _RequestorHomeProfileAvatar({this.onTap});

  final VoidCallback? onTap;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, authController]),
      builder: (context, _) {
        final displayName = appState.profileName.trim().isNotEmpty
            ? appState.profileName
            : (authController.user?.name ?? '');
        final initials = memberDisplayInitials(displayName);
        final imageUrl = appState.profileImageUrl;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kMobileMinTouch,
              height: kMobileMinTouch,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _kRequestorHeaderCyan.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: _size,
                                height: _size,
                                errorBuilder: (_, __, ___) =>
                                    _RequestorHomeInitials(initials: initials),
                              )
                            : _RequestorHomeInitials(initials: initials),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: kGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: kSurface, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RequestorHomeInitials extends StatelessWidget {
  const _RequestorHomeInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kRequestorHeaderCyan.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: _kRequestorHeaderNavy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
