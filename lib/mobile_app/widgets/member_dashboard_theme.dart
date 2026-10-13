import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

// ── ACCESS VisionCheck member UI palette ─────────────────────────────────────
// Primary blue  → buttons, active nav, selected states ([kMemberPrimary] / kAccent)
// ACCESS cyan   → branding, icons, highlights, section accents
// See also shared [theme.dart] for semantic success / warning / danger tokens.

const kMemberPrimary = kAccent;
const kMemberCyan = kCyan;
const kMemberDashboardAccent = kMemberCyan;
const kMemberDashboardAccentLight = kCyanDim;
const kMemberDashboardTitle = kTextPrimary;
const kMemberDashboardBg = kBg;
const kDashTextPrimary = kTextPrimary;
const kDashTextSecondary = kTextSecondary;
const kDashBorder = kBorder;
const kDashCardBg = kSurface;

const kDashAccentAnnouncements = kCyanDim;
const kDashAccentCompetency = Color(0xFFEEF3FF);
const kDashAccentCompetencyIcon = kMemberPrimary;
const kDashAccentUploads = kGreenDim;
const kDashAccentUploadsIcon = kGreen;
const kDashAccentFeedback = kYellowDim;
const kDashAccentFeedbackIcon = kYellow;

const kDashStatBlue = kBlueDim;
const kDashStatBlueIcon = kMemberPrimary;
const kDashStatCyan = kCyanDim;
const kDashStatCyanIcon = kMemberCyan;
const kDashStatPurple = Color(0xFFF5F3FF);
const kDashStatPurpleIcon = Color(0xFF8B5CF6);
const kDashStatGreen = kGreenDim;
const kDashStatGreenIcon = kGreen;

/// Semantic icon-tile colors for [AccessStatCard] (white card body — matches admin-web stat rows).
const kStatIconPrimary = kMemberPrimary;
const kStatIconMedia = kMemberCyan;
const kStatIconSuccess = kGreen;
const kStatIconWarning = kYellow;
const kStatIconDanger = kRed;
const kStatIconPurple = kDashStatPurpleIcon;
const kStatIconNeutral = kTextSecondary;

// ── Layout ────────────────────────────────────────────────────────────────────

const kMemberDashboardPagePadding = 22.0;
const kMemberDashboardCardRadius = 20.0;
const kMemberDashboardInnerRadius = 16.0;
const kMemberDashboardIconRadius = 14.0;
const kMemberDashboardButtonRadius = 14.0;
const kMemberDashboardSectionGap = 26.0;
const kMemberDashboardSectionTitleGap = 14.0;
const kMemberDashboardCardPadding = 20.0;

/// Dark hero shell (home dashboard, calendar mini-hero).
const kMemberDarkHeroBottomRadius = 28.0;
const kMemberDarkHeroMiniBottomRadius = 20.0;

/// Member profile pinned hero: slight bottom curve (tighter than mini-hero 20px).
const kMemberProfileHeroBottomRadius = 8.0;

const kMemberDarkHeroGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF050C1C),
    Color(0xFF0A1628),
    Color(0xFF0F2744),
  ],
  stops: [0.0, 0.55, 1.0],
);

/// Cyan → indigo → purple (ACCESS logo palette). Home featured event card, profile stats.
const kMemberBrandAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kCyan,
    Color(0xFF6366F1),
    kDashStatPurpleIcon,
  ],
);

const Duration kMemberDashboardAnimDuration = Duration(milliseconds: 500);
const Duration kMemberDashboardAnimStagger = Duration(milliseconds: 65);

TextStyle dashText(TextStyle base) => GoogleFonts.inter(textStyle: base);

TextStyle get memberDashboardSectionTitleStyle => dashText(const TextStyle(
      color: kDashTextPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.2,
    ));

TextStyle get memberDashboardSectionSubtitleStyle => dashText(const TextStyle(
      color: kDashTextSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ));

TextStyle get memberDashboardCardTitleStyle => dashText(const TextStyle(
      color: kDashTextPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ));

TextStyle get memberDashboardBodyStyle => dashText(const TextStyle(
      color: kDashTextSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ));

TextStyle get memberDashboardMetaStyle => dashText(const TextStyle(
      color: kDashTextSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ));

LinearGradient get kMemberDashboardAccentGradient => LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        kMemberCyan.withValues(alpha: 0.95),
        kMemberPrimary,
      ],
    );

List<BoxShadow> memberDashboardCardShadows({Color? tint}) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: (tint ?? kMemberCyan).withValues(alpha: 0.05),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];

