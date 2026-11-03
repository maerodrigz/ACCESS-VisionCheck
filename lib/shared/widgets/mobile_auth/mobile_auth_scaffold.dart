import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_header.dart';

/// Shared mobile auth layout: header + body (scrollable for long forms, fixed for sign-in).
class MobileAuthScaffold extends StatelessWidget {
  const MobileAuthScaffold({
    super.key,
    required this.body,
    this.scrollable = true,
    this.headerHeightFactor = MobileAuthConstants.headerHeightFactor,
    this.fixedViewport = false,
    this.backgroundAsset,
  });

  final Widget body;
  final bool scrollable;

  /// Used when [scrollable] is true (registration screens).
  final double headerHeightFactor;

  /// Sign-in: hero + white form sheet above the keyboard.
  final bool fixedViewport;

  /// Full-screen decorative background (sign-in art); header and form stay as widgets on top.
  final String? backgroundAsset;

  double _headerHeight(MediaQueryData media) {
    if (fixedViewport) {
      final h = media.size.height * MobileAuthConstants.signInHeaderHeightFactor;
      return h.clamp(
        MobileAuthConstants.signInHeaderMinHeight,
        MobileAuthConstants.signInHeaderMaxHeight,
      );
    }
    final h = media.size.height * headerHeightFactor;
    return h.clamp(200, 280);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final imageBacked = backgroundAsset != null && backgroundAsset!.isNotEmpty;

    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _headerHeight(media),
          child: MobileAuthHeader(
            compact: fixedViewport,
            imageBacked: imageBacked,
          ),
        ),
        Expanded(child: _bodySlot(body, media, imageBacked: imageBacked)),
      ],
    );

    if (imageBacked) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: kSurface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
            SafeArea(top: false, bottom: false, child: column),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      resizeToAvoidBottomInset: true,
      body: ColoredBox(
        color: fixedViewport ? kSurface : kBg,
        child: column,
      ),
    );
  }

  Widget _bodySlot(Widget child, MediaQueryData media, {required bool imageBacked}) {
    if (scrollable) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + media.viewInsets.bottom,
        ),
        child: child,
      );
    }

    const formPadding = EdgeInsets.fromLTRB(24, 8, 24, 12);

    final scrollChild = LayoutBuilder(
      builder: (context, constraints) {
        final minBodyHeight = constraints.maxHeight - formPadding.vertical;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: formPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minBodyHeight > 0 ? minBodyHeight : 0,
              ),
              child: child,
            ),
          ),
        );
      },
    );

    if (imageBacked) {
      return scrollChild;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: kSurface,
        child: scrollChild,
      ),
    );
  }
}
