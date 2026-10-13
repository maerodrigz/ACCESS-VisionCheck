import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';
import 'package:access_mobile/mobile_app/sheets/event_detail_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_announcements.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_requestor_feedback.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';

const _horizontalPad = 18.0;

/// Member home — mock-aligned dashboard with dark hero and white content sheet.
class MemberHomeDashboard extends StatelessWidget {
  const MemberHomeDashboard({
    super.key,
    this.isSyncing = false,
    this.userName = '',
    this.onLogout,
    this.onViewPortfolio,
    this.onViewEventGallery,
    this.onViewCalendar,
    this.onViewRankings,
    this.onViewNotifications,
    this.onProfileTap,
    this.onViewAllRequestorFeedback,
    this.onRefresh,
  });

  final bool isSyncing;
  final String userName;
  final VoidCallback? onLogout;
  final VoidCallback? onViewPortfolio;
  final VoidCallback? onViewEventGallery;
  final VoidCallback? onViewCalendar;
  final VoidCallback? onViewRankings;
  final VoidCallback? onViewNotifications;
  final VoidCallback? onProfileTap;
  final VoidCallback? onViewAllRequestorFeedback;
  final Future<void> Function()? onRefresh;

  static int _activeTaskCount() {
    return appState.challenges.where((c) {
      if (c.completed) return false;
      final s = c.status.toLowerCase();
      return s != 'cancelled' && s != 'canceled' && s != 'declined';
    }).length;
  }

  static int _uploadCount() {
    if (appState.profileUploads > 0) return appState.profileUploads;
    return appState.gallery.length;
  }

  static bool _shouldShowGettingStarted() {
    if (authController.user?.role.isOrganization ?? false) return false;
    if (memberDataController.isLoading &&
        appState.evaluations.isEmpty &&
        appState.challenges.isEmpty) {
      return false;
    }
    if (appState.evaluations.isNotEmpty) return false;
    if (appState.challenges.isNotEmpty) return false;
    if (_uploadCount() > 0) return false;
    if (appState.gallery.isNotEmpty) return false;
    return true;
  }

