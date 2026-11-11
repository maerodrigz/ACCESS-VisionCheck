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
const _kHomeNavy = Color(0xFF103E56);
const _kHomeMuted = Color(0xFF617F91);
const _kHomeCardBorder = Color(0xFFD0EBF5);
const _kHomeCardRadius = 15.0;
const _kSectionGap = 12.0;
const _kHomeCameraAsset = 'assets/images/requestor_greeting_illustration.png';

/// Member home — transparent brand bar + Phase 2 upper content over global sky bg.
class MemberHomeDashboard extends StatelessWidget {
  const MemberHomeDashboard({
    super.key,
    this.isSyncing = false,
    this.userName = '',
    this.onLogout,
    this.onViewPortfolio,
    this.onViewAllRecentUploads,
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
  /// Recent Uploads → View All → Media Evaluation / All Evaluations.
  final VoidCallback? onViewAllRecentUploads;
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
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final assignment = memberNextAssignment();
        final taskCount = _activeTaskCount();
        final uploads = _uploadCount();
        final aiScore = _aiQualityScore();

        return ColoredBox(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSyncing)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: kCyan,
                  backgroundColor: Color(0xFF1E293B),
                ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPad,
                    0,
                    _horizontalPad,
                    4,
                  ),
                  child: _HomeTopBar(
                    userName: userName,
                    onNotifications: onViewNotifications,
                    onProfileTap: onProfileTap,
                  ),
                ),
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
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      28,
                    ),
                    children: [
                      _HomeUpperContent(
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _horizontalPad,
                          12,
                          _horizontalPad,
                          0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_shouldShowGettingStarted())
                              _MemberGettingStartedCard(
                                onStartPractice: onViewPortfolio,
                                onViewAssignments: () => _openAllTasks(context),
                              ),
                            if (_shouldShowGettingStarted())
                              const SizedBox(height: _kSectionGap),
                            _HomeMyTasksSection(
                              onViewAll: () => _openAllTasks(context),
                              onViewCalendar: onViewCalendar,
                              onOpenTask: (task) => _openTask(context, task),
                            ),
                            const SizedBox(height: _kSectionGap),
                            _HomeRecentUploadsSection(
                              onViewEventGallery: onViewEventGallery,
                              onViewPortfolio: onViewPortfolio,
                              onViewAllRecentUploads: onViewAllRecentUploads,
                            ),
                            const SizedBox(height: _kSectionGap),
                            _HomeAiEvaluationCard(onOpen: onViewPortfolio),
                            const SizedBox(height: _kSectionGap),
                            _HomeSkillFeedbackPair(
                              onViewRankings: onViewRankings,
                              onViewAllFeedback: onViewAllRequestorFeedback,
                            ),
                            const SizedBox(height: _kSectionGap),
                            const _HomeAnnouncementsSection(),
                          ],
                        ),
                      ),
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

// ── Phase 2 upper content (greeting / camera / assignment / stats) ────────────

class _HomeUpperContent extends StatelessWidget {
  const _HomeUpperContent({
    this.assignment,
    required this.taskCount,
    required this.uploadCount,
    required this.aiScore,
    this.onEventTap,
    this.onTasksTap,
    this.onUploadsTap,
    this.onAiScoreTap,
  });

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
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPad,
        narrow ? 4 : 6,
        _horizontalPad,
        narrow ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeGreetingRow(narrow: narrow),
          SizedBox(height: narrow ? 10 : 12),
          _HomeNextAssignmentCard(
            assignment: assignment,
            onTap: onEventTap,
          ),
          SizedBox(height: narrow ? 8 : 10),
          _HomeCompactStatsRow(
            taskCount: taskCount,
            uploadCount: uploadCount,
            aiScore: aiScore,
            onTasksTap: onTasksTap,
            onUploadsTap: onUploadsTap,
            onAiScoreTap: onAiScoreTap,
          ),
        ],
      ),
    );
  }
}