BoxDecoration memberDashboardCardDecoration({
  Color? backgroundColor,
  Color? borderColor,
  List<BoxShadow>? shadows,
}) {
  return BoxDecoration(
    color: backgroundColor ?? kDashCardBg,
    borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
    border: Border.all(
      color: borderColor ?? kMemberCyan.withValues(alpha: 0.12),
    ),
    boxShadow: shadows ?? memberDashboardCardShadows(),
  );
}

/// Inner panel surface inside hero / welcome cards.
BoxDecoration memberDashboardInnerPanelDecoration() {
  return BoxDecoration(
    color: kSurfaceAlt,
    borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
    border: Border.all(color: kMemberCyan.withValues(alpha: 0.10)),
  );
}

/// Small rounded icon tile for dashboard list rows.
class MemberDashboardIconTile extends StatelessWidget {
  const MemberDashboardIconTile({
    super.key,
    required this.icon,
    this.size = 38,
    this.iconSize = 20,
    this.color,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? kMemberCyan;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Icon(icon, size: iconSize, color: accent),
    );
  }
}

// ── Dashboard helpers ─────────────────────────────────────────────────────────

String memberDashboardGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String memberDashboardName() {
  final fromProfile = appState.profileName.trim();
  if (fromProfile.isNotEmpty) return fromProfile;
  final fromAuth = authController.user?.name.trim() ?? '';
  if (fromAuth.isNotEmpty) return fromAuth;
  if (authController.user?.role == AccessRole.organization) return 'Requestor';
  return 'Member';
}

String memberDashboardFirstName() {
  final full = memberDashboardName().trim();
  if (full.isEmpty) return 'Member';
  return full.split(RegExp(r'\s+')).first;
}

/// Name shown after "Good Morning," — full org name for requestors, first name for members.
String memberDashboardGreetingName() {
  final full = memberDashboardName().trim();
  if (full.isEmpty) return 'there';
  if (authController.user?.role == AccessRole.organization) return full;
  if (full == 'Member' || full == 'Requestor') return full;
  final first = full.split(RegExp(r'\s+')).first;
  return first.isNotEmpty ? first : full;
}

String memberDashboardRole({Challenge? assignment}) {
  final role = assignment?.taskRole?.trim();
  if (role != null && role.isNotEmpty) return formatTaskRole(role);
  return 'Documentation Member';
}

String formatTaskRole(String role) {
  final r = role.toLowerCase();
  if (r.contains('video')) return 'Videographer';
  if (r.contains('photo')) return 'Photographer';
  return role[0].toUpperCase() + role.substring(1);
}

String memberDashboardCompetencyLevel() {
  final skill = appState.profileSkillLevel?.trim();
  if (skill != null && skill.isNotEmpty) return skill;
  return 'Beginner';
}

Challenge? memberActiveAssignment() {
  Challenge? accepted;
  for (final task in appState.challenges) {
    if (task.completed) continue;
    final status = task.status.toLowerCase();
    if (status == 'cancelled' || status == 'canceled' || status == 'declined') continue;
    if (status == 'pending_acceptance' || status == 'assigned') return task;
    if (status == 'accepted' || status == 'in_progress') {
      accepted ??= task;
    }
  }
  return accepted;
}

CalendarEvent? calendarEventForAssignment(Challenge assignment) {
  final requestId = assignment.requestId;
  if (requestId != null) {
    for (final event in appState.events) {
      if (event.requestId == requestId) return event;
    }
  }
  for (final event in appState.events) {
    if (event.title == assignment.title) return event;
  }
  return null;
}

Challenge? memberAssignmentForEvent(CalendarEvent event) {
  final requestId = event.requestId;
  if (requestId != null) {
    for (final task in appState.challenges) {
      if (task.requestId == requestId) return task;
    }
  }
  for (final task in appState.challenges) {
    if (task.title == event.title) return task;
  }
  return null;
}

/// True when this event matches an active documentation task for the logged-in member.
bool memberHasActiveTaskForEvent(CalendarEvent event) {
  final requestId = event.requestId;
  for (final task in appState.challenges) {
    final status = task.status.toLowerCase();
    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'declined' ||
        status == 'completed' ||
        status == 'done') {
      continue;
    }
    if (requestId != null && task.requestId == requestId) return true;
    if (task.title.trim().toLowerCase() == event.title.trim().toLowerCase()) {
      return true;
    }
  }
  return false;
}

