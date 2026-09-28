import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_data.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/home_panels.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/overview_cards.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/pending_requests_section.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/today_schedule_section.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/welcome_header.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/error_state.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/layout/skeleton_loading.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Action-oriented admin command center — no charts or statistical reports.
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  HomeDashboardSnapshot? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await fetchHomeDashboard();
      if (mounted) {
        setState(() {
          _data = snap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _navigate(AdminRoute route, {Map<String, dynamic>? params}) {
    AdminNavigationScope.go(context, route, params: params);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(color: AdminTheme.contentBg, child: AdminPageSkeleton());
    }

    final admin = AdminSessionScope.maybeOf(context);
    final name = admin?.name ?? 'Admin';

    return Container(
      color: AdminTheme.contentBg,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AdminTheme.accentBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AdminBreakpoints.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: WelcomeHeader(adminName: name)),
                  PageHeaderRefreshButton(onPressed: _load),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorState(
                  title: 'Some dashboard data could not load',
                  message: _error!,
                  onRetry: _load,
                ),
              ],
              if (_data != null) ...[
                const SizedBox(height: 24),
                OverviewStatCards(stats: _data!.overview, onNavigate: _navigate),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= AdminBreakpoints.desktop;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                PendingRequestsSection(requests: _data!.pendingRequests, onNavigate: _navigate),
                                const SizedBox(height: 16),
                                RecentActivitySection(items: _data!.recentActivity, onNavigate: _navigate),
                                const SizedBox(height: 16),
                                MediaEvaluationQueuePanel(queue: _data!.mediaQueue, onNavigate: _navigate),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                TodayScheduleSection(items: _data!.todaySchedule, onNavigate: _navigate),
                                const SizedBox(height: 16),
                                NotificationsPanel(items: _data!.notifications, onNavigate: _navigate),
                                const SizedBox(height: 16),
                                QuickActionsGrid(onNavigate: _navigate),
                                const SizedBox(height: 16),
                                AnnouncementsPanel(items: _data!.announcements),
                                const SizedBox(height: 16),
                                AiSummaryPanel(snapshot: _data!),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        PendingRequestsSection(requests: _data!.pendingRequests, onNavigate: _navigate),
                        const SizedBox(height: 16),
                        TodayScheduleSection(items: _data!.todaySchedule, onNavigate: _navigate),
                        const SizedBox(height: 16),
                        MediaEvaluationQueuePanel(queue: _data!.mediaQueue, onNavigate: _navigate),
                        const SizedBox(height: 16),
                        QuickActionsGrid(onNavigate: _navigate),
                        const SizedBox(height: 16),
                        NotificationsPanel(items: _data!.notifications, onNavigate: _navigate),
                        const SizedBox(height: 16),
                        RecentActivitySection(items: _data!.recentActivity, onNavigate: _navigate),
                        const SizedBox(height: 16),
                        AnnouncementsPanel(items: _data!.announcements),
                        const SizedBox(height: 16),
                        AiSummaryPanel(snapshot: _data!),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                ViewAnalyticsBanner(onNavigate: _navigate),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
