import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/themes/theme.dart';import 'package:access_mobile/shared/widgets/access_logo.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

export 'member_dashboard_theme.dart'
    show kMemberDashboardAccent, kMemberDashboardTitle, kMemberDashboardBg, kMemberCyan, kMemberPrimary;

/// Fixed content height of the member app header bar (excluding [SafeArea] top inset).
const kMemberDashboardHeaderBarHeight = 56.0;
const kMemberDashboardHeaderBarHeightCompact = 52.0;

/// Persistent member app header — page title and notifications.
///
/// Profile avatar in the header on every tab; bottom nav stays workflow-focused.
class MemberDashboardHeader extends StatelessWidget {
  const MemberDashboardHeader({
    super.key,
    this.onNotificationsTap,
    this.pageTitle,
  });

  final VoidCallback? onNotificationsTap;
  /// When set, shows the current tab title instead of the brand wordmark.
  final String? pageTitle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Material(
      color: kSurface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(
            bottom: BorderSide(
              color: kMemberDashboardAccent.withValues(alpha: 0.08),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: kMemberDashboardAccent.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: compact
                ? kMemberDashboardHeaderBarHeightCompact
                : kMemberDashboardHeaderBarHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 14,
                0,
                compact ? 8 : 10,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: pageTitle != null
                          ? Text(
                              pageTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: dashText(TextStyle(
                                color: kTextPrimary,
                                fontSize: compact ? 17 : 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.1,
                              )),
                            )
                          : _HeaderBrandWordmark(compact: compact),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: appState,
                    builder: (context, _) {
                      return _HeaderIconButton(
                        icon: appState.unreadCount > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        accent: kMemberPrimary,
                        onTap: onNotificationsTap,
                        badgeCount: appState.unreadCount,
                        compact: compact,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + two-tone ACCESS VisionCheck wordmark for the member header.
class _HeaderBrandWordmark extends StatelessWidget {
  const _HeaderBrandWordmark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 14.0 : 15.0;
    final logoSize = compact ? 38.0 : 42.0;

    return Row(
      children: [
        AccessLogoImage(size: logoSize),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'ACCESS ',
                  style: dashText(TextStyle(
                    color: kTextPrimary,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                    height: 1.1,
                  )),
                ),
                TextSpan(
                  text: 'VisionCheck',
                  style: dashText(TextStyle(
                    color: kMemberCyan,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.05,
                    height: 1.1,
                  )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.accent,
    this.onTap,
    this.badgeCount = 0,
    this.compact = false,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 38.0;
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
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 19 : 20,
                    color: badgeCount > 0 ? accent : kIconInactive,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: kRed,
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
  }
}
