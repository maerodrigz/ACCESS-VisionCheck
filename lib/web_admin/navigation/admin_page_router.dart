import 'package:flutter/material.dart';

import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

import 'package:access_mobile/web_admin/screens/admin_ai_detection_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_dashboard_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_evaluations_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_events_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_analytics_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_requester_feedback_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_feature_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_notifications_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_system_monitor_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_branding_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_media_repository_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_members_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_registration_approvals_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_rankings_screen.dart';
import 'package:access_mobile/web_admin/screens/admin_roles_screen.dart';

import 'package:access_mobile/web_admin/screens/admin_requests_screen.dart';

/// Maps [AdminRoute] to the page widget for the main content area.

class AdminPageRouter {

  static Widget pageFor(AdminRoute route) {

    switch (route) {

      case AdminRoute.dashboard:

        return const AdminDashboardScreen();



      case AdminRoute.docRequests:
      case AdminRoute.requestStatus:
      case AdminRoute.taskAssignments:
        return const AdminRequestsScreen();

      case AdminRoute.eventCalendar:
        return const AdminEventsScreen();



      case AdminRoute.mediaRepository:

        return const AdminMediaRepositoryScreen();



      case AdminRoute.mediaEvaluation:

        return const AdminEvaluationsScreen();



      case AdminRoute.aiDetection:

        return const AdminAiDetectionScreen();



      case AdminRoute.registrationApprovals:

        return const AdminRegistrationApprovalsScreen();

      case AdminRoute.members:

        return const AdminMembersScreen();



      case AdminRoute.skillClassification:

      case AdminRoute.rankings:

        return const AdminRankingsScreen();



      case AdminRoute.analyticsDashboard:
      case AdminRoute.participationReports:
        return const AdminAnalyticsScreen();

      case AdminRoute.feedbackReports:
        return const AdminRequesterFeedbackScreen();



      case AdminRoute.notifications:

        return const AdminNotificationsScreen();



      case AdminRoute.systemMonitor:

        return const AdminSystemMonitorScreen();

      case AdminRoute.branding:

        return const AdminBrandingScreen();

      case AdminRoute.roles:

        return const AdminRolesScreen();

    }

  }



  static Widget _featurePlaceholder(AdminRoute route) {

    final meta = _placeholders[route];

    if (meta == null) return const SizedBox.shrink();

    return AdminFeatureScreen(

      route: route,

      title: meta.$1,

      subtitle: meta.$2,

      icon: meta.$3,

      color: meta.$4,

      features: meta.$5,

    );

  }

}



typedef _Meta = (String, String, IconData, Color, List<String>);



const _placeholders = <AdminRoute, _Meta>{

  AdminRoute.roles: (

    'Account Management',

    'Manage user accounts, authentication, and platform access.',

    Icons.manage_accounts_outlined,

    AdminTheme.accentBlue,

    ['Activate / deactivate accounts', 'Reset passwords', 'Login activity', 'Role assignment'],

  ),

  AdminRoute.skillClassification: (

    'Competency Management',

    'Evaluate photographer and videographer competency for documentation assignments.',

    Icons.workspace_premium_outlined,

    AdminTheme.accentBlue,

    ['System recommendations with transparent criteria', 'Administrator override support'],

  ),

  AdminRoute.notifications: (

    'Notifications',

    'Member notifications are stored in DB; broadcast UI coming soon.',

    Icons.notifications,

    Color(0xFF64748B),

    ['Database: notifications table'],

  ),

  AdminRoute.systemMonitor: (

    'System Monitor',

    'API health at GET /api/health',

    Icons.monitor_heart,

    Color(0xFF059669),

    ['Backend: python manage.py runserver'],

  ),

};

