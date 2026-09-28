import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_detail_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';

/// Requestor home — overview, quick actions, and recent documentation requests.
class RequestorHomeScreen extends StatelessWidget {
  const RequestorHomeScreen({
    super.key,
    required this.userName,
    required this.onOpenRequestTab,
    required this.onOpenFeedback,
    required this.onViewGallery,
    required this.onViewFeedback,
    required this.onViewCalendar,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final String userName;
  final void Function({RequestStatus? filter}) onOpenRequestTab;
  final void Function({int? requestId}) onOpenFeedback;
  final VoidCallback onViewGallery;
  final void Function({int? requestId}) onViewFeedback;
  final VoidCallback onViewCalendar;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  Future<void> _openCreateForm(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DocumentationRequestFormScreen()),
    );
    if (created == true) {
      await memberDataController.refreshAll();
    }
  }

  void _openDetails(BuildContext context, ServiceRequest req) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          request: req,
          onViewGallery: onViewGallery,
          onViewFeedback: onViewFeedback,
        ),
      ),
    );
  }

  List<ServiceRequest> _recentRequests(List<ServiceRequest> all) {
    final sorted = [...all]
      ..sort((a, b) {
        final ad = a.submissionDate ?? a.eventDate;
        final bd = b.submissionDate ?? b.eventDate;
        return bd.compareTo(ad);
      });
    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: kBg,
        child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final requests = appState.serviceRequests;
          final pending =
              requests.where((r) => r.requestStatus == RequestStatus.pending).length;
          final approved =
              requests.where((r) => r.requestStatus == RequestStatus.approved).length;
          final completed =
              requests.where((r) => r.requestStatus == RequestStatus.completed).length;
          final recent = _recentRequests(requests);
          final displayName = _requestorDisplayName(userName);

          return RefreshIndicator(
            color: kMemberPrimary,
            displacement: 36,
            strokeWidth: 2.5,
            onRefresh: () => memberDataController.refreshAll(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _RequestorHomeDarkHero(
                    displayName: displayName,
                    total: requests.length,
                    pending: pending,
                    approved: approved,
                    onNotifications: onNotificationsTap,
                    onProfileTap: onProfileTap,
                    onOpenRequestTab: onOpenRequestTab,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kMemberDashboardPagePadding,
                    18,
                    kMemberDashboardPagePadding,
                    56,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: EdgeInsets.only(bottom: requests.isEmpty ? 14 : 20),
                        child: _CreateRequestBanner(
                          onTap: () => _openCreateForm(context),
                        ),
                      ),
                      if (requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 22),
                          child: _EmptyRequestsHint(),
                        )
                      else ...[
                        _HomeSectionHeader(
                          title: 'Recent requests',
                          subtitle: completed > 0
                              ? '$completed completed · tap a card for details'
                              : 'Your latest documentation submissions',
                          actionLabel: 'See all',
                          onAction: () => onOpenRequestTab(),
                        ),
                        const SizedBox(height: 10),
                        ...recent.map(
                          (req) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecentRequestTile(
                              request: req,
                              onTap: () => _openDetails(context, req),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const _HomeSectionHeader(
                        title: 'Explore',
                        subtitle: 'Jump to calendar, gallery, or feedback',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 10.0;
                          final tileWidth = (constraints.maxWidth - gap * 2) / 3;
                          final compact = tileWidth < 108;
                          return Row(
                            children: [
                              SizedBox(
                                width: tileWidth,
                                child: _CompactShortcut(
                                  icon: Icons.calendar_month_rounded,
                                  label: compact ? 'Calendar' : 'Campus calendar',
                                  accent: kCyan,
                                  background: kCyanDim,
                                  onTap: onViewCalendar,
                                  compact: compact,
                                ),
                              ),
                              const SizedBox(width: gap),
                              SizedBox(
                                width: tileWidth,
                                child: _CompactShortcut(
                                  icon: Icons.photo_library_rounded,
                                  label: compact ? 'Gallery' : 'Event gallery',
                                  accent: kDashStatPurpleIcon,
                                  background: kPurpleDim,
                                  onTap: onViewGallery,
                                  compact: compact,
                                ),
                              ),
                              const SizedBox(width: gap),
                              SizedBox(
                                width: tileWidth,
                                child: _CompactShortcut(
                                  icon: Icons.rate_review_rounded,
                                  label: compact ? 'Feedback' : 'Rate coverage',
                                  accent: kYellow,
                                  background: kYellowDim,
                                  onTap: onOpenFeedback,
                                  compact: compact,
                                ),
                              ),
                            ],
                          );
                        },
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

String _requestorDisplayName(String sessionName) {
  final profile = appState.profileName.trim();
  if (profile.isNotEmpty) return profile;
  final session = sessionName.trim();
  if (session.isNotEmpty) return session;
  return 'Organization';
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: kAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _RequestorHomeDarkHero extends StatelessWidget {
  const _RequestorHomeDarkHero({
    required this.displayName,
    required this.total,
    required this.pending,
    required this.approved,
    this.onNotifications,
    this.onProfileTap,
    required this.onOpenRequestTab,
  });

  final String displayName;
  final int total;
  final int pending;
  final int approved;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;
  final void Function({RequestStatus? filter}) onOpenRequestTab;

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
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RequestorHeroTopBar(
                onNotifications: onNotifications,
                onProfileTap: onProfileTap,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome back',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.15,
                )),
              ),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.2,
                      )),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track documentation requests from submission through approval.',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                )),
              ),
              const SizedBox(height: 14),
              _RequestorHeroStats(
                total: total,
                pending: pending,
                approved: approved,
                onTotalTap: () => onOpenRequestTab(),
                onPendingTap: () => onOpenRequestTab(filter: RequestStatus.pending),
                onApprovedTap: () => onOpenRequestTab(filter: RequestStatus.approved),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestorHeroStats extends StatelessWidget {
  const _RequestorHeroStats({
    required this.total,
    required this.pending,
    required this.approved,
    this.onTotalTap,
    this.onPendingTap,
    this.onApprovedTap,
  });

  final int total;
  final int pending;
  final int approved;
  final VoidCallback? onTotalTap;
  final VoidCallback? onPendingTap;
  final VoidCallback? onApprovedTap;

  static Widget _divider(bool compact) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
        child: Container(
          width: 1,
          color: kCyan.withValues(alpha: 0.22),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCyan.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HeroStatCell(
                icon: Icons.description_rounded,
                value: '$total',
                label: 'Total',
                accent: kCyan,
                onTap: onTotalTap,
                stacked: compact,
              ),
            ),
            _divider(compact),
            Expanded(
              child: _HeroStatCell(
                icon: Icons.schedule_rounded,
                value: '$pending',
                label: 'Pending',
                accent: kYellow,
                onTap: onPendingTap,
                stacked: compact,
              ),
            ),
            _divider(compact),
            Expanded(
              child: _HeroStatCell(
                icon: Icons.check_circle_rounded,
                value: '$approved',
                label: 'Approved',
                accent: kGreen,
                onTap: onApprovedTap,
                stacked: compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatCell extends StatelessWidget {
  const _HeroStatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.onTap,
    this.stacked = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: stacked ? 6 : 8,
        vertical: 11,
      ),
      child: stacked
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: accent.withValues(alpha: 0.95)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.2,
                  )),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  )),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: accent.withValues(alpha: 0.95)),
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
                        maxLines: 1,
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
              ],
            ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _CreateRequestBanner extends StatelessWidget {
  const _CreateRequestBanner({required this.onTap});

  final VoidCallback onTap;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      kAccent,
      Color(0xFF0066CC),
      kCyan,
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            boxShadow: [
              BoxShadow(
                color: kAccent.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create new request',
                        style: dashText(const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        )),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Plan documentation coverage for an upcoming event.',
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12,
                          height: 1.3,
                        )),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle lift + ripple on tap for tinted home cards.
