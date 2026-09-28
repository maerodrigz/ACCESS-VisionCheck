import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_home_dashboard.dart';

/// Member home — dashboard hub (hero, quick actions, focus, feeds).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.userName = '',
    this.onLogout,
    this.onViewPortfolio,
    this.onViewEventGallery,
    this.onViewCalendar,
    this.onViewRankings,
    this.onViewNotifications,
    this.onProfileTap,
  });

  final String userName;
  final VoidCallback? onLogout;
  final VoidCallback? onViewPortfolio;
  final VoidCallback? onViewEventGallery;
  final VoidCallback? onViewCalendar;
  final VoidCallback? onViewRankings;
  final VoidCallback? onViewNotifications;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kMemberDashboardBg,
      child: ListenableBuilder(
        listenable: Listenable.merge([memberDataController, appState]),
        builder: (context, _) {
          final syncing =
              memberDataController.isLoading || appState.isSyncingMemberData;

          return MemberHomeDashboard(
            isSyncing: syncing,
            userName: userName,
            onLogout: onLogout,
            onViewPortfolio: onViewPortfolio,
            onViewEventGallery: onViewEventGallery,
            onViewCalendar: onViewCalendar,
            onViewRankings: onViewRankings,
            onViewNotifications: onViewNotifications,
            onProfileTap: onProfileTap,
            onRefresh: () => memberDataController.refreshHomeTab(),
          );
        },
      ),
    );
  }
}
