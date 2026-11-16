import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_fixed_background.dart';
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

  double _headerHeight(double screenHeight) {
    final imageBacked = backgroundAsset != null && backgroundAsset!.isNotEmpty;
    if (fixedViewport || imageBacked) {
      final h = screenHeight * MobileAuthConstants.signInHeaderHeightFactor;
      return h.clamp(
        MobileAuthConstants.signInHeaderMinHeight,
        MobileAuthConstants.signInHeaderMaxHeight,
      );
    }
    final h = screenHeight * headerHeightFactor;
    return h.clamp(200, 280);
  }

  /// Mobile sign-up flows: same midnight scanner background as sign-in.
  factory MobileAuthScaffold.signUp({required Widget body}) {
    return MobileAuthScaffold(
      backgroundAsset: MobileAuthConstants.signInBackgroundAsset,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final imageBacked = backgroundAsset != null && backgroundAsset!.isNotEmpty;
    final keyboardBottom = media.viewInsets.bottom;
    // Full layout height (keyboard does not shrink body when resizeToAvoidBottomInset is false).
    final screenHeight = media.size.height;

    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _headerHeight(screenHeight),
          child: MobileAuthHeader(
            compact: fixedViewport || imageBacked,
            imageBacked: imageBacked,
          ),
        ),
        Expanded(
          child: _bodySlot(
            body,
            keyboardBottom: keyboardBottom,
            bottomSafe: media.padding.bottom,
            imageBacked: imageBacked,
          ),
        ),
      ],
    );

    if (imageBacked) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: MobileAuthConstants.midnightScaffoldColor,
        body: Stack(
          fit: StackFit.expand,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          children: [
            MobileAuthFixedBackground(assetPath: backgroundAsset!),
            SafeArea(
              top: true,
              bottom: false,
              child: column,
            ),
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

  Widget _bodySlot(
    Widget child, {
    required double keyboardBottom,
    required double bottomSafe,
    required bool imageBacked,
  }) {
    if (scrollable) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          24,
          imageBacked ? 6 : 4,
          24,
          16 + bottomSafe + keyboardBottom,
        ),
        child: child,
      );
    }

    const formPadding = EdgeInsets.fromLTRB(24, 2, 24, 4);
    // Room for IME + compact login toast clearance so password stays visible.
    final keyboardPad = keyboardBottom > 0 ? keyboardBottom + 24 + 56 : 0.0;

    final scrollChild = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(bottom: keyboardPad),
      child: Padding(
        padding: formPadding,
        child: child,
      ),
    );

    if (imageBacked) {
      return scrollChild;
    }

    final scrollChildWithMinHeight = LayoutBuilder(
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: kSurface,
        child: scrollChildWithMinHeight,
      ),
    );
  }
}