/// True when this campus calendar row belongs to the logged-in requestor's service request.
bool requestorOwnsCalendarEvent(CalendarEvent event) {
  final requestId = event.requestId;
  if (requestId == null) return false;
  return appState.serviceRequests.any((r) => r.requestId == requestId);
}

/// True when this calendar event matches one of the member's active assignments.
bool memberIsAssignedToEvent(CalendarEvent event) {
  final requestId = event.requestId;
  if (requestId != null) {
    for (final task in appState.challenges) {
      if (task.requestId != requestId && task.title != event.title) continue;
      final status = task.status.toLowerCase();
      if (status == 'cancelled' ||
          status == 'canceled' ||
          status == 'declined' ||
          status == 'completed' ||
          status == 'done') {
        continue;
      }
      return true;
    }
  }

  final memberName = memberDashboardFirstName().toLowerCase();
  final fullName = authController.user?.name.trim().toLowerCase() ?? '';
  for (final name in [
    ...event.documentationTeam,
    if (event.assignedMemberName != null) event.assignedMemberName!,
  ]) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) continue;
    if (fullName.isNotEmpty && (n.contains(fullName) || fullName.contains(n))) return true;
    if (memberName.isNotEmpty && (n.contains(memberName) || fullName.startsWith(memberName))) {
      return true;
    }
  }
  return false;
}

String eventNameForUpload(GalleryItem item) {
  if (item.requestId != null) {
    for (final task in appState.challenges) {
      if (task.requestId == item.requestId && task.title.isNotEmpty) {
        return task.title;
      }
    }
    for (final event in appState.events) {
      if (event.requestId == item.requestId && event.title.isNotEmpty) {
        return event.title;
      }
    }
  }
  if (item.category == 'Practice') return 'Practice Upload';
  if (item.category.isNotEmpty) return item.category;
  return 'Event Coverage';
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class MemberDashboardFadeSlide extends StatefulWidget {
  const MemberDashboardFadeSlide({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<MemberDashboardFadeSlide> createState() => _MemberDashboardFadeSlideState();
}

class _MemberDashboardFadeSlideState extends State<MemberDashboardFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kMemberDashboardAnimDuration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(kMemberDashboardAnimStagger * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class MemberDashboardTapScale extends StatefulWidget {
  const MemberDashboardTapScale({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<MemberDashboardTapScale> createState() => _MemberDashboardTapScaleState();
}

class _MemberDashboardTapScaleState extends State<MemberDashboardTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class MemberDashboardSection extends StatelessWidget {
  const MemberDashboardSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.topPadding = kMemberDashboardSectionGap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        topPadding,
        kMemberDashboardPagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: memberDashboardSectionTitleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: memberDashboardSectionSubtitleStyle),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: kMemberDashboardSectionTitleGap),
          child,
        ],
      ),
    );
  }
}

class MemberDashboardCard extends StatelessWidget {
  const MemberDashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(kMemberDashboardCardPadding),
    this.showAccentStrip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showAccentStrip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: memberDashboardCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAccentStrip)
              Container(
                height: 3,
                color: kMemberCyan,
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class MemberDashboardChip extends StatelessWidget {
  const MemberDashboardChip({
    super.key,
    required this.icon,
    required this.label,
    this.accent = kMemberDashboardAccent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: dashText(TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }
}

class MemberDashboardPrimaryButton extends StatelessWidget {
  const MemberDashboardPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = kMemberPrimary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(kMobileMinTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
          ),
          textStyle: dashText(const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ),
    );
  }
}

class MemberDashboardTextButton extends StatelessWidget {
  const MemberDashboardTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: kMemberPrimary,
        textStyle: dashText(const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      child: Text(label),
    );
  }
}

