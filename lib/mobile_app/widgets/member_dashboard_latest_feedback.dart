import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/sheets/evaluation_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

class LatestAdminFeedback {
  const LatestAdminFeedback({
    required this.eventName,
    required this.preview,
    required this.date,
    required this.fullMessage,
    required this.adminName,
    this.evaluation,
    this.isRankingRemarks = false,
  });

  final String eventName;
  final String preview;
  final String date;
  final String fullMessage;
  final String adminName;
  final Evaluation? evaluation;
  final bool isRankingRemarks;

  static LatestAdminFeedback? fromAppState() {
    for (final ev in appState.evaluations) {
      final message = ev.feedback.trim();
      if (message.isEmpty) continue;
      return LatestAdminFeedback(
        eventName: _eventNameForEvaluation(ev),
        preview: _preview(message),
        date: ev.date.isNotEmpty ? ev.date : 'Recently',
        fullMessage: message,
        adminName: 'ACCESS Administrator',
        evaluation: ev,
      );
    }

    final remarks = appState.profileAdminRemarks?.trim();
    if (remarks != null && remarks.isNotEmpty) {
      return LatestAdminFeedback(
        eventName: 'Performance Review',
        preview: _preview(remarks),
        date: 'Recently',
        fullMessage: remarks,
        adminName: 'ACCESS Administrator',
        isRankingRemarks: true,
      );
    }

    return null;
  }

  static String _eventNameForEvaluation(Evaluation ev) {
    for (final item in appState.gallery) {
      if (item.title == ev.title && item.requestId != null) {
        for (final task in appState.challenges) {
          if (task.requestId == item.requestId && task.title.isNotEmpty) {
            return task.title;
          }
        }
      }
    }
    for (final task in appState.challenges) {
      if (task.title.isNotEmpty) return task.title;
    }
    return ev.title;
  }

  static String _preview(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 120) return cleaned;
    return '${cleaned.substring(0, 117)}…';
  }
}

void showAdminFeedbackSheet(BuildContext context, LatestAdminFeedback item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kDashCardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: kDashBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(item.eventName, style: memberDashboardCardTitleStyle.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            MemberDashboardMetaRow(icon: Icons.person_outline_rounded, label: item.adminName),
            const SizedBox(height: 4),
            MemberDashboardMetaRow(icon: Icons.calendar_today_outlined, label: item.date),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kDashAccentFeedback,
                borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                border: Border.all(color: kDashBorder),
              ),
              child: Text(
                item.fullMessage,
                style: memberDashboardBodyStyle.copyWith(color: kDashTextPrimary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MemberDashboardLatestFeedback extends StatelessWidget {
  const MemberDashboardLatestFeedback({super.key});

  void _viewFeedback(BuildContext context, LatestAdminFeedback item) {
    if (item.evaluation != null) {
      showEvaluationDetail(context, item.evaluation!);
      return;
    }
    showAdminFeedbackSheet(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final latest = LatestAdminFeedback.fromAppState();

        return MemberDashboardSection(
          title: 'Latest Feedback',
          subtitle: 'Most recent review from an ACCESS administrator',
          child: latest == null
              ? MemberDashboardEmptyState(
                  icon: Icons.rate_review_outlined,
                  message:
                      'Keep participating! Administrator feedback will appear after your completed documentation assignments.',
                  backgroundColor: kDashCardBg,
                  iconColor: kDashAccentFeedbackIcon,
                )
              : Container(
                  padding: const EdgeInsets.all(kMemberDashboardCardPadding),
                  decoration: memberDashboardCardDecoration(
                    backgroundColor: kDashCardBg,
                    borderColor: kDashBorder,
                    shadows: memberDashboardCardShadows(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: kDashCardBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: kDashAccentFeedbackIcon,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(latest.adminName, style: memberDashboardCardTitleStyle),
                                const SizedBox(height: 2),
                                MemberDashboardMetaRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: latest.date,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        latest.eventName,
                        style: memberDashboardMetaStyle.copyWith(
                          color: kDashAccentFeedbackIcon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kDashCardBg,
                          borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                          border: Border.all(color: kDashBorder),
                        ),
                        child: Text(
                          '"${latest.preview}"',
                          style: memberDashboardBodyStyle.copyWith(
                            color: kDashTextPrimary,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MemberDashboardPrimaryButton(
                        label: 'View Feedback',
                        icon: Icons.open_in_new_rounded,
                        color: kDashAccentFeedbackIcon,
                        onPressed: () => _viewFeedback(context, latest),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
