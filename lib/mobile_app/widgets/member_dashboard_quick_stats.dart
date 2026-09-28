import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

/// Four-up quick stats grid for the member home dashboard.
class MemberDashboardQuickStats extends StatelessWidget {
  const MemberDashboardQuickStats({super.key});

  static int _submittedMedia() {
    if (appState.profileUploads > 0) return appState.profileUploads;
    return appState.gallery.length;
  }

  static int _approvedRequests() {
    if (appState.profileAssignmentsCompleted > 0) {
      return appState.profileAssignmentsCompleted;
    }
    return appState.challenges.where((c) {
      final s = c.status.toLowerCase();
      return s == 'accepted' ||
          s == 'in_progress' ||
          s == 'completed' ||
          s == 'done';
    }).length;
  }

  static int _portfolioItems() => appState.gallery.length;

  static String _averageScoreLabel() {
    var avg = appState.profileAverageScore;
    if (avg <= 0 && appState.evaluations.isNotEmpty) {
      final scored = appState.evaluations.where((e) => e.score > 0).toList();
      if (scored.isNotEmpty) {
        avg = scored.fold<double>(0, (sum, e) => sum + e.score) / scored.length;
      }
    }
    if (avg <= 0) return 'N/A';
    final pct = avg <= 1 ? (avg * 100).round() : avg.round();
    return '$pct%';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final stats = [
          (
            icon: Icons.upload_rounded,
            value: '${_submittedMedia()}',
            label: 'Submitted Media',
            iconColor: kStatIconMedia,
          ),
          (
            icon: Icons.check_circle_outline_rounded,
            value: '${_approvedRequests()}',
            label: 'Approved Requests',
            iconColor: kStatIconSuccess,
          ),
          (
            icon: Icons.collections_bookmark_outlined,
            value: '${_portfolioItems()}',
            label: 'Portfolio Items',
            iconColor: kStatIconPurple,
          ),
          (
            icon: Icons.insights_rounded,
            value: _averageScoreLabel(),
            label: 'Average Evaluation Score',
            iconColor: kStatIconWarning,
          ),
        ];

        return MemberDashboardSection(
          title: 'Quick Statistics',
          subtitle: 'Your documentation activity at a glance',
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final tileWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: stats
                    .map(
                      (s) => SizedBox(
                        width: tileWidth,
                        child: AccessStatCard(
                          icon: s.icon,
                          value: s.value,
                          label: s.label,
                          iconColor: s.iconColor,
                          dashboardLayout: true,
                          compact: true,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        );
      },
    );
  }
}