  static String _aiQualityScore() {
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
      listenable: appState,
      builder: (context, _) {
        final assignment = memberActiveAssignment();
        final taskCount = _activeTaskCount();
        final uploads = _uploadCount();
        final aiScore = _aiQualityScore();

        return ColoredBox(
          color: kBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSyncing)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: kCyan,
                  backgroundColor: Color(0xFF1E293B),
                ),
              _HomeDarkHero(
                userName: userName,
                onNotifications: onViewNotifications,
                onProfileTap: onProfileTap,
                assignment: assignment,
                taskCount: taskCount,
                uploadCount: uploads,
                aiScore: aiScore,
                onEventTap: assignment != null
                    ? () => _openAssignment(context, assignment)
                    : onViewCalendar,
                onTasksTap: () => _openAllTasks(context),
                onUploadsTap: onViewEventGallery,
                onAiScoreTap: onViewPortfolio,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: kMemberPrimary,
                  displacement: 36,
                  strokeWidth: 2.5,
                  onRefresh: onRefresh ?? () async {},
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(_horizontalPad, 18, _horizontalPad, 32),
                    children: [
                      if (_shouldShowGettingStarted())
                        _MemberGettingStartedCard(
                          onStartPractice: onViewPortfolio,
                          onViewAssignments: () => _openAllTasks(context),
                        ),
                      if (_shouldShowGettingStarted()) const SizedBox(height: 20),
                      _HomeMyTasksSection(
                        onViewAll: () => _openAllTasks(context),
                        onViewCalendar: onViewCalendar,
                        onOpenTask: (task) => _openTask(context, task),
                      ),
                      const SizedBox(height: 24),
                      _HomeRecentUploadsSection(
                        onViewEventGallery: onViewEventGallery,
                        onViewPortfolio: onViewPortfolio,
                      ),
                      const SizedBox(height: 22),
                      _HomeAiEvaluationCard(onOpen: onViewPortfolio),
                      const SizedBox(height: 22),
                      _HomeSkillProgressSection(onViewRankings: onViewRankings),
                      const SizedBox(height: 22),
                      if (onViewAllRequestorFeedback != null)
                        MemberDashboardRequestorFeedbackSection(
                          onViewAll: onViewAllRequestorFeedback!,
                        ),
                      if (onViewAllRequestorFeedback != null) const SizedBox(height: 22),
                      const _HomeAnnouncementsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _openAssignment(BuildContext context, Challenge assignment) {
    _openTask(context, assignment);
  }

  static void _openTask(BuildContext context, Challenge task) {
    final event = calendarEventForAssignment(task);
    if (event != null) {
      showEventDetail(context, event);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
    );
  }

  static Future<void> _openGalleryItem(
    BuildContext context,
    GalleryItem item, {
    VoidCallback? onViewPortfolio,
    VoidCallback? onViewEventGallery,
  }) async {
    await openPortfolioGalleryItem(
      context,
      item,
      onViewPortfolio: onViewPortfolio ?? onViewEventGallery,
    );
  }

  static void _openAllTasks(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
    );
  }
}

// ── Dark hero ─────────────────────────────────────────────────────────────────

class _HomeDarkHero extends StatelessWidget {
  const _HomeDarkHero({
    required this.userName,
    this.onNotifications,
    this.onProfileTap,
    this.assignment,
    required this.taskCount,
    required this.uploadCount,
    required this.aiScore,
    this.onEventTap,
    this.onTasksTap,
    this.onUploadsTap,
    this.onAiScoreTap,
  });

  final String userName;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;
  final Challenge? assignment;
  final int taskCount;
  final int uploadCount;
  final String aiScore;
  final VoidCallback? onEventTap;
  final VoidCallback? onTasksTap;
  final VoidCallback? onUploadsTap;
  final VoidCallback? onAiScoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberDarkHeroBottomRadius),
          bottomRight: Radius.circular(kMemberDarkHeroBottomRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_horizontalPad, 4, _horizontalPad, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeTopBar(
                userName: userName,
                onNotifications: onNotifications,
                onProfileTap: onProfileTap,
              ),
              const SizedBox(height: 16),
              Text(
                '${memberDashboardGreeting()}, ${memberDashboardFirstName()}!',
                style: dashText(const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.2,
                )),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s what\'s happening with your documentation today.',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                )),
              ),
              const SizedBox(height: 14),
              _HomeFeaturedEventCard(
                assignment: assignment,
                onTap: onEventTap,
              ),
              const SizedBox(height: 12),
              _HomeHeroStats(
                taskCount: taskCount,
                uploadCount: uploadCount,
                aiScore: aiScore,
                onTasksTap: onTasksTap,
                onUploadsTap: onUploadsTap,
                onAiScoreTap: onAiScoreTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.userName,
    this.onNotifications,
    this.onProfileTap,
  });

  final String userName;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = authController.user?.name ?? userName;
    final initials = _initials(displayName);

    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: AccessBrandLockup(markSize: 40, compact: true),
            ),
            _HeroIconButton(
              icon: appState.unreadCount > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              badgeCount: appState.unreadCount,
              onTap: onNotifications,
            ),
            _HeroProfileAvatar(
              initials: initials,
              imageUrl: appState.profileImageUrl,
              onTap: onProfileTap,
            ),
          ],
        );
      },
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    this.badgeCount = 0,
    this.onTap,
  });

  static const _buttonSize = 40.0;

  final IconData icon;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: kMobileMinTouch,
          height: kMobileMinTouch,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: _buttonSize,
                  height: _buttonSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: kDashStatPurpleIcon,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF050C1C), width: 1.2),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroProfileAvatar extends StatelessWidget {
  const _HeroProfileAvatar({
    required this.initials,
    this.imageUrl,
    this.onTap,
  });

  static const _avatarSize = 38.0;

  final String initials;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: kMobileMinTouch,
          height: kMobileMinTouch,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            width: _avatarSize,
                            height: _avatarSize,
                            errorBuilder: (_, __, ___) => _InitialsBadge(initials: initials),
                          )
                        : _InitialsBadge(initials: initials),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: kGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF050C1C), width: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kCyan.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HomeFeaturedEventCard extends StatelessWidget {
  const _HomeFeaturedEventCard({
    this.assignment,
    this.onTap,
  });

  final Challenge? assignment;
  final VoidCallback? onTap;

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending_acceptance':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'accepted':
        return 'Confirmed';
      default:
        return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEvent = assignment != null;
    final title = hasEvent ? assignment!.title : 'No upcoming event';
    final date = hasEvent ? (assignment!.eventDate ?? 'Date TBA') : 'Check the calendar';
    final venue = hasEvent ? (assignment!.venue ?? '') : '';
    final meta = venue.isNotEmpty ? '$date • $venue' : date;
    final status = hasEvent ? _statusLabel(assignment!.status) : 'Browse';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: kMemberBrandAccentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    hasEvent ? Icons.calendar_today_outlined : Icons.calendar_month_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasEvent ? 'Upcoming Event' : 'Calendar',
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        )),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        )),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    status,
                    style: dashText(const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeroStats extends StatelessWidget {
  const _HomeHeroStats({
    required this.taskCount,
    required this.uploadCount,
    required this.aiScore,
    this.onTasksTap,
    this.onUploadsTap,
    this.onAiScoreTap,
  });

  final int taskCount;
  final int uploadCount;
  final String aiScore;
  final VoidCallback? onTasksTap;
  final VoidCallback? onUploadsTap;
  final VoidCallback? onAiScoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCyan.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _HeroStatCell(
                icon: Icons.calendar_today_outlined,
                value: '$taskCount',
                label: 'My Tasks',
                onTap: onTasksTap,
              ),
            ),
            _heroStatDivider,
            Expanded(
              child: _HeroStatCell(
                icon: Icons.photo_outlined,
                value: '$uploadCount',
                label: 'My Uploads',
                onTap: onUploadsTap,
              ),
            ),
            _heroStatDivider,
            Expanded(
              child: _HeroStatCell(
                icon: Icons.star_outline_rounded,
                value: aiScore,
                label: 'Avg. Quality Score',
                onTap: onAiScoreTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _heroStatDivider = VerticalDivider(
    width: 1,
    thickness: 1,
    indent: 12,
    endIndent: 12,
    color: kCyan.withValues(alpha: 0.22),
  );
}

class _HeroStatCell extends StatelessWidget {
  const _HeroStatCell({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(8, 11, 6, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: kCyan.withValues(alpha: 0.92)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.2,
                  )),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  )),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 15,
            color: kCyan.withValues(alpha: 0.75),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: kCyan.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: child,
      ),
    );
  }
}

