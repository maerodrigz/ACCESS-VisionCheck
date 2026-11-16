import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Generated Feedback banner (ice-blue waves + camera / rating artwork).
/// Left zone stays clear for live Flutter title and subtitle.
const kRequestorFeedbackHeaderAsset =
    'assets/images/requestor_feedback_header.png';

/// Intrinsic aspect of [kRequestorFeedbackHeaderAsset] after margin crop (~2087×620).
const kRequestorFeedbackHeaderAspect = 2087 / 620;

/// Display band aspect (slightly taller than the asset) so text has room and
/// [BoxFit.cover] crops baked white corner canvas out of the Flutter card.
const _kFeedbackHeaderDisplayAspect = 3.0;

const _kFeedbackHeaderUnderpaint = Color(0xFFB8E8FA);
const _kFeedbackHeaderRadius = 22.0;
const _kFeedbackHeaderNavy = Color(0xFF173650);
const _kFeedbackHeaderMuted = Color(0xFF617F91);

/// Requestor Feedback illustrated banner.
///
/// When [includeTopActions] is false (preferred with [RequestorBrandAppBar]),
/// only the scrollable artwork card is built.
class RequestorFeedbackIllustratedHeader extends StatelessWidget {
  const RequestorFeedbackIllustratedHeader({
    super.key,
    this.title = 'Feedback',
    this.subtitle =
        'Share your experience. Help us improve event coverage.',
    this.onNotificationsTap,
    this.onProfileTap,
    this.includeTopActions = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  /// When true, wraps SafeArea and shows notification/profile (legacy).
  final bool includeTopActions;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final banner = _RequestorFeedbackHeaderBanner(
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

class _RequestorFeedbackHeaderBanner extends StatelessWidget {
  const _RequestorFeedbackHeaderBanner({
    required this.title,
    required this.subtitle,
    required this.narrow,
  });

  final String title;
  final String subtitle;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    // Home-style card: ClipRRect + AspectRatio. Cover (not fill) so the
    // artwork's baked white corner canvas is cropped away.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kFeedbackHeaderRadius),
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
        borderRadius: BorderRadius.circular(_kFeedbackHeaderRadius),
        child: AspectRatio(
          aspectRatio: _kFeedbackHeaderDisplayAspect,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              const ColoredBox(color: _kFeedbackHeaderUnderpaint),
              Image.asset(
                kRequestorFeedbackHeaderAsset,
                fit: BoxFit.cover,
                // Bias right: keep camera/stars right, left gradient under text.
                alignment: const Alignment(0.55, 0.0),
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 14 : 16,
                  narrow ? 12 : 14,
                  narrow ? 12 : 14,
                  narrow ? 12 : 14,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    // Stay inside the clear left zone of the artwork.
                    widthFactor: narrow ? 0.46 : 0.44,
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
                            color: _kFeedbackHeaderNavy,
                            fontSize: narrow ? 20 : 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.08,
                          )),
                        ),
                        SizedBox(height: narrow ? 6 : 7),
                        Text(
                          subtitle,
                          maxLines: 3,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: _kFeedbackHeaderMuted,
                            fontSize: narrow ? 11 : 12,
                            fontWeight: FontWeight.w500,
                            height: 1.32,
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
