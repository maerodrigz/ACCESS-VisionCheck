import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/widgets/auth_gate.dart';
import 'package:access_mobile/mobile_app/screens/dashboard_screen.dart';
import 'package:access_mobile/mobile_app/screens/calendar_screen.dart';
import 'package:access_mobile/mobile_app/screens/my_assignments_screen.dart';
import 'package:access_mobile/mobile_app/screens/event_album_screen.dart';
import 'package:access_mobile/mobile_app/screens/gallery_screen.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/mobile_app/screens/rankings_screen.dart';
import 'package:access_mobile/mobile_app/screens/profile_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/request_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/requestor_gallery_screen.dart';
import 'package:access_mobile/mobile_app/navigation/member_shell_navigation.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_tabs.dart';
import 'package:access_mobile/mobile_app/screens/requestor/requestor_calendar_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/requestor_feedback_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/requestor_home_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/requestor_profile_screen.dart';
import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_bottom_nav.dart';
import 'package:access_mobile/mobile_app/sheets/notifications_sheet.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_splash_gate.dart';
import 'package:access_mobile/mobile_app/widgets/member_bottom_nav.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';
import 'package:access_mobile/shared/navigation/app_navigator.dart';
import 'package:access_mobile/web_admin/controllers/web_admin_shell.dart';
class AccessApp extends StatefulWidget {
  const AccessApp({super.key});
  @override
  State<AccessApp> createState() => _AccessAppState();
}

// Legacy account type for mobile shells (maps from API roles).
enum AccountType { member, requester }

class _AccessAppState extends State<AccessApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => MaterialApp(
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: buildAccessLightTheme(),
        darkTheme: buildAccessDarkTheme(),
        // Mobile uses the clean light ACCESS palette (matches design tokens).
        themeMode: kIsWeb ? appState.themeMode : ThemeMode.light,
        builder: (context, child) {
          if (kIsWeb || child == null) return child ?? const SizedBox.shrink();
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 0.92, maxScaleFactor: 1.12),
            ),
            child: child,
          );
        },
        home: MobileSplashGate(
          key: const ValueKey('access_mobile_splash_gate'),
          child: AuthGate(
            adminBuilder: (user) => kIsWeb
                ? WebAdminShell(user: user)
                : MainShell(
                    onLogout: authController.logout,
                    userName: user.name,
                  ),
            memberBuilder: (user) => MainShell(
              onLogout: authController.logout,
              userName: user.name,
            ),
            organizationBuilder: (user) => RequesterShell(
              onLogout: authController.logout,
              userName: user.name,
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  final String userName;
  const MainShell({super.key, required this.onLogout, required this.userName});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    MemberShellNavigation.openGallery = _openGallery;
    MemberShellNavigation.openHome = () => _goToTab(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      memberDataController.seedHomeFromSession();
      unawaited(memberDataController.bootstrapMemberApp());
    });
  }

  @override
  void dispose() {
    MemberShellNavigation.clear();
    super.dispose();
  }

  void _goToTab(int index) {
    if (_navIndex == index) return;
    setState(() => _navIndex = index);
    unawaited(memberDataController.ensureMemberTabData(index));
  }

  void _openGallery({int? requestId}) {
    _goToTab(3);
    if (requestId == null) return;
    unawaited(_openGalleryAlbumWhenReady(requestId));
  }

  Future<void> _openGalleryAlbumWhenReady(int requestId) async {
    await memberDataController.ensureGalleryTab();
    var albums = buildEventGalleryAlbums(appState.eventGallery);
    var album = galleryAlbumForRequestId(albums, requestId);
    if (album == null) {
      await memberDataController.refreshEventGallery(fullCatalog: true);
      if (!mounted) return;
      albums = buildEventGalleryAlbums(appState.eventGallery);
      album = galleryAlbumForRequestId(albums, requestId);
    }
    if (!mounted || album == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event gallery is not available yet. Try again shortly.'),
          ),
        );
      }
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => EventAlbumScreen(album: album!)),
    );
  }

  void _openProfile() {
    unawaited(memberDataController.refreshProfile());
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (profileContext) => ProfileScreen(
          onViewRankings: () {
            Navigator.pop(profileContext);
            _goToTab(5);
          },
          onViewEvaluations: () {
            Navigator.pop(profileContext);
            _goToTab(1);
          },
          onNotificationsTap: () => showNotifications(profileContext),
        ),
      ),
    );
  }

  Widget get _screen => switch (_navIndex) {
    0 => DashboardScreen(
          userName: widget.userName,
          onLogout: widget.onLogout,
          onViewPortfolio: () => _goToTab(1),
          onViewEventGallery: () => _goToTab(3),
          onViewCalendar: () => _goToTab(2),
          onViewRankings: () => _goToTab(5),
          onViewNotifications: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
    1 => EvaluationScreen(
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
    2 => CalendarScreen(
          onViewGallery: () => _goToTab(3),
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
          onViewAssignments: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAssignmentsScreen()),
            );
          },
        ),
    3 => GalleryScreen(
          onViewCalendar: () => _goToTab(2),
          onViewPortfolio: () => _goToTab(1),
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
    5 => RankingsScreen(
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
    _ => const DashboardScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      resizeToAvoidBottomInset: false,
      body: MobilePageWrapper(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey(_navIndex),
            child: _screen,
          ),
        ),
      ),
      bottomNavigationBar: MemberBottomNav(
        selected: _navIndex,
        onTap: _goToTab,
      ),
    );
  }
}