// ── My Tasks (white content) ──────────────────────────────────────────────────

class _HomeMyTasksSection extends StatelessWidget {
  const _HomeMyTasksSection({
    this.onViewAll,
    this.onViewCalendar,
    this.onOpenTask,
  });

  final VoidCallback? onViewAll;
  final VoidCallback? onViewCalendar;
  final void Function(Challenge task)? onOpenTask;

  static List<Challenge> _visibleTasks() {
    return appState.challenges
        .where((c) {
          if (c.completed) return false;
          final s = c.status.toLowerCase();
          return s != 'cancelled' && s != 'canceled' && s != 'declined';
        })
        .take(3)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _visibleTasks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.event_available_outlined, size: 20, color: kAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'My Tasks',
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                )),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: dashText(const TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          _HomeEmptyTasksCard(onViewCalendar: onViewCalendar)
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HomeTaskRow(
                task: task,
                onTap: onOpenTask != null ? () => onOpenTask!(task) : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeEmptyTasksCard extends StatelessWidget {
  const _HomeEmptyTasksCard({this.onViewCalendar});

  final VoidCallback? onViewCalendar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 28, color: kAccent.withValues(alpha: 0.65)),
          const SizedBox(height: 8),
          Text(
            'No tasks assigned yet',
            style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Documentation assignments from ACCESS will appear here.',
            textAlign: TextAlign.center,
            style: memberDashboardBodyStyle.copyWith(fontSize: 12),
          ),
          if (onViewCalendar != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onViewCalendar,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('View Calendar'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeTaskRow extends StatelessWidget {
  const _HomeTaskRow({
    required this.task,
    this.onTap,
  });

  final Challenge task;
  final VoidCallback? onTap;

  static ({IconData icon, Color color, Color bg}) _taskVisual(Challenge task) {
    final role = (task.taskRole ?? '').toLowerCase();
    if (role.contains('video')) {
      return (icon: Icons.videocam_outlined, color: kAccent, bg: kBlueDim);
    }
    if (role.contains('photo')) {
      return (icon: Icons.photo_camera_outlined, color: kDashStatPurpleIcon, bg: kDashStatPurple);
    }
    return (icon: Icons.collections_outlined, color: kGreen, bg: kGreenDim);
  }

  static ({String label, Color color, Color bg}) _statusVisual(String status) {
    final s = status.toLowerCase();
    if (s == 'pending_acceptance' || s == 'assigned') {
      return (label: 'Pending', color: kYellow, bg: kYellowDim);
    }
    if (s == 'in_progress') {
      return (label: 'In Review', color: kAccent, bg: kBlueDim);
    }
    if (s == 'accepted' || s == 'completed' || s == 'done') {
      return (label: 'Approved', color: kGreen, bg: kGreenDim);
    }
    return (label: status, color: kTextSecondary, bg: kSurfaceAlt);
  }

  String _taskTitle(Challenge task) {
    final role = formatTaskRole(task.taskRole ?? 'member');
    if (role == 'Photographer') return 'Cover Photo Editing';
    if (role == 'Videographer') return 'Event Video Coverage';
    return '$role Coverage';
  }

  @override
  Widget build(BuildContext context) {
    final visual = _taskVisual(task);
    final status = _statusVisual(task.status);

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
              );
            },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: visual.bg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _taskTitle(task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardBodyStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.label,
                    style: dashText(TextStyle(
                      color: status.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recent Uploads ────────────────────────────────────────────────────────────

class _HomeRecentUploadsSection extends StatelessWidget {
  const _HomeRecentUploadsSection({
    this.onViewEventGallery,
    this.onViewPortfolio,
  });

  final VoidCallback? onViewEventGallery;
  final VoidCallback? onViewPortfolio;

  static const _tileWidth = 118.0;
  static const _tileHeight = 152.0;
  static const _maxRecent = 12;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final recent = appState.gallery.take(_maxRecent).toList();
        final isLoading =
            memberDataController.evaluationsTabLoading && recent.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 20, color: kGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent Uploads',
                    style: dashText(const TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    )),
                  ),
                ),
                TextButton(
                  onPressed: onViewPortfolio,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Evaluation',
                    style: dashText(const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              SizedBox(
                height: _tileHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => const SizedBox(
                    width: _tileWidth,
                    child: _HomeUploadSkeletonTile(),
                  ),
                ),
              )
            else if (recent.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 28, color: kAccent.withValues(alpha: 0.65)),
                    const SizedBox(height: 8),
                    Text(
                      'No practice uploads yet',
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Run an AI evaluation to build your portfolio.',
                      textAlign: TextAlign.center,
                      style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                    ),
                    if (onViewPortfolio != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onViewPortfolio,
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const Text('Start Evaluation'),
                          style: FilledButton.styleFrom(
                            backgroundColor: kAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              SizedBox(
                height: _tileHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final item = recent[index];
                    return SizedBox(
                      width: _tileWidth,
                      child: _HomeUploadTile(
                        item: item,
                        onTap: () => MemberHomeDashboard._openGalleryItem(
                          context,
                          item,
                          onViewPortfolio: onViewPortfolio,
                          onViewEventGallery: onViewEventGallery,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeUploadTile extends StatelessWidget {
  const _HomeUploadTile({
    required this.item,
    this.onTap,
  });

  final GalleryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eventName = eventNameForUpload(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _HomeUploadImage(item: item),
                    if (item.isVideo)
                      Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: memberDashboardCardTitleStyle.copyWith(fontSize: 11),
            ),
            Text(
              item.date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: memberDashboardMetaStyle.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeUploadSkeletonTile extends StatelessWidget {
  const _HomeUploadSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kBorder.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: kBorder.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: 48,
          decoration: BoxDecoration(
            color: kBorder.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _HomeUploadImage extends StatelessWidget {
  const _HomeUploadImage({required this.item});

  final GalleryItem item;

  @override
  Widget build(BuildContext context) {
    return GalleryMediaThumbnail(
      url: item.networkUrl,
      isVideo: item.isVideo,
      memoryBytes: item.imageBytes,
      fallbackIconColor: item.color,
      fallbackIconSize: 24,
    );
  }
}

// ── Media evaluation callout ──────────────────────────────────────────────────

class _HomeAiEvaluationCard extends StatelessWidget {
  const _HomeAiEvaluationCard({this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kCyan.withValues(alpha: 0.14),
            kAccent.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCyan.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.auto_awesome_outlined, color: kAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Evaluation',
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get instant feedback on your media quality.',
                  style: memberDashboardBodyStyle.copyWith(fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: kDashStatPurpleIcon,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: dashText(const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              )),
            ),
            child: const Text('Evaluate Media'),
          ),
        ],
      ),
    );
  }
}

// ── Announcements ─────────────────────────────────────────────────────────────

class _HomeAnnouncementsSection extends StatelessWidget {
  const _HomeAnnouncementsSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final items = appState.announcements.take(2).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined, size: 20, color: kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Announcements',
                    style: dashText(const TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    )),
                  ),
                ),
                TextButton(
                  onPressed: () => showAllAnnouncementsSheet(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: dashText(const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: kBorder.withValues(alpha: 0.8)),
                    _HomeAnnouncementRow(announcement: items[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeAnnouncementRow extends StatelessWidget {
  const _HomeAnnouncementRow({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showAnnouncementDetailSheet(context, announcement),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_outlined, color: kAccent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(announcement.date, style: memberDashboardMetaStyle.copyWith(fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(
                      announcement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      announcement.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardBodyStyle.copyWith(fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: kTextSecondary.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skill / XP progress ───────────────────────────────────────────────────────

class _HomeSkillProgressSection extends StatelessWidget {
  const _HomeSkillProgressSection({this.onViewRankings});

  final VoidCallback? onViewRankings;

  static String _formatXp(int value) {
    final s = value.abs().toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final snapshot = MemberCompetencySnapshot.fromAppState();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 20, color: kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Skill Progress',
                    style: dashText(const TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    )),
                  ),
                ),
                if (onViewRankings != null)
                  TextButton(
                    onPressed: onViewRankings,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Rankings',
                      style: dashText(const TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onViewRankings,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.levelName,
                                  style: memberDashboardCardTitleStyle.copyWith(
                                    fontSize: 18,
                                    color: kAccent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatXp(snapshot.points)} XP',
                                  style: memberDashboardMetaStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: kTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: kTextSecondary.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                      if (snapshot.progressUsesSkillScore) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 8,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(color: kBorder.withValues(alpha: 0.45)),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: snapshot.progress.clamp(0.0, 1.0),
                                  child: const ColoredBox(color: kAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        snapshot.progressSubtitle,
                        style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemberGettingStartedCard extends StatelessWidget {
  const _MemberGettingStartedCard({
    required this.onStartPractice,
    required this.onViewAssignments,
  });

  final VoidCallback? onStartPractice;
  final VoidCallback onViewAssignments;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      showAccentStrip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to ACCESS', style: memberDashboardCardTitleStyle.copyWith(fontSize: 17)),
          const SizedBox(height: 6),
          Text(
            'Your account is active. When admins assign events they appear under My Tasks. '
            'You can start building your portfolio with a practice photo or video evaluation anytime.',
            style: memberDashboardBodyStyle.copyWith(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (onStartPractice != null)
            FilledButton.icon(
              onPressed: onStartPractice,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text('Start practice evaluation'),
              style: FilledButton.styleFrom(
                backgroundColor: kMemberPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onViewAssignments,
            child: const Text('View My Assignments'),
          ),
        ],
      ),
    );
  }
}
