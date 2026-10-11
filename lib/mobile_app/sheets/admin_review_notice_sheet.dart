import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Full admin message from a push/in-app notification (before or beside evaluation report).
void showAdminReviewNoticeSheet(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? onViewEvaluation,
}) {
  final body = message.trim();
  if (body.isEmpty && onViewEvaluation == null) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined, color: kAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title.trim().isEmpty ? 'Administrator message' : title.trim(),
                    style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Text(
                  body,
                  style: memberDashboardBodyStyle.copyWith(
                    color: kTextPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (onViewEvaluation != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onViewEvaluation();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View evaluation', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}

/// Prefer text after "Remarks:" from notification body when API remarks are not synced yet.
String adminRemarksFromNotificationFallback(String? notificationBody) {
  final body = notificationBody?.trim() ?? '';
  if (body.isEmpty) return '';
  final lower = body.toLowerCase();
  const marker = 'remarks:';
  final idx = lower.indexOf(marker);
  if (idx >= 0) {
    return body.substring(idx + marker.length).trim();
  }
  return body;
}
