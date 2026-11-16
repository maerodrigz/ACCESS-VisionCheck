import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Dedicated calendar header artwork (ice-blue waves + camera/calendar).
/// No baked-in title or subtitle. Left zone stays clear for live Flutter text.
const kRequestorCalendarHeaderBackgroundAsset =
    'assets/images/requestor_calendar_header_background.png';

/// Intrinsic aspect of [kRequestorCalendarHeaderBackgroundAsset] (1241×495).
const kRequestorCalendarHeaderAspect = 1241 / 495;

const _kCalendarHeaderUnderpaint = Color(0xFFC9F0FD);
const _kCalendarHeaderNavy = Color(0xFF103E56);
const _kCalendarHeaderRadius = 20.0;

/// Requestor Calendar top chrome: notification/profile outside the illustrated banner.
class RequestorCalendarIllustratedHeader extends StatelessWidget {
  const RequestorCalendarIllustratedHeader({
    super.key,
    this.title = 'Calendar',
    this.subtitle = 'Campus events and your documentation schedule.',
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final sidePad = narrow ? 16.0 : mobilePagePaddingOf(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(sidePad, 4, sidePad, narrow ? 8 : 10),
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
            SizedBox(height: narrow ? 6 : 8),
            _RequestorCalendarHeaderBanner(
              title: title,
              subtitle: subtitle,
              narrow: narrow,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestorCalendarHeaderBanner extends StatelessWidget {
  const _RequestorCalendarHeaderBanner({
    required this.title,
    required this.subtitle,
    required this.narrow,
  });

  final String title;
  final String subtitle;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kCalendarHeaderRadius),
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCalendarHeaderRadius),
        child: AspectRatio(
          aspectRatio: kRequestorCalendarHeaderAspect,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              const ColoredBox(color: _kCalendarHeaderUnderpaint),
              Image.asset(
                kRequestorCalendarHeaderBackgroundAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
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
                    widthFactor: narrow ? 0.56 : 0.52,
                    alignment: Alignment.centerLeft,
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
                            color: _kCalendarHeaderNavy,
                            fontSize: narrow ? 22 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.1,
                          )),
                        ),
                        SizedBox(height: narrow ? 4 : 5),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: _kCalendarHeaderNavy.withValues(alpha: 0.72),
                            fontSize: narrow ? 11.5 : 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
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