class _InteractiveTintCard extends StatefulWidget {
  const _InteractiveTintCard({
    required this.accent,
    required this.background,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Color accent;
  final Color background;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  State<_InteractiveTintCard> createState() => _InteractiveTintCardState();
}

class _InteractiveTintCardState extends State<_InteractiveTintCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kMemberDashboardInnerRadius);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.background,
              Color.lerp(widget.background, kSurface, 0.35)!,
            ],
          ),
          border: Border.all(
            color: widget.accent.withValues(alpha: _pressed ? 0.34 : 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: _pressed ? 0.12 : 0.07),
              blurRadius: _pressed ? 14 : 10,
              offset: Offset(0, _pressed ? 5 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            borderRadius: radius,
            splashColor: widget.accent.withValues(alpha: 0.12),
            highlightColor: widget.accent.withValues(alpha: 0.06),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactShortcut extends StatelessWidget {
  const _CompactShortcut({
    required this.icon,
    required this.label,
    required this.accent,
    required this.background,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color background;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _InteractiveTintCard(
      accent: accent,
      background: background,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 12 : 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: compact ? 18 : 20),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            label,
            style: dashText(TextStyle(
              color: kTextPrimary,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            )),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RecentRequestTile extends StatelessWidget {
  const _RecentRequestTile({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);
    final submitted = request.submissionDate;
    final location = request.location?.trim();
    final start = request.startTime?.trim();
    final end = request.endTime?.trim();
    final timeLabel = start != null && start.isNotEmpty
        ? (end != null && end.isNotEmpty ? '$start – $end' : start)
        : null;

    return MemberDashboardCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        splashColor: style.color.withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: style.color, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.eventName,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _RecentMetaRow(
                      icon: Icons.event_rounded,
                      text: formatRequestShortDate(request.eventDate),
                    ),
                    if (timeLabel != null) ...[
                      const SizedBox(height: 3),
                      _RecentMetaRow(icon: Icons.schedule_rounded, text: timeLabel),
                    ],
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _RecentMetaRow(icon: Icons.location_on_outlined, text: location),
                    ],
                    if (submitted != null) ...[
                      const SizedBox(height: 3),
                      _RecentMetaRow(
                        icon: Icons.upload_rounded,
                        text: 'Submitted ${formatRequestShortDate(submitted)}',
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: style.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: style.color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          color: style.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: style.color.withValues(alpha: 0.75),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMetaRow extends StatelessWidget {
  const _RecentMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: kIconInactive),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EmptyRequestsHint extends StatelessWidget {
  const _EmptyRequestsHint();

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccent.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.inbox_outlined, color: kAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No requests yet',
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use the banner above to submit your first event for documentation coverage.',
                  style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
