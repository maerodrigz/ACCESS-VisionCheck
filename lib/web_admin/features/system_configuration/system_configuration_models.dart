/// Persisted system-wide configuration for the Administration Panel.
class SystemConfigurationData {
  const SystemConfigurationData({
    required this.organizationName,
    required this.organizationEmail,
    required this.academicYear,
    required this.allowLateMediaUploads,
    required this.maxUploadPeriodDays,
    required this.requireEventAlbumBeforeUpload,
    required this.enableFacebookPublishing,
    required this.enableAiDetection,
    required this.aiConfidenceThreshold,
    required this.autoGenerateReviewAlerts,
    required this.requireManualVerificationBeforeWarning,
    required this.notifyNewDocumentationRequests,
    required this.notifyMediaIntegrityAlerts,
    required this.notifyRequesterFeedback,
    required this.notifyFacebookPublishingStatus,
    required this.notifySystemNotifications,
    required this.minPasswordLength,
    required this.sessionTimeoutMinutes,
    required this.accountLockoutMinutes,
    required this.twoFactorEnabled,
    required this.lastBackupAt,
    required this.backupStatus,
    required this.storageUsagePercent,
  });

  final String organizationName;
  final String organizationEmail;
  final String academicYear;

  final bool allowLateMediaUploads;
  final int maxUploadPeriodDays;
  final bool requireEventAlbumBeforeUpload;
  final bool enableFacebookPublishing;

  final bool enableAiDetection;
  final double aiConfidenceThreshold;
  final bool autoGenerateReviewAlerts;
  final bool requireManualVerificationBeforeWarning;

  final bool notifyNewDocumentationRequests;
  final bool notifyMediaIntegrityAlerts;
  final bool notifyRequesterFeedback;
  final bool notifyFacebookPublishingStatus;
  final bool notifySystemNotifications;

  final int minPasswordLength;
  final int sessionTimeoutMinutes;
  final int accountLockoutMinutes;
  final bool twoFactorEnabled;

  final DateTime? lastBackupAt;
  final String backupStatus;
  final double storageUsagePercent;

  SystemConfigurationData copyWith({
    String? organizationName,
    String? organizationEmail,
    String? academicYear,
    bool? allowLateMediaUploads,
    int? maxUploadPeriodDays,
    bool? requireEventAlbumBeforeUpload,
    bool? enableFacebookPublishing,
    bool? enableAiDetection,
    double? aiConfidenceThreshold,
    bool? autoGenerateReviewAlerts,
    bool? requireManualVerificationBeforeWarning,
    bool? notifyNewDocumentationRequests,
    bool? notifyMediaIntegrityAlerts,
    bool? notifyRequesterFeedback,
    bool? notifyFacebookPublishingStatus,
    bool? notifySystemNotifications,
    int? minPasswordLength,
    int? sessionTimeoutMinutes,
    int? accountLockoutMinutes,
    bool? twoFactorEnabled,
    DateTime? lastBackupAt,
    String? backupStatus,
    double? storageUsagePercent,
  }) =>
      SystemConfigurationData(
        organizationName: organizationName ?? this.organizationName,
        organizationEmail: organizationEmail ?? this.organizationEmail,
        academicYear: academicYear ?? this.academicYear,
        allowLateMediaUploads: allowLateMediaUploads ?? this.allowLateMediaUploads,
        maxUploadPeriodDays: maxUploadPeriodDays ?? this.maxUploadPeriodDays,
        requireEventAlbumBeforeUpload: requireEventAlbumBeforeUpload ?? this.requireEventAlbumBeforeUpload,
        enableFacebookPublishing: enableFacebookPublishing ?? this.enableFacebookPublishing,
        enableAiDetection: enableAiDetection ?? this.enableAiDetection,
        aiConfidenceThreshold: aiConfidenceThreshold ?? this.aiConfidenceThreshold,
        autoGenerateReviewAlerts: autoGenerateReviewAlerts ?? this.autoGenerateReviewAlerts,
        requireManualVerificationBeforeWarning:
            requireManualVerificationBeforeWarning ?? this.requireManualVerificationBeforeWarning,
        notifyNewDocumentationRequests: notifyNewDocumentationRequests ?? this.notifyNewDocumentationRequests,
        notifyMediaIntegrityAlerts: notifyMediaIntegrityAlerts ?? this.notifyMediaIntegrityAlerts,
        notifyRequesterFeedback: notifyRequesterFeedback ?? this.notifyRequesterFeedback,
        notifyFacebookPublishingStatus: notifyFacebookPublishingStatus ?? this.notifyFacebookPublishingStatus,
        notifySystemNotifications: notifySystemNotifications ?? this.notifySystemNotifications,
        minPasswordLength: minPasswordLength ?? this.minPasswordLength,
        sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
        accountLockoutMinutes: accountLockoutMinutes ?? this.accountLockoutMinutes,
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        backupStatus: backupStatus ?? this.backupStatus,
        storageUsagePercent: storageUsagePercent ?? this.storageUsagePercent,
      );

