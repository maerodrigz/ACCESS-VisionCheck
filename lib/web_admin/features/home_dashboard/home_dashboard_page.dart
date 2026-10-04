import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_data.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/active_documenters_panel.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/evaluation_trend_chart.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/media_evaluation_overview_panel.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/overview_cards.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/pending_requests_section.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/today_schedule_section.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/welcome_header.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/error_state.dart';
import 'package:access_mobile/web_admin/layout/skeleton_loading.dart';
import 'package:access_mobile/web_admin/navigation/admin_navigation_scope.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

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
      if (mounted) setState(() { _data = snap; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
              // ── Header (greeting + refresh + date) ──────────────────────
              WelcomeHeader(adminName: name, onRefresh: _load),

              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorState(
                  title: 'Some dashboard data could not load',
                  message: _error!,
                  onRetry: _load,
                ),
              ],

              if (_data != null) ...[
                const SizedBox(height: 20),

                // ── 4 overview stat cards ────────────────────────────────
                OverviewStatCards(stats: _data!.overview, onNavigate: _navigate),

                const SizedBox(height: 20),

                // ── Middle row: Action Center | Today's Schedule ─────────
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= AdminBreakpoints.desktop;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Action Center (left, wider)
                          Expanded(
                            flex: 55,
                            child: ActionCenterSection(
                              items: _data!.actionCenterItems,
                              pendingCount: _data!.overview.pendingRequests,
                              mediaPendingCount: _data!.overview.mediaPendingEvaluation,
                              onNavigate: _navigate,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Today's Schedule (right)
                          Expanded(
                            flex: 45,
                            child: TodayScheduleSection(
                              items: _data!.todaySchedule,
                              onNavigate: _navigate,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        ActionCenterSection(
                          items: _data!.actionCenterItems,
                          pendingCount: _data!.overview.pendingRequests,
                          mediaPendingCount: _data!.overview.mediaPendingEvaluation,
                          onNavigate: _navigate,
                        ),
                        const SizedBox(height: 16),
                        TodayScheduleSection(
                          items: _data!.todaySchedule,
                          onNavigate: _navigate,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ── Bottom row: Eval Overview | Trend Chart | Active Docs ─
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= AdminBreakpoints.desktop;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Media Evaluation Overview
                          Expanded(
                            flex: 32,
                            child: MediaEvaluationOverviewPanel(
                              stats: _data!.evalOverview,
                              onNavigate: _navigate,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Evaluation Trend chart
                          Expanded(
                            flex: 38,
                            child: EvaluationTrendChart(
                              points: _data!.evalTrend,
                              onNavigate: _navigate,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Active Documenters
                          Expanded(
                            flex: 30,
                            child: ActiveDocumentersPanel(
                              snapshot: _data!.activeDocumenters,
                              onNavigate: _navigate,
                            ),
                          ),
                        ],
                      );
                    }
                    // Narrow: stack them
                    return Column(
                      children: [
                        MediaEvaluationOverviewPanel(
                          stats: _data!.evalOverview,
                          onNavigate: _navigate,
                        ),
                        const SizedBox(height: 16),
                        EvaluationTrendChart(
                          points: _data!.evalTrend,
                          onNavigate: _navigate,
                        ),
                        const SizedBox(height: 16),
                        ActiveDocumentersPanel(
                          snapshot: _data!.activeDocumenters,
                          onNavigate: _navigate,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