class MemberDashboardMetaRow extends StatelessWidget {
  const MemberDashboardMetaRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor ?? kDashTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: memberDashboardMetaStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class MemberDashboardEmptyState extends StatelessWidget {
  const MemberDashboardEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final String message;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? kMemberDashboardAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: memberDashboardCardDecoration(
        backgroundColor: backgroundColor ?? kDashCardBg,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: memberDashboardBodyStyle.copyWith(fontSize: 13, color: kDashTextSecondary),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder while dashboard data loads.
class MemberDashboardSkeleton extends StatelessWidget {
  const MemberDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        16,
        kMemberDashboardPagePadding,
        0,
      ),
      child: Column(
        children: [
          _bone(height: 120, radius: kMemberDashboardCardRadius),
          const SizedBox(height: 20),
          _bone(height: 180, radius: kMemberDashboardCardRadius),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _bone(height: 100, radius: 16)),
              const SizedBox(width: 12),
              Expanded(child: _bone(height: 100, radius: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bone({required double height, required double radius}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: kDashBorder.withValues(alpha: 0.45),
      ),
    );
  }
}

/// Notification bell for dark mini-hero headers (matches Home hero styling).
class MemberDarkHeroNotificationButton extends StatelessWidget {
  const MemberDarkHeroNotificationButton({super.key, this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  static const _buttonSize = 40.0;

  double get _touchSize => compact ? 40.0 : kMobileMinTouch;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final badgeCount = appState.unreadCount;
        final icon = badgeCount > 0
            ? Icons.notifications_rounded
            : Icons.notifications_outlined;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _touchSize,
              height: _touchSize,
              child: ClipRect(
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: compact ? 34 : _buttonSize,
                        height: compact ? 34 : _buttonSize,
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
                          size: compact ? 20 : 24,
                        ),
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          top: compact ? 2 : 4,
                          right: compact ? 2 : 4,
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: compact ? 13 : 14,
                              minHeight: compact ? 13 : 14,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: kDashStatPurpleIcon,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF050C1C), width: 1.2),
                            ),
                            child: Center(
                              child: Text(
                                badgeCount > 9 ? '9+' : '$badgeCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 7 : 8,
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
          ),
        );
      },
    );
  }
}

/// Notification bell for light page backgrounds (Evaluations, Feedback).
class MemberPageNotificationButton extends StatelessWidget {
  const MemberPageNotificationButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final badgeCount = appState.unreadCount;
        final size = compact ? 36.0 : 38.0;

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
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: kMemberPrimary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(color: kMemberPrimary.withValues(alpha: 0.22)),
                      ),
                      child: Icon(
                        badgeCount > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        size: compact ? 19 : 20,
                        color: badgeCount > 0 ? kMemberPrimary : kIconInactive,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: kRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: kSurface, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 9 ? '9+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
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
      },
    );
  }
}

String memberDisplayInitials(String name) {
  final n = name.trim();
  if (n.isEmpty) return '?';
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return n[0].toUpperCase();
}

class _MemberProfileInitialsBadge extends StatelessWidget {
  const _MemberProfileInitialsBadge({
    required this.initials,
    this.dark = false,
  });

  final String initials;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark
          ? kCyan.withValues(alpha: 0.2)
          : kMemberPrimary.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: dark ? Colors.white : kMemberPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Profile avatar for light page headers (Evaluations, Feedback).
class MemberPageProfileAvatar extends StatelessWidget {
  const MemberPageProfileAvatar({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final size = compact ? 36.0 : 38.0;

    return ListenableBuilder(
      listenable: Listenable.merge([appState, authController]),
      builder: (context, _) {
        final displayName = appState.profileName.trim().isNotEmpty
            ? appState.profileName
            : (authController.user?.name ?? '');
        final initials = memberDisplayInitials(displayName);
        final imageUrl = appState.profileImageUrl;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kMobileMinTouch,
              height: kMobileMinTouch,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kMemberPrimary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: size,
                            height: size,
                            errorBuilder: (_, __, ___) =>
                                _MemberProfileInitialsBadge(initials: initials),
                          )
                        : _MemberProfileInitialsBadge(initials: initials),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Profile avatar for dark mini-hero headers (Home, Calendar, Gallery, Rankings).
class MemberDarkHeroProfileAvatar extends StatelessWidget {
  const MemberDarkHeroProfileAvatar({super.key, this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  double get _avatarSize => compact ? 34.0 : 38.0;
  double get _touchSize => compact ? 40.0 : kMobileMinTouch;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, authController]),
      builder: (context, _) {
        final displayName = appState.profileName.trim().isNotEmpty
            ? appState.profileName
            : (authController.user?.name ?? '');
        final initials = memberDisplayInitials(displayName);
        final imageUrl = appState.profileImageUrl;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _touchSize,
              height: _touchSize,
              child: ClipRect(
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: _avatarSize,
                                  height: _avatarSize,
                                  errorBuilder: (_, __, ___) =>
                                      _MemberProfileInitialsBadge(
                                    initials: initials,
                                    dark: true,
                                  ),
                                )
                              : _MemberProfileInitialsBadge(
                                  initials: initials,
                                  dark: true,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: compact ? 0 : 2,
                        right: compact ? 0 : 2,
                        child: Container(
                          width: compact ? 8 : 9,
                          height: compact ? 8 : 9,
                          decoration: BoxDecoration(
                            color: kGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF050C1C),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
