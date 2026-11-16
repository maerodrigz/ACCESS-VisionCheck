import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/widgets/login/login_error_toast.dart';

/// Holds a single floating login notice and auto-dismiss timer.
mixin LoginNoticeHost<T extends StatefulWidget> on State<T> {
  Timer? _loginNoticeTimer;
  String? loginNoticeTitle;
  String? loginNoticeMessage;
  LoginNoticeKind? loginNoticeKind;
  String? loginNoticeActionLabel;
  VoidCallback? loginNoticeAction;

  /// Clearance above the legal footer / copyright when the keyboard is closed.
  static const footerClearance = 96.0;

  Duration durationFor(LoginNoticeKind kind) => kind.displayDuration;

  void showLoginNotice(
    String message,
    LoginNoticeKind kind, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _loginNoticeTimer?.cancel();
    setState(() {
      loginNoticeTitle = title?.trim().isEmpty == true ? null : title?.trim();
      loginNoticeMessage = trimmed;
      loginNoticeKind = kind;
      loginNoticeActionLabel = actionLabel;
      loginNoticeAction = onAction;
    });
    _loginNoticeTimer = Timer(durationFor(kind), () {
      if (!mounted) return;
      dismissLoginNotice();
    });
  }

  void dismissLoginNotice() {
    _loginNoticeTimer?.cancel();
    _loginNoticeTimer = null;
    if (!mounted) return;
    if (loginNoticeMessage == null && loginNoticeKind == null) return;
    setState(() {
      loginNoticeTitle = null;
      loginNoticeMessage = null;
      loginNoticeKind = null;
      loginNoticeActionLabel = null;
      loginNoticeAction = null;
    });
  }

  void disposeLoginNotice() {
    _loginNoticeTimer?.cancel();
    _loginNoticeTimer = null;
  }

  /// Bottom offset for the toast overlay.
  ///
  /// Keyboard open: sit just above the IME.
  /// Keyboard closed: clear the legal footer without climbing into the inputs.
  @visibleForTesting
  static double toastBottomOffset({
    required double keyboardInset,
    required double safeBottom,
    required double screenHeight,
  }) {
    if (keyboardInset > 0) {
      return keyboardInset + 16;
    }
    final preferred = safeBottom + footerClearance;
    final maxFromBottom = screenHeight * 0.34;
    return math.min(math.max(preferred, safeBottom + 16), maxFromBottom);
  }

  /// Overlay toast with intrinsic height; centered with a responsive max width.
  Widget buildWithLoginNotice(Widget child) {
    final message = loginNoticeMessage;
    final kind = loginNoticeKind;
    final title = loginNoticeTitle;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (message != null && kind != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final bottom = toastBottomOffset(
                keyboardInset: media.viewInsets.bottom,
                safeBottom: media.padding.bottom,
                screenHeight: constraints.maxHeight,
              );
              final maxToastWidth = math.min(360.0, constraints.maxWidth - 32);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottom,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxToastWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: LoginErrorToast(
                              key: ValueKey('login-toast-$kind'),
                              title: title,
                              message: message,
                              kind: kind,
                              onDismiss: dismissLoginNotice,
                              actionLabel: loginNoticeActionLabel,
                              onAction: loginNoticeAction == null
                                  ? null
                                  : () {
                                      final action = loginNoticeAction;
                                      dismissLoginNotice();
                                      action?.call();
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
