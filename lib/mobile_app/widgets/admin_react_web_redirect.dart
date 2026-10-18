import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

/// Shown when an administrator opens the Flutter web build.
/// Production admin UI is React (`admin-web/`), not Flutter.
class AdminReactWebRedirect extends StatelessWidget {
  const AdminReactWebRedirect({
    super.key,
    required this.userName,
    required this.onLogout,
  });

  final String userName;
  final VoidCallback onLogout;

  static const _reactAdminDevUrl = 'http://127.0.0.1:5173';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Administrator sign-in'),
        actions: [
          TextButton(onPressed: onLogout, child: const Text('Sign out')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.computer_rounded, size: 48, color: kAccent.withValues(alpha: 0.9)),
                const SizedBox(height: 16),
                Text(
                  'Use the React web admin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Signed in as $userName. The ACCESS administrator dashboard runs in the React app (admin-web), not in Flutter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.45, color: kTextSecondary),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  _reactAdminDevUrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start it with: cd admin-web && npm run dev',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: kTextSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onLogout,
                  style: FilledButton.styleFrom(
                    backgroundColor: kMemberButtonPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
