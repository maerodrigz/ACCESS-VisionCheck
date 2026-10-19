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

  /// Sign-in: cyan hero + white form sheet above the keyboard.
  final bool fixedViewport;

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

    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _headerHeight(media),
          child: MobileAuthHeader(compact: fixedViewport),
        ),
        Expanded(child: _bodySlot(body, media)),
      ],
    );

    return Scaffold(
      backgroundColor: kSurface,
      resizeToAvoidBottomInset: true,
      body: ColoredBox(
        color: fixedViewport ? kSurface : kBg,
        child: column,
      ),
    );
  }

  Widget _bodySlot(Widget child, MediaQueryData media) {
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: kSurface,
        child: LayoutBuilder(
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
        ),
      ),
    );
  }
}
