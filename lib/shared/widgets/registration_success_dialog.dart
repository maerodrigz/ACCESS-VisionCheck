import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';

/// Confirms self-registration before returning the user to login.
Future<void> showRegistrationSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Back to Sign in',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kGreenDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_outline, color: kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(height: 1.45, color: kTextSecondary)),
      actions: [
        SizedBox(
          width: double.infinity,
          child: MobileAuthGradientButton(
            label: confirmLabel,
            compact: true,
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
      ],
    ),
  );
}
