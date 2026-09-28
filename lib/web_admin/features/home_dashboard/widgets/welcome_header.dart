import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key, required this.adminName});

  final String adminName;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = adminName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting, $firstName!',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AdminTheme.textPrimary,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Here\'s what needs your attention today.',
          style: TextStyle(fontSize: 14, color: AdminTheme.textSecondary.withValues(alpha: 0.95), height: 1.4),
        ),
      ],
    );
  }
}