class _HomeGreetingRow extends StatelessWidget {
  const _HomeGreetingRow({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final cameraWidth = narrow ? 92.0 : 108.0;
    final cameraHeight = narrow ? 72.0 : 84.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${memberDashboardGreeting()}, ${memberDashboardFirstName()}!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: _kHomeNavy,
                  fontSize: narrow ? 20 : 22,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.3,
                )),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s your documentation overview.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: _kHomeMuted,
                  fontSize: narrow ? 12.5 : 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                )),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: cameraWidth,
          height: cameraHeight,
          child: Image.asset(
            _kHomeCameraAsset,
            fit: BoxFit.contain,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        ),
      ],
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
              child: AccessBrandLockup(
                markSize: 38,
                compact: true,
                lightBackground: true,
              ),
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
                    color: kCyan.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kCyan.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: badgeCount > 0
                        ? kTextPrimary
                        : kTextSecondary,
                    size: 22,
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
                        color: const Color(0xFF139CD9),
                        shape: BoxShape.circle,
                        border: Border.all(color: kSurface, width: 1.2),
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
                    border: Border.all(
                      color: kCyan.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            width: _avatarSize,
                            height: _avatarSize,
                            errorBuilder: (_, __, ___) =>
                                _InitialsBadge(initials: initials),
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
                      border: Border.all(color: kSurface, width: 1.4),
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
      color: kCyan.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HomeNextAssignmentCard extends StatelessWidget {
  const _HomeNextAssignmentCard({
    this.assignment,
    this.onTap,
  });

  final Challenge? assignment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final hasEvent = assignment != null;
    final statusBadge = hasEvent
        ? memberAssignmentStatusBadge(assignment!.status)
        : null;
    final date = hasEvent ? (assignment!.eventDate?.trim() ?? '') : '';
    final time = hasEvent
        ? (assignment!.eventTimeRange?.trim().isNotEmpty == true
            ? assignment!.eventTimeRange!.trim()
            : (assignment!.eventTime?.trim() ?? ''))
        : '';
    final venue = hasEvent ? (assignment!.venue?.trim() ?? '') : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            border: Border.all(color: _kHomeCardBorder),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 11 : 12,
              narrow ? 9 : 10,
              narrow ? 6 : 8,
              narrow ? 9 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kCyan.withValues(alpha: 0.22)),
                  ),
                  child: Icon(
                    hasEvent
                        ? Icons.calendar_today_outlined
                        : Icons.event_available_outlined,
                    color: kCyan,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Next Assignment',
                        style: dashText(const TextStyle(
                          color: _kHomeMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        )),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasEvent
                            ? assignment!.title
                            : 'No upcoming assignment',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: _kHomeNavy,
                          fontSize: narrow ? 13.5 : 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        )),
                      ),
                      if (hasEvent) ...[
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dashText(const TextStyle(
                              color: _kHomeMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            )),
                          ),
                        ],
                        if (time.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dashText(const TextStyle(
                              color: _kHomeMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            )),
                          ),
                        ],
                        if (venue.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dashText(const TextStyle(
                              color: _kHomeMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            )),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 3),
                        Text(
                          'Check the calendar for new documentation tasks.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(const TextStyle(
                            color: _kHomeMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          )),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (statusBadge != null)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 84),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBadge.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusBadge.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(TextStyle(
                            color: statusBadge.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          )),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _kHomeMuted.withValues(alpha: 0.85),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCompactStatsRow extends StatelessWidget {
  const _HomeCompactStatsRow({
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HomeCompactStatCard(
              icon: Icons.assignment_outlined,
              value: '$taskCount',
              label: 'My Tasks',
              onTap: onTasksTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HomeCompactStatCard(
              icon: Icons.photo_outlined,
              value: '$uploadCount',
              label: 'Uploads',
              onTap: onUploadsTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HomeCompactStatCard(
              icon: Icons.star_outline_rounded,
              value: aiScore,
              label: 'Avg. Quality',
              onTap: onAiScoreTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCompactStatCard extends StatelessWidget {
  const _HomeCompactStatCard({
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
    final narrow = MediaQuery.sizeOf(context).width < 360;

    final child = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 8 : 9,
        vertical: narrow ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        border: Border.all(color: _kHomeCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: narrow ? 16 : 17, color: kCyan),
          SizedBox(height: narrow ? 6 : 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: dashText(TextStyle(
                color: _kHomeNavy,
                fontSize: narrow ? 20 : 21,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.3,
              )),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(TextStyle(
              color: _kHomeMuted,
              fontSize: narrow ? 11 : 11.5,
              fontWeight: FontWeight.w500,
              height: 1.15,
            )),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
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
            const Icon(Icons.event_available_outlined, size: 18, color: kCyan),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'My Tasks',
                style: dashText(const TextStyle(
                  color: _kHomeNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                )),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: dashText(const TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          _HomeEmptyTasksCard(onViewCalendar: onViewCalendar)
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                  backgroundColor: kMemberButtonPrimary,
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

  String _taskSubtitle(Challenge task) {
    final role = memberDashboardRole(assignment: task);
    final schedule = memberAssignmentScheduleLine(task);
    if (schedule != 'Schedule TBA') return '$role · $schedule';
    return role;
  }

  @override
  Widget build(BuildContext context) {
    final visual = _taskVisual(task);
    final status = memberAssignmentStatusBadge(task.status);

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(_kHomeCardRadius),
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
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            border: Border.all(color: _kHomeCardBorder),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: visual.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 17),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _taskSubtitle(task),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardBodyStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: status.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: dashText(TextStyle(
                        color: status.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Phase 5: Recent Uploads + Media Evaluation CTA ────────────────────────────

class _HomeRecentUploadsSection extends StatelessWidget {
  const _HomeRecentUploadsSection({
    this.onViewEventGallery,
    this.onViewPortfolio,
    this.onViewAllRecentUploads,
  });

  final VoidCallback? onViewEventGallery;
  final VoidCallback? onViewPortfolio;
  final VoidCallback? onViewAllRecentUploads;

  static const _maxRecent = 12;
  static const _viewportThumbs = 3;
  static const _thumbGap = 8.0;
  static const _thumbRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final recent = appState.gallery.take(_maxRecent).toList();
        final isLoading =
            memberDataController.evaluationsTabLoading && recent.isEmpty;
        // Practice uploads belong on Media Evaluation → All Evaluations (not Gallery).
        final viewAll =
            onViewAllRecentUploads ?? onViewPortfolio ?? onViewEventGallery;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            border: Border.all(color: _kHomeCardBorder),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 17, color: kCyan),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recent Uploads',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(const TextStyle(
                        color: _kHomeNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      )),
                    ),
                  ),
                  if (viewAll != null)
                    TextButton(
                      onPressed: viewAll,
                      style: TextButton.styleFrom(
                        foregroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(40, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style: dashText(const TextStyle(
                          color: kAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        )),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (isLoading)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final thumb = _thumbSizeFor(constraints.maxWidth);
                    return SizedBox(
                      height: thumb,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _viewportThumbs,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: _thumbGap),
                        itemBuilder: (_, __) =>
                            _HomeUploadSkeletonTile(size: thumb),
                      ),
                    );
                  },
                )
              else if (recent.isEmpty)
                const _HomeEmptyUploadsBody()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final thumb = _thumbSizeFor(constraints.maxWidth);
                    return SizedBox(
                      height: thumb,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: recent.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: _thumbGap),
                        itemBuilder: (_, index) {
                          final item = recent[index];
                          return _HomeUploadTile(
                            item: item,
                            size: thumb,
                            onTap: () => MemberHomeDashboard._openGalleryItem(
                              context,
                              item,
                              onViewPortfolio: onViewPortfolio,
                              onViewEventGallery: onViewEventGallery,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Fit about [_viewportThumbs] squares in the card width on X695-class phones.
  static double _thumbSizeFor(double maxWidth) {
    final raw =
        (maxWidth - _thumbGap * (_viewportThumbs - 1)) / _viewportThumbs;
    return raw.clamp(78.0, 100.0);
  }
}

class _HomeEmptyUploadsBody extends StatelessWidget {
  const _HomeEmptyUploadsBody();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.photo_camera_outlined,
          size: 18,
          color: _kHomeMuted.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No practice uploads yet.',
            style: dashText(const TextStyle(
              color: _kHomeMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
            )),
          ),
        ),
      ],
    );
  }
}

class _HomeUploadTile extends StatelessWidget {
  const _HomeUploadTile({
    required this.item,
    required this.size,
    this.onTap,
  });

  final GalleryItem item;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(_HomeRecentUploadsSection._thumbRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(_HomeRecentUploadsSection._thumbRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HomeUploadImage(item: item),
                if (item.isVideo)
                  Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
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

class _HomeUploadSkeletonTile extends StatelessWidget {
  const _HomeUploadSkeletonTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kHomeCardBorder.withValues(alpha: 0.7),
          borderRadius:
              BorderRadius.circular(_HomeRecentUploadsSection._thumbRadius),
        ),
      ),
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
      fallbackIconSize: 22,
    );
  }
}

// ── Media evaluation callout ──────────────────────────────────────────────────

class _HomeAiEvaluationCard extends StatelessWidget {
  const _HomeAiEvaluationCard({this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media Evaluation',
          style: dashText(const TextStyle(
            color: _kHomeNavy,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.15,
          )),
        ),
        const SizedBox(height: 3),
        Text(
          'Check your media quality and get instant feedback.',
          style: dashText(const TextStyle(
            color: _kHomeMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            height: 1.3,
          )),
        ),
      ],
    );

    final action = FilledButton(
      onPressed: onOpen,
      style: FilledButton.styleFrom(
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: narrow ? const Size.fromHeight(38) : Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: dashText(const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        )),
      ),
      child: const Text('Evaluate Media'),
    );

    final icon = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kCyan.withValues(alpha: 0.28)),
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: kCyan, size: 17),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: kCyanDim,
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        border: Border.all(color: kCyan.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 10),
                action,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(child: copy),
                const SizedBox(width: 8),
                action,
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
                const Icon(Icons.campaign_outlined, size: 18, color: kCyan),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Announcements',
                    style: dashText(const TextStyle(
                      color: _kHomeNavy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    )),
                  ),
                ),
                TextButton(
                  onPressed: () => showAllAnnouncementsSheet(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: dashText(const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(_kHomeCardRadius),
                border: Border.all(color: _kHomeCardBorder),
                boxShadow: [
                  BoxShadow(
                    color: kCyan.withValues(alpha: 0.05),
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.campaign_outlined, color: kCyan, size: 15),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(announcement.date, style: memberDashboardMetaStyle.copyWith(fontSize: 10)),
                    const SizedBox(height: 1),
                    Text(
                      announcement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      announcement.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardBodyStyle.copyWith(fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 17, color: kTextSecondary.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skill Progress + Requestor Feedback (stacked full-width cards) ────────────

const _kPairNavy = Color(0xFF103E56);
const _kPairMuted = Color(0xFF617F91);
const _kPairBorder = Color(0xFFD0EBF5);
const _kPairRadius = 15.0;
const _kPairGap = 10.0;

class _HomeSkillFeedbackPair extends StatelessWidget {
  const _HomeSkillFeedbackPair({
    this.onViewRankings,
    this.onViewAllFeedback,
  });

  final VoidCallback? onViewRankings;
  final VoidCallback? onViewAllFeedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSkillProgressCard(onViewRankings: onViewRankings),
        const SizedBox(height: _kPairGap),
        _HomeRequestorFeedbackCard(onViewAll: onViewAllFeedback),
      ],
    );
  }
}

class _HomePairCardShell extends StatelessWidget {
  const _HomePairCardShell({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kPairRadius),
        border: Border.all(color: _kPairBorder),
        boxShadow: [
          BoxShadow(
            color: kCyan.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kPairRadius),
        child: card,
      ),
    );
  }
}

/// Compact title + cyan action that keeps full headings readable in half-width cards.
class _HomePairCardHeader extends StatelessWidget {
  const _HomePairCardHeader({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final showAction = actionLabel != null && onAction != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kCyan),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: dashText(const TextStyle(
                  color: _kPairNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                )),
              ),
            ),
          ],
        ),
        if (showAction)
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 1),
                child: Text(
                  actionLabel!,
                  style: dashText(const TextStyle(
                    color: kAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.1,
                  )),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeSkillProgressCard extends StatelessWidget {
  const _HomeSkillProgressCard({this.onViewRankings});

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

        return _HomePairCardShell(
          onTap: onViewRankings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomePairCardHeader(
                icon: Icons.emoji_events_outlined,
                title: 'Skill Progress',
                actionLabel: onViewRankings == null ? null : 'Rankings',
                onAction: onViewRankings,
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.levelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dashText(const TextStyle(
                  color: kAccent,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                )),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatXp(snapshot.points)} XP',
                style: dashText(const TextStyle(
                  color: _kPairNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                )),
              ),
              if (snapshot.progressUsesSkillScore) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: _kPairBorder.withValues(alpha: 0.7)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: snapshot.progress.clamp(0.0, 1.0),
                          child: const ColoredBox(color: kCyan),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                snapshot.progressSubtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: dashText(const TextStyle(
                  color: _kPairMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.28,
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeRequestorFeedbackCard extends StatelessWidget {
  const _HomeRequestorFeedbackCard({this.onViewAll});

  final VoidCallback? onViewAll;

  bool get _isMemberUser =>
      authController.isLoggedIn &&
      !(authController.user?.role.isOrganization ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_isMemberUser) {
      return _HomePairCardShell(
        child: Text(
          'Requestor feedback is available for documentation members.',
          style: dashText(const TextStyle(
            color: _kPairMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            height: 1.3,
          )),
        ),
      );
    }

    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        final loaded = memberDataController.requestorRatingsLoaded;
        final loadError = memberDataController.requestorRatingsLoadError;
        final loading = !loaded &&
            loadError == null &&
            (memberDataController.isLoading ||
                !memberDataController.profileLoadAttempted);
        final ratings = memberDataController.requestorRatings;
        final hasFeedback =
            loaded && memberDataController.requestorRatingCount > 0 && ratings.isNotEmpty;

        return _HomePairCardShell(
          onTap: onViewAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomePairCardHeader(
                icon: Icons.star_rate_rounded,
                title: 'Requestor Feedback',
                actionLabel: onViewAll == null ? null : 'View All',
                onAction: onViewAll,
              ),
              const SizedBox(height: 8),
              if (loading)
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: kCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Loading…',
                        style: dashText(const TextStyle(
                          color: _kPairMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        )),
                      ),
                    ),
                  ],
                )
              else if (loadError != null && !loaded)
                Text(
                  loadError,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(const TextStyle(
                    color: kRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  )),
                )
              else if (!hasFeedback)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: _kPairMuted.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No requestor feedback yet.',
                        style: dashText(const TextStyle(
                          color: _kPairMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        )),
                      ),
                    ),
                  ],
                )
              else
                _HomeFeedbackPreview(row: ratings.first),
            ],
          ),
        );
      },
    );
  }
}

class _HomeFeedbackPreview extends StatelessWidget {
  const _HomeFeedbackPreview({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final rating = ((row['rating'] as num?)?.toInt() ?? 0).clamp(0, 5);
    final eventTitle = (row['event_title'] as String?)?.trim() ?? '';
    final comment = (row['comment'] as String?)?.trim() ?? '';
    final dateLabel = formatRequestorFeedbackDate(row['created_at'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RequestorFeedbackStarRow(rating: rating, size: 14),
        if (eventTitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            eventTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(const TextStyle(
              color: _kPairNavy,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            )),
          ),
        ],
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            comment,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: dashText(const TextStyle(
              color: _kPairMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
            )),
          ),
        ],
        if (dateLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dashText(TextStyle(
              color: _kPairMuted.withValues(alpha: 0.9),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            )),
          ),
        ],
      ],
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
