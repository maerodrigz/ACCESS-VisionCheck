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
  });

  final Widget body;
  final bool scrollable;

  /// Used when [scrollable] is true (registration screens).
  final double headerHeightFactor;

  /// Sign-in: adaptive header; body scrolls inside the white card when needed.
  final bool fixedViewport;

  double _headerHeight(MediaQueryData media) {
    if (fixedViewport) {
      if (media.viewInsets.bottom > 0) {
        return MobileAuthConstants.signInHeaderKeyboardHeight;
      }
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
    final headerH = _headerHeight(media);
    final keyboardOpen = media.viewInsets.bottom > 0;

    Widget bodySlot(Widget child) {
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

      return DecoratedBox(
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                12 + media.viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: keyboardOpen ? 0 : constraints.maxHeight,
                ),
                child: child,
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: fixedViewport ? kBg : kSurface,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: headerH,
            child: MobileAuthHeader(
              compact: fixedViewport,
              minimal: fixedViewport && keyboardOpen,
            ),
          ),
          Expanded(child: bodySlot(body)),
        ],
      ),
    );
  }
}
