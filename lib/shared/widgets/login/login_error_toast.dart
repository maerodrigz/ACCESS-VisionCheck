import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Compact login failure categories (UI timing + styling only).
enum LoginNoticeKind {
  credentials,
  lockout,
  network,
  server,
  validation,
}

extension LoginNoticeKindTiming on LoginNoticeKind {
  Duration get displayDuration => switch (this) {
        LoginNoticeKind.credentials => const Duration(seconds: 3),
        LoginNoticeKind.lockout => const Duration(seconds: 5),
        LoginNoticeKind.network => const Duration(seconds: 4),
        LoginNoticeKind.server => const Duration(seconds: 4),
        LoginNoticeKind.validation => const Duration(seconds: 3),
      };
}

/// Compact floating login toast. Intrinsic height only; wraps up to 3 lines.
class LoginErrorToast extends StatelessWidget {
  const LoginErrorToast({
    super.key,
    required this.message,
    required this.kind,
    required this.onDismiss,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  /// Optional bold title (lockout). When null, [message] is the only text.
  final String? title;
  final String message;
  final LoginNoticeKind kind;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const _bg = Color(0xFF1E293B);
  static const _fg = Color(0xFFF8FAFC);
  static const _muted = Color(0xFFCBD5E1);

  Color get _accent => switch (kind) {
        LoginNoticeKind.lockout => kYellow,
        LoginNoticeKind.network => kCyan,
        LoginNoticeKind.validation => const Color(0xFFCBD5E1),
        LoginNoticeKind.server => kRed,
        LoginNoticeKind.credentials => const Color(0xFFFBBF24),
      };

  IconData get _icon => switch (kind) {
        LoginNoticeKind.lockout => Icons.lock_clock_outlined,
        LoginNoticeKind.network => Icons.wifi_off_rounded,
        LoginNoticeKind.validation => Icons.info_outline_rounded,
        LoginNoticeKind.server => Icons.error_outline_rounded,
        LoginNoticeKind.credentials => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    final hasTitle = title != null && title!.trim().isNotEmpty;
    final scaler = MediaQuery.textScalerOf(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scaler.scale(1).clamp(1.0, 1.1)),
      ),
      child: Semantics(
        container: true,
        label: 'login_error_toast_v2',
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                Icon(_icon, color: _accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitle)
                        Text(
                          title!.trim(),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: _fg,
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (hasTitle) const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: hasTitle ? 3 : 2,
                        softWrap: true,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: hasTitle ? _muted : _fg,
                          fontSize: hasTitle ? 12.5 : 13,
                          height: 1.25,
                          fontWeight: hasTitle ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                      if (hasAction) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: onAction,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            actionLabel!,
                            style: const TextStyle(
                              color: kCyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Dismiss',
                  child: GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
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
