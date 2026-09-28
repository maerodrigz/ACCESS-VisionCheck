import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum IntegrityAlertLevel { low, medium, high }

enum IntegrityAlertStatus {
  pendingReview,
  warningSent,
  dismissed,
  resolved,
  confirmedViolation,
}

enum IntegrityWarningLevel { first, second, finalWarning }

class IntegrityOverviewStats {
  const IntegrityOverviewStats({
    required this.pendingReviewAlerts,
    required this.confirmedViolations,
    required this.warningsIssued,
    required this.resolvedAlerts,
  });

  final int pendingReviewAlerts;
  final int confirmedViolations;
  final int warningsIssued;
  final int resolvedAlerts;
}

class IntegrityAlert {
  const IntegrityAlert({
    required this.id,
    required this.mediaId,
    required this.memberId,
    required this.memberName,
    required this.memberRole,
    required this.eventName,
    required this.uploadDate,
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.aiConfidence,
    required this.detectionSummary,
    required this.alertLevel,
    required this.status,
    required this.initials,
    this.skillLevel,
    this.adminNotes,
    this.underMonitoring = false,
  });

  final String id;
  final int mediaId;
  final int memberId;
  final String memberName;
  final String memberRole;
  final String eventName;
  final DateTime? uploadDate;
  final String fileName;
  final String fileType;
  final String fileUrl;
  final double aiConfidence;
  final String detectionSummary;
  final IntegrityAlertLevel alertLevel;
  final IntegrityAlertStatus status;
  final String initials;
  final String? skillLevel;
  final String? adminNotes;
  final bool underMonitoring;

  bool get isVideo => fileType.toLowerCase() == 'video';
  String get thumbnailUrl => AdminApiService.mediaUrl(fileUrl);
  int get confidencePercent => (aiConfidence * 100).round().clamp(0, 100);
}

class IntegrityWarningRecord {
  const IntegrityWarningRecord({
    required this.level,
    required this.reason,
    required this.message,
    required this.issuedAt,
    required this.alertId,
  });

  final IntegrityWarningLevel level;
  final String reason;
  final String message;
  final DateTime issuedAt;
  final String alertId;

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'reason': reason,
        'message': message,
        'issuedAt': issuedAt.toIso8601String(),
        'alertId': alertId,
      };

  factory IntegrityWarningRecord.fromJson(Map<String, dynamic> j) => IntegrityWarningRecord(
        level: IntegrityWarningLevel.values.firstWhere(
          (e) => e.name == j['level'],
          orElse: () => IntegrityWarningLevel.first,
        ),
        reason: j['reason'] as String? ?? '',
        message: j['message'] as String? ?? '',
        issuedAt: DateTime.tryParse(j['issuedAt'] as String? ?? '') ?? DateTime.now(),
        alertId: j['alertId'] as String? ?? '',
      );
}

class IntegrityTimelineEvent {
  const IntegrityTimelineEvent({
    required this.date,
    required this.title,
    required this.subtitle,
    this.icon = Icons.circle,
    this.color,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
}

class MemberIntegrityRecord {
  const MemberIntegrityRecord({
    required this.memberId,
    required this.memberName,
    required this.initials,
    required this.role,
    required this.integrityScore,
    required this.warningsIssued,
    required this.resolvedAlerts,
    required this.confirmedViolations,
    required this.lastWarningDate,
    required this.timeline,
    this.skillLevel,
  });

  final int memberId;
  final String memberName;
  final String initials;
  final String role;
  final int integrityScore;
  final int warningsIssued;
  final int resolvedAlerts;
  final int confirmedViolations;
  final DateTime? lastWarningDate;
  final List<IntegrityTimelineEvent> timeline;
  final String? skillLevel;
}

class IntegrityDashboardData {
  const IntegrityDashboardData({
    required this.alerts,
    required this.stats,
    required this.memberRecords,
  });

  final List<IntegrityAlert> alerts;
  final IntegrityOverviewStats stats;
  final Map<int, MemberIntegrityRecord> memberRecords;
}

extension IntegrityAlertLevelX on IntegrityAlertLevel {
  String get label => switch (this) {
        IntegrityAlertLevel.low => 'Low',
        IntegrityAlertLevel.medium => 'Medium',
        IntegrityAlertLevel.high => 'High',
      };

  Color get color => switch (this) {
        IntegrityAlertLevel.low => AdminTheme.success,
        IntegrityAlertLevel.medium => AdminTheme.warning,
        IntegrityAlertLevel.high => AdminTheme.danger,
      };

  String get emoji => switch (this) {
        IntegrityAlertLevel.low => '🟢',
        IntegrityAlertLevel.medium => '🟡',
        IntegrityAlertLevel.high => '🔴',
      };
}

extension IntegrityAlertStatusX on IntegrityAlertStatus {
  String get label => switch (this) {
        IntegrityAlertStatus.pendingReview => 'Pending Review',
        IntegrityAlertStatus.warningSent => 'Warning Sent',
        IntegrityAlertStatus.dismissed => 'Dismissed',
        IntegrityAlertStatus.resolved => 'Resolved',
        IntegrityAlertStatus.confirmedViolation => 'Confirmed Violation',
      };

  Color get color => switch (this) {
        IntegrityAlertStatus.pendingReview => AdminTheme.warning,
        IntegrityAlertStatus.warningSent => const Color(0xFFEA580C),
        IntegrityAlertStatus.dismissed => AdminTheme.textSecondary,
        IntegrityAlertStatus.resolved => AdminTheme.success,
        IntegrityAlertStatus.confirmedViolation => AdminTheme.danger,
      };
}

extension IntegrityWarningLevelX on IntegrityWarningLevel {
  String get label => switch (this) {
        IntegrityWarningLevel.first => 'First Warning',
        IntegrityWarningLevel.second => 'Second Warning',
        IntegrityWarningLevel.finalWarning => 'Final Warning',
      };
}

String memberInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String formatIntegrityDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String formatTimelineMonthDay(DateTime d) {
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${months[d.month - 1]} ${d.day}';
}

const kDefaultWarningReason =
    'Uploading AI-generated media as official documentation is prohibited under ACCESS documentation policies.';
