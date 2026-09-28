import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Confirms self-registration before returning the user to login.
Future<void> showRegistrationSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Back to Sign In',
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
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