  Map<String, dynamic> toPrefsMap() => {
        'organization_name': organizationName,
        'organization_email': organizationEmail,
        'academic_year': academicYear,
        'allow_late_media_uploads': allowLateMediaUploads,
        'max_upload_period_days': maxUploadPeriodDays,
        'require_event_album_before_upload': requireEventAlbumBeforeUpload,
        'enable_facebook_publishing': enableFacebookPublishing,
        'enable_ai_detection': enableAiDetection,
        'ai_confidence_threshold': aiConfidenceThreshold,
        'auto_generate_review_alerts': autoGenerateReviewAlerts,
        'require_manual_verification_before_warning': requireManualVerificationBeforeWarning,
        'notify_new_documentation_requests': notifyNewDocumentationRequests,
        'notify_media_integrity_alerts': notifyMediaIntegrityAlerts,
        'notify_requester_feedback': notifyRequesterFeedback,
        'notify_facebook_publishing_status': notifyFacebookPublishingStatus,
        'notify_system_notifications': notifySystemNotifications,
        'min_password_length': minPasswordLength,
        'session_timeout_minutes': sessionTimeoutMinutes,
        'account_lockout_minutes': accountLockoutMinutes,
        'two_factor_enabled': twoFactorEnabled,
        'last_backup_at': lastBackupAt?.toIso8601String(),
        'backup_status': backupStatus,
        'storage_usage_percent': storageUsagePercent,
      };

  factory SystemConfigurationData.fromPrefsMap(Map<String, dynamic> map, {required String defaultOrgName}) {
    return SystemConfigurationData(
      organizationName: map['organization_name'] as String? ?? defaultOrgName,
      organizationEmail: map['organization_email'] as String? ?? 'access@university.edu.ph',
      academicYear: map['academic_year'] as String? ?? '2025–2026',
      allowLateMediaUploads: map['allow_late_media_uploads'] as bool? ?? true,
      maxUploadPeriodDays: map['max_upload_period_days'] as int? ?? 7,
      requireEventAlbumBeforeUpload: map['require_event_album_before_upload'] as bool? ?? true,
      enableFacebookPublishing: map['enable_facebook_publishing'] as bool? ?? true,
      enableAiDetection: map['enable_ai_detection'] as bool? ?? true,
      aiConfidenceThreshold: (map['ai_confidence_threshold'] as num?)?.toDouble() ?? 0.75,
      autoGenerateReviewAlerts: map['auto_generate_review_alerts'] as bool? ?? true,
      requireManualVerificationBeforeWarning: map['require_manual_verification_before_warning'] as bool? ?? true,
      notifyNewDocumentationRequests: map['notify_new_documentation_requests'] as bool? ?? true,
      notifyMediaIntegrityAlerts: map['notify_media_integrity_alerts'] as bool? ?? true,
      notifyRequesterFeedback: map['notify_requester_feedback'] as bool? ?? true,
      notifyFacebookPublishingStatus: map['notify_facebook_publishing_status'] as bool? ?? true,
      notifySystemNotifications: map['notify_system_notifications'] as bool? ?? true,
      minPasswordLength: map['min_password_length'] as int? ?? 8,
      sessionTimeoutMinutes: map['session_timeout_minutes'] as int? ?? 60,
      accountLockoutMinutes: map['account_lockout_minutes'] as int? ?? 30,
      twoFactorEnabled: map['two_factor_enabled'] as bool? ?? false,
      lastBackupAt: _parseDate(map['last_backup_at']),
      backupStatus: map['backup_status'] as String? ?? 'Healthy',
      storageUsagePercent: (map['storage_usage_percent'] as num?)?.toDouble() ?? 42,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

String formatConfigDateTime(DateTime? dt) {
  if (dt == null) return 'Not yet recorded';
  final local = dt.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ap = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $h:$m $ap';
}