// The legacy side rail was removed — the mobile shell uses [MemberBottomNav]
// on every form factor. The web admin has its own shell under lib/web_admin/.
// Do not re-introduce a side rail here without keeping tab indices in sync.

// ── Requester Shell (separate app for service requesters) ─────────────────────
class RequesterShell extends StatefulWidget {
  final VoidCallback onLogout;
  final String userName;
  const RequesterShell({super.key, required this.onLogout, required this.userName});
  @override
  State<RequesterShell> createState() => _RequesterShellState();
}

class _RequesterShellState extends State<RequesterShell> {
  int _navIndex = 0;
  RequestStatus? _requestFilter;
  int? _feedbackRequestId;

  @override
  void initState() {
    super.initState();
    RequestorShellNavigation.openFeedback = _openFeedback;
    RequestorShellNavigation.openGallery = () => _goToTab(RequestorShellTabs.gallery);
    RequestorShellNavigation.openCalendar = () => _goToTab(RequestorShellTabs.calendar);
    RequestorShellNavigation.openRequests = _openRequestTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      memberDataController.seedHomeFromSession();
      unawaited(memberDataController.bootstrapMemberApp());
    });
  }

  @override
  void dispose() {
    RequestorShellNavigation.clear();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() {
      if (index != RequestorShellTabs.requests) _requestFilter = null;
      if (index != RequestorShellTabs.feedback) _feedbackRequestId = null;
      _navIndex = index;
    });
    unawaited(memberDataController.ensureRequestorTabData(index));
  }

  void _openFeedback({int? requestId}) {
    setState(() {
      _feedbackRequestId = requestId;
      _navIndex = RequestorShellTabs.feedback;
    });
    unawaited(memberDataController.ensureRequestorTabData(RequestorShellTabs.feedback));
  }

  void _openRequestTab({RequestStatus? filter}) {
    setState(() {
      _requestFilter = filter;
      _navIndex = RequestorShellTabs.requests;
    });
  }

  void _openProfile() {
    unawaited(memberDataController.refreshProfile());
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const RequestorProfileScreen(),
      ),
    );
  }

  Future<void> _openCreateForm({DateTime? eventDate}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentationRequestFormScreen(initialEventDate: eventDate),
      ),
    );
    if (created == true && mounted) {
      await memberDataController.refreshAll();
    }
  }

  List<Widget> get _tabStack => [
        RequestorHomeScreen(
          userName: widget.userName,
          onOpenRequestTab: _openRequestTab,
          onOpenFeedback: _openFeedback,
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
        RequestorCalendarScreen(
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
          onPlanRequest: (day) => _openCreateForm(eventDate: day),
        ),
        RequestScreen(
          key: ValueKey(_requestFilter?.name ?? 'all'),
          initialFilter: _requestFilter,
          onViewGallery: () => _goToTab(RequestorShellTabs.gallery),
          onViewFeedback: _openFeedback,
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
        RequestorGalleryScreen(
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
        RequestorFeedbackScreen(
          key: ValueKey('feedback-$_feedbackRequestId'),
          initialRequestId: _feedbackRequestId,
          onNotificationsTap: () => showNotifications(context),
          onProfileTap: _openProfile,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      resizeToAvoidBottomInset: true,
      body: MobilePageWrapper(
        child: IndexedStack(
          index: _navIndex,
          children: _tabStack,
        ),
      ),
      bottomNavigationBar: RequestorBottomNav(
        selected: _navIndex,
        onTap: _goToTab,
      ),
    );
  }
}
