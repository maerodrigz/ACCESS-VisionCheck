import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

class MobileAuthSectionHeader extends StatelessWidget {
  const MobileAuthSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: MobileAuthConstants.signInGradient,
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        Text(
          title,
          style: TextStyle(
            color: kTextPrimary,
            fontSize: compact ? 22 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: compact ? 4 : 6),
          Text(
            subtitle!,
            style: TextStyle(
              color: kTextSecondary,
              fontSize: compact ? 13 : 14,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class MobileAuthGradientButton extends StatelessWidget {
  const MobileAuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MobileAuthConstants.buttonRadius),
        gradient: enabled ? MobileAuthConstants.signInGradient : null,
        color: enabled ? null : kBorder,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: kCyan.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(MobileAuthConstants.buttonRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 13 : 15),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: enabled ? Colors.white : kTextSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cyan outline button (matches header; used for secondary actions like Send code).
class MobileAuthOutlineButton extends StatelessWidget {
  const MobileAuthOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: kCyan,
        disabledForegroundColor: kTextSecondary,
        side: BorderSide(color: enabled ? kCyan : kBorder),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MobileAuthConstants.buttonRadius),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class MobileAuthBackButton extends StatelessWidget {
  const MobileAuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class MobileAuthTextLinkRow extends StatelessWidget {
  const MobileAuthTextLinkRow({
    super.key,
    required this.prompt,
    required this.linkLabel,
    required this.onLinkTap,
  });

  final String prompt;
  final String linkLabel;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
        TextButton(
          onPressed: onLinkTap,
          style: TextButton.styleFrom(
            foregroundColor: kCyan,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(linkLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}

InputDecoration mobileAuthInputDecoration({
  required String hint,
  IconData? icon,
  Widget? suffix,
  bool dense = false,
}) {
  const radius = MobileAuthConstants.fieldRadius;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: kTextSecondary, fontSize: dense ? 13 : 14),
    prefixIcon: icon != null ? Icon(icon, color: kTextSecondary, size: 20) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: kSurface,
    isDense: dense,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 12 : 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kCyan, width: 1.5),
    ),
  );
}

Widget mobileAuthErrorBanner(String message, {int maxLines = 4}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: kRedDim,
      borderRadius: BorderRadius.circular(MobileAuthConstants.fieldRadius),
      border: Border.all(color: kRed.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: kRed, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kRed, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    ),
  );
}
