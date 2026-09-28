import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

void showAllAnnouncementsSheet(BuildContext context) {
  final items = appState.announcements;
  showModalBottomSheet(
    context: context,
    backgroundColor: kDashCardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kDashBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('All Announcements', style: memberDashboardSectionTitleStyle),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: kDashTextSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AnnouncementTile(announcement: items[i]),
            ),
          ),
        ],
      ),
    ),
  );
}

void showAnnouncementDetailSheet(BuildContext context, Announcement item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kDashCardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.88,
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
            Text(item.title, style: memberDashboardCardTitleStyle.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            MemberDashboardMetaRow(icon: Icons.calendar_today_outlined, label: item.date),
            const SizedBox(height: 16),
            Text(item.content, style: memberDashboardBodyStyle.copyWith(color: kDashTextPrimary)),
          ],
        ),
      ),
    ),
  );
}

class MemberDashboardAnnouncements extends StatelessWidget {
  const MemberDashboardAnnouncements({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final items = appState.announcements.take(3).toList();

        return MemberDashboardSection(
          title: 'Announcements',
          subtitle: 'Updates from ACCESS administrators',
          trailing: items.isNotEmpty
              ? MemberDashboardTextButton(
                  label: 'View All',
                  onPressed: () => showAllAnnouncementsSheet(context),
                )
              : null,
          child: items.isEmpty
              ? MemberDashboardEmptyState(
                  icon: Icons.campaign_outlined,
                  message: 'Important updates from ACCESS administrators will appear here when posted.',
                  backgroundColor: kDashAccentAnnouncements,
                  iconColor: kMemberDashboardAccent,
                )
              : Container(
                  decoration: memberDashboardCardDecoration(
                    backgroundColor: kDashAccentAnnouncements,
                    borderColor: kMemberDashboardAccent.withValues(alpha: 0.12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: kMemberDashboardAccent.withValues(alpha: 0.12)),
                        MemberDashboardTapScale(
                          onTap: () => showAnnouncementDetailSheet(context, items[i]),
                          child: _AnnouncementTile(announcement: items[i]),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kDashCardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign_outlined, color: kMemberDashboardAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(announcement.date, style: memberDashboardMetaStyle),
                const SizedBox(height: 2),
                Text(announcement.title, style: memberDashboardCardTitleStyle),
                const SizedBox(height: 4),
                Text(
                  announcement.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: kDashTextSecondary, size: 20),
        ],
      ),
    );
  }
}
