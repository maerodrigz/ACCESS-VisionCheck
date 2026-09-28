import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

/// Log out control for the member Profile tab.
class MemberProfileLogoutSection extends StatelessWidget {
  const MemberProfileLogoutSection({super.key});

  static Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDashCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out?',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to log out of your ACCESS VisionCheck account?',
          style: memberDashboardMetaStyle.copyWith(height: 1.45, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: dashText(const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Log Out',
              style: dashText(const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await _confirmLogout(context);
    if (!confirmed || !context.mounted) return;
    await authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleLogout(context),
          borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
          child: Container(
            width: double.infinity,
            height: kMobileMinTouch,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: kRed.withValues(alpha: 0.9), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Log Out',
                  style: dashText(const TextStyle(
                    color: kRed,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
