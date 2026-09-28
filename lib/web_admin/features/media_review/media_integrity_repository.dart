import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/web_admin/features/media_review/media_integrity_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaIntegrityRepository {
  static const _alertStatusKey = 'integrity_alert_status';
  static const _alertNotesKey = 'integrity_alert_notes';
  static const _monitoringKey = 'integrity_under_monitoring';
  static const _warningsKey = 'integrity_member_warnings';
  static const _timelineKey = 'integrity_member_timeline';

  Future<IntegrityDashboardData> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception('Backend offline. Run: cd access_backend && python manage.py runserver');
    }

    final results = await Future.wait([
      adminApi.allMedia(),
      adminApi.allUsers(),
      adminApi.allAiDetection(),
      adminApi.rankings(),
    ]);

    final media = _enrichMediaWithAi(results[0], results[2]);
    final users = results[1];
    final rankings = results[3];

    final statusMap = await _loadAlertStatuses();
    final notesMap = await _loadAlertNotes();
    final monitoring = await _loadMonitoringIds();
    final warningsByMember = await _loadWarningsByMember();
    final timelineByMember = await _loadTimelineByMember();

    final skillByUser = <int, String>{};
    for (final r in rankings) {
      final uid = r['user_id'] as int? ?? r['id'] as int?;
      if (uid != null) {
        skillByUser[uid] = r['skill_level'] as String? ?? r['tier'] as String? ?? 'Member';
      }
    }

    final alerts = _buildAlerts(
      media: media,
      users: users,
      statusMap: statusMap,
      notesMap: notesMap,
      monitoring: monitoring,
      skillByUser: skillByUser,
    );

    final memberRecords = _buildMemberRecords(
      alerts: alerts,
      warningsByMember: warningsByMember,
      timelineByMember: timelineByMember,
      skillByUser: skillByUser,
    );

    return IntegrityDashboardData(
      alerts: alerts,
      stats: _computeStats(alerts),
      memberRecords: memberRecords,
    );
  }

  List<IntegrityAlert> _buildAlerts({
    required List<Map<String, dynamic>> media,
    required List<Map<String, dynamic>> users,
    required Map<String, String> statusMap,
    required Map<String, String> notesMap,
    required Set<int> monitoring,
    required Map<int, String> skillByUser,
  }) {
    final alerts = <IntegrityAlert>[];

    for (final row in media) {
      if (!_isAiRow(row)) continue;

      final mediaId = row['id'] as int? ?? 0;
      final memberId = row['uploaded_by'] as int? ?? 0;
      final alertId = 'alert_$mediaId';

      final user = users.where((u) => (u['id'] as int?) == memberId).firstOrNull;
      final name = user?['name'] as String? ?? user?['fullname'] as String? ?? row['uploader_name'] as String? ?? 'Unknown';
      final role = _memberRole(user, row);
      final event = row['event_title'] as String? ?? row['source_label'] as String? ?? 'Event';
      final confidence = _aiConfidence(row);
      final level = _alertLevel(confidence);
      final status = _parseStatus(statusMap[alertId] ?? 'pendingReview');

      alerts.add(IntegrityAlert(
        id: alertId,
        mediaId: mediaId,
        memberId: memberId,
        memberName: name,
        memberRole: role,
        eventName: event,
        uploadDate: _parseDate(row['uploaded_at'] as String?),
        fileName: row['file_name'] as String? ?? 'Media #$mediaId',
        fileType: row['file_type'] as String? ?? 'image',
        fileUrl: row['file_url'] as String? ?? '',
        aiConfidence: confidence,
        detectionSummary: _detectionSummary(row, confidence),
        alertLevel: level,
        status: status,
        initials: memberInitials(name),
        skillLevel: skillByUser[memberId],
        adminNotes: notesMap[alertId],
        underMonitoring: monitoring.contains(memberId),
      ));
    }

    alerts.sort((a, b) {
      final lc = a.alertLevel.index.compareTo(b.alertLevel.index);
      if (lc != 0) return lc;
      return (b.uploadDate ?? DateTime(2000)).compareTo(a.uploadDate ?? DateTime(2000));
    });

    return alerts;
  }

  Map<int, MemberIntegrityRecord> _buildMemberRecords({
    required List<IntegrityAlert> alerts,
    required Map<int, List<IntegrityWarningRecord>> warningsByMember,
    required Map<int, List<IntegrityTimelineEvent>> timelineByMember,
    required Map<int, String> skillByUser,
  }) {
    final byMember = <int, List<IntegrityAlert>>{};
    for (final a in alerts) {
      byMember.putIfAbsent(a.memberId, () => []).add(a);
    }

    final records = <int, MemberIntegrityRecord>{};
    for (final entry in byMember.entries) {
      final memberId = entry.key;
      final memberAlerts = entry.value;
      final name = memberAlerts.first.memberName;
      final role = memberAlerts.first.memberRole;
      final warnings = warningsByMember[memberId] ?? [];
      final resolved = memberAlerts.where((a) => a.status == IntegrityAlertStatus.resolved || a.status == IntegrityAlertStatus.dismissed).length;
      final violations = memberAlerts.where((a) => a.status == IntegrityAlertStatus.confirmedViolation).length;
      final lastWarning = warnings.isEmpty ? null : warnings.map((w) => w.issuedAt).reduce((a, b) => a.isAfter(b) ? a : b);

      var score = 100;
      score -= warnings.length * 12;
      score -= violations * 25;
      score += resolved * 3;
      score = score.clamp(0, 100);

      final timeline = timelineByMember[memberId] ?? _defaultTimeline(memberAlerts, warnings);
      timeline.sort((a, b) => b.date.compareTo(a.date));

      records[memberId] = MemberIntegrityRecord(
        memberId: memberId,
        memberName: name,
        initials: memberInitials(name),
        role: role,
        integrityScore: score,
        warningsIssued: warnings.length,
        resolvedAlerts: resolved,
        confirmedViolations: violations,
        lastWarningDate: lastWarning,
        timeline: timeline.take(12).toList(),
        skillLevel: skillByUser[memberId],
      );
    }

    return records;
  }

  List<IntegrityTimelineEvent> _defaultTimeline(
    List<IntegrityAlert> alerts,
    List<IntegrityWarningRecord> warnings,
  ) {
    final events = <IntegrityTimelineEvent>[];
    for (final w in warnings) {
      events.add(IntegrityTimelineEvent(
        date: w.issuedAt,
        title: 'Warning Issued',
        subtitle: w.level.label,
        icon: Icons.warning_amber_rounded,
        color: AdminTheme.warning,
      ));
    }
    for (final a in alerts) {
      if (a.status == IntegrityAlertStatus.dismissed) {
        events.add(IntegrityTimelineEvent(
          date: a.uploadDate ?? DateTime.now(),
          title: 'Alert Dismissed',
          subtitle: a.eventName,
          icon: Icons.check_circle_outline,
          color: AdminTheme.success,
        ));
      } else if (a.status == IntegrityAlertStatus.resolved) {
        events.add(IntegrityTimelineEvent(
          date: a.uploadDate ?? DateTime.now(),
          title: 'Authentic Submission Verified',
          subtitle: a.eventName,
          icon: Icons.verified_outlined,
          color: AdminTheme.accentBlue,
        ));
      }
    }
    return events;
  }

  IntegrityOverviewStats _computeStats(List<IntegrityAlert> alerts) {
    var warnings = 0;
    for (final a in alerts) {
      if (a.status == IntegrityAlertStatus.warningSent) warnings++;
    }
    return IntegrityOverviewStats(
      pendingReviewAlerts: alerts.where((a) => a.status == IntegrityAlertStatus.pendingReview).length,
      confirmedViolations: alerts.where((a) => a.status == IntegrityAlertStatus.confirmedViolation).length,
      warningsIssued: warnings,
      resolvedAlerts: alerts.where((a) => a.status == IntegrityAlertStatus.resolved || a.status == IntegrityAlertStatus.dismissed).length,
    );
  }

  List<IntegrityAlert> filterAlerts({
    required List<IntegrityAlert> alerts,
    required String search,
    IntegrityAlertStatus? statusFilter,
    IntegrityAlertLevel? levelFilter,
    IntegrityWarningLevel? warningFilter,
  }) {
    return alerts.where((a) {
      if (statusFilter != null && a.status != statusFilter) return false;
      if (levelFilter != null && a.alertLevel != levelFilter) return false;
      if (search.trim().isEmpty) return true;
      final q = search.toLowerCase();
      return a.memberName.toLowerCase().contains(q) ||
          a.eventName.toLowerCase().contains(q) ||
          a.memberRole.toLowerCase().contains(q) ||
          a.status.label.toLowerCase().contains(q) ||
          (a.uploadDate != null && formatIntegrityDate(a.uploadDate!).toLowerCase().contains(q)) ||
          (warningFilter != null && q.contains(warningFilter.label.toLowerCase()));
    }).toList();
  }

  Future<void> setAlertStatus(String alertId, IntegrityAlertStatus status) async {
    final map = await _loadAlertStatuses();
    map[alertId] = status.name;
    await _saveKeyValueList(_alertStatusKey, map);
  }

  Future<void> setAlertNotes(String alertId, String notes) async {
    final map = await _loadAlertNotes();
    map[alertId] = notes;
    await _saveKeyValueList(_alertNotesKey, map);
  }

  Future<void> dismissAlert(IntegrityAlert alert, {String? notes}) async {
    await setAlertStatus(alert.id, IntegrityAlertStatus.dismissed);
    if (notes != null) await setAlertNotes(alert.id, notes);
    await _appendTimeline(alert.memberId, IntegrityTimelineEvent(
      date: DateTime.now(),
      title: 'Alert Dismissed',
      subtitle: alert.eventName,
      icon: Icons.check_circle_outline,
      color: AdminTheme.success,
    ));
  }

  Future<void> resolveAlert(IntegrityAlert alert, {String? notes}) async {
    await setAlertStatus(alert.id, IntegrityAlertStatus.resolved);
    if (notes != null) await setAlertNotes(alert.id, notes);
    await _appendTimeline(alert.memberId, IntegrityTimelineEvent(
      date: DateTime.now(),
      title: 'Authentic Submission Verified',
      subtitle: alert.eventName,
      icon: Icons.verified_outlined,
      color: AdminTheme.accentBlue,
    ));
  }

  Future<void> confirmViolation(IntegrityAlert alert, {String? notes}) async {
    await setAlertStatus(alert.id, IntegrityAlertStatus.confirmedViolation);
    if (notes != null) await setAlertNotes(alert.id, notes);
    await _appendTimeline(alert.memberId, IntegrityTimelineEvent(
      date: DateTime.now(),
      title: 'Confirmed Violation',
      subtitle: alert.eventName,
      icon: Icons.gavel_outlined,
      color: AdminTheme.danger,
    ));
  }

  Future<void> keepUnderMonitoring(IntegrityAlert alert) async {
    final ids = await _loadMonitoringIds()..add(alert.memberId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_monitoringKey, ids.map((e) => '$e').toList());
  }

  Future<void> sendWarning({
    required IntegrityAlert alert,
    required IntegrityWarningLevel level,
    required String reason,
    required String message,
  }) async {
    final warnings = await _loadWarningsByMember();
    final list = warnings.putIfAbsent(alert.memberId, () => []);
    list.add(IntegrityWarningRecord(
      level: level,
      reason: reason,
      message: message,
      issuedAt: DateTime.now(),
      alertId: alert.id,
    ));
    await _saveWarnings(warnings);
    await setAlertStatus(alert.id, IntegrityAlertStatus.warningSent);
    await _appendTimeline(alert.memberId, IntegrityTimelineEvent(
      date: DateTime.now(),
      title: 'Warning Issued',
      subtitle: level.label,
      icon: Icons.warning_amber_rounded,
      color: AdminTheme.warning,
    ));
  }

  Future<int> warningCountForMember(int memberId) async {
    final w = await _loadWarningsByMember();
    return w[memberId]?.length ?? 0;
  }

  Future<IntegrityWarningLevel> suggestWarningLevel(int memberId) async {
    final count = await warningCountForMember(memberId);
    return switch (count) {
      0 => IntegrityWarningLevel.first,
      1 => IntegrityWarningLevel.second,
      _ => IntegrityWarningLevel.finalWarning,
    };
  }

  String buildExportReport(IntegrityDashboardData data) {
    final buf = StringBuffer('ACCESS VisionCheck — Media Integrity Report\n');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}\n');
    buf.writeln('Pending: ${data.stats.pendingReviewAlerts}');
    buf.writeln('Violations: ${data.stats.confirmedViolations}');
    buf.writeln('Warnings: ${data.stats.warningsIssued}');
    buf.writeln('Resolved: ${data.stats.resolvedAlerts}\n');
    for (final a in data.alerts) {
      buf.writeln('${a.memberName} | ${a.eventName} | ${a.confidencePercent}% | ${a.status.label}');
    }
    return buf.toString();
  }

  Future<void> _appendTimeline(int memberId, IntegrityTimelineEvent event) async {
    final all = await _loadTimelineByMember();
    final list = all.putIfAbsent(memberId, () => []);
    list.insert(0, event);
    await _saveTimeline(all);
  }

  Future<Map<String, String>> _loadAlertStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseKeyValueList(prefs.getStringList(_alertStatusKey) ?? []);
  }

  Future<Map<String, String>> _loadAlertNotes() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseKeyValueList(prefs.getStringList(_alertNotesKey) ?? []);
  }

  Future<Set<int>> _loadMonitoringIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_monitoringKey)?.map(int.tryParse).whereType<int>().toSet() ?? {};
  }

  Future<Map<int, List<IntegrityWarningRecord>>> _loadWarningsByMember() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_warningsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(
          int.parse(k),
          (v as List).map((e) => IntegrityWarningRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        ));
  }

  Future<void> _saveWarnings(Map<int, List<IntegrityWarningRecord>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = data.map((k, v) => MapEntry('$k', v.map((w) => w.toJson()).toList()));
    await prefs.setString(_warningsKey, jsonEncode(encoded));
  }

  Future<Map<int, List<IntegrityTimelineEvent>>> _loadTimelineByMember() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timelineKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(
          int.parse(k),
          (v as List).map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return IntegrityTimelineEvent(
              date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
              title: m['title'] as String? ?? '',
              subtitle: m['subtitle'] as String? ?? '',
            );
          }).toList(),
        ));
  }

  Future<void> _saveTimeline(Map<int, List<IntegrityTimelineEvent>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = data.map((k, v) => MapEntry(
          '$k',
          v.map((e) => {'date': e.date.toIso8601String(), 'title': e.title, 'subtitle': e.subtitle}).toList(),
        ));
    await prefs.setString(_timelineKey, jsonEncode(encoded));
  }

  Future<void> _saveKeyValueList(String key, Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, map.entries.map((e) => '${e.key}:${e.value}').toList());
  }

  Map<String, String> _parseKeyValueList(List<String> raw) {
    final map = <String, String>{};
    for (final entry in raw) {
      final sep = entry.indexOf(':');
      if (sep <= 0) continue;
      map[entry.substring(0, sep)] = entry.substring(sep + 1);
    }
    return map;
  }

  IntegrityAlertStatus _parseStatus(String raw) => switch (raw) {
        'warningSent' => IntegrityAlertStatus.warningSent,
        'dismissed' => IntegrityAlertStatus.dismissed,
        'resolved' => IntegrityAlertStatus.resolved,
        'confirmedViolation' => IntegrityAlertStatus.confirmedViolation,
        _ => IntegrityAlertStatus.pendingReview,
      };

  IntegrityAlertLevel _alertLevel(double confidence) {
    if (confidence >= 0.75) return IntegrityAlertLevel.high;
    if (confidence >= 0.5) return IntegrityAlertLevel.medium;
    return IntegrityAlertLevel.low;
  }

  double _aiConfidence(Map<String, dynamic> row) {
    final p = _asDouble(row['ai_probability']);
    if (p != null) return p.clamp(0.0, 1.0);
    return 0.65;
  }

  String _detectionSummary(Map<String, dynamic> row, double confidence) {
    final pct = (confidence * 100).round();
    final type = (row['file_type'] as String? ?? 'image') == 'video' ? 'video' : 'photo';
    return 'Model indicates this $type may be AI-generated ($pct% confidence). Administrator verification required.';
  }

  String _memberRole(Map<String, dynamic>? user, Map<String, dynamic> row) {
    final task = user?['primary_task_role'] as String? ?? user?['task_role'] as String?;
    if (task != null && task.isNotEmpty) {
      return task.toLowerCase().contains('video') ? 'Videographer' : 'Photographer';
    }
    return (row['file_type'] as String? ?? '') == 'video' ? 'Videographer' : 'Photographer';
  }

  List<Map<String, dynamic>> _enrichMediaWithAi(
    List<Map<String, dynamic>> media,
    List<Map<String, dynamic>> aiRows,
  ) {
    final aiByMedia = <int, Map<String, dynamic>>{};
    for (final row in aiRows) {
      final mid = row['media_id'] as int?;
      if (mid != null) aiByMedia[mid] = row;
    }
    return media.map((row) {
      final id = row['id'] as int? ?? 0;
      final ai = aiByMedia[id];
      final result = (ai?['detection_result'] as String? ?? ai?['ai_result'] as String? ?? '').toLowerCase();
      final detected = row['ai_detected'] as bool? ?? (result.contains('ai') || result.contains('generated'));
      return {
        ...row,
        'ai_detected': detected,
        'ai_probability': row['ai_probability'] ?? ai?['ai_probability'],
        'detection_result': ai?['detection_result'] ?? ai?['ai_result'],
      };
    }).toList();
  }

  bool _isAiRow(Map<String, dynamic> row) {
    if (row['ai_detected'] == true) return true;
    final result = (row['detection_result'] as String? ?? '').toLowerCase();
    return result.contains('ai') || result.contains('generated');
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
