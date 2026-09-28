import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/stat_card.dart';

/// "My Activity" — four stat cards with semantic icon accents (white tiles).
class MemberDashboardMyActivity extends StatelessWidget {
  const MemberDashboardMyActivity({super.key});

  static int _eventsCovered() {
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

  static int _submittedMedia() {
    if (appState.profileUploads > 0) return appState.profileUploads;
    return appState.gallery.length;
  }

  static String _averageScore() {
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

  static int _portfolioItems() => appState.gallery.length;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final stats = [
          (
            icon: Icons.event_available_outlined,
            value: '${_eventsCovered()}',
            label: 'Events Covered',
            iconColor: kStatIconPrimary,
          ),
          (
            icon: Icons.upload_outlined,
            value: '${_submittedMedia()}',
            label: 'Submitted Media',
            iconColor: kStatIconMedia,
          ),
          (
            icon: Icons.insights_outlined,
            value: _averageScore(),
            label: 'Average Evaluation Score',
            iconColor: kStatIconWarning,
          ),
          (
            icon: Icons.collections_bookmark_outlined,
            value: '${_portfolioItems()}',
            label: 'Portfolio Items',
            iconColor: kStatIconPurple,
          ),
        ];

        return MemberDashboardSection(
          title: 'My Activity',
          subtitle: 'Your documentation performance summary',
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
