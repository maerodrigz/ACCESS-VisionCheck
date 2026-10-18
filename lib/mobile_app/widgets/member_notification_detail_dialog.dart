import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Centered floating card for in-app notification detail (member / requestor).
Future<bool> showMemberNotificationFloatingCard(
  BuildContext context, {
  required String title,
  required String message,
  String? categoryLabel,
  IconData icon = Icons.notifications_outlined,
  Color accent = kAccent,
  String? timeLabel,
  String? primaryActionLabel,
}) async {
  final body = message.trim();
  final displayTitle = title.trim().isEmpty ? 'Notification' : title.trim();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Material(
          color: kSurface,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (categoryLabel != null && categoryLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _CategoryBadgeText(
                                    label: categoryLabel,
                                    accent: accent,
                                  ),
                                ),
                              ),
                            Text(
                              displayTitle,
                              style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
                            ),
                            if (timeLabel != null && timeLabel.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: dashText(const TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                )),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Container(
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
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (primaryActionLabel != null && primaryActionLabel.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: kMemberButtonPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          primaryActionLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (primaryActionLabel != null && primaryActionLabel.isNotEmpty)
                    const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(primaryActionLabel == null ? 'Close' : 'Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  return result == true;
}

class _CategoryBadgeText extends StatelessWidget {
  const _CategoryBadgeText({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim();
    final integrity = normalized.toLowerCase().startsWith('integrity');
    if (integrity) {
      final rest = normalized.length > 'integrity'.length
          ? normalized.substring('integrity'.length)
          : '';
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Integrity',
              style: dashText(TextStyle(
                color: kCyan,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              )),
            ),
            if (rest.isNotEmpty)
              TextSpan(
                text: rest,
                style: dashText(TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )),
              ),
          ],
        ),
      );
    }

    return Text(
      normalized,
      style: dashText(TextStyle(
        color: accent,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      )),
    );
  }
}
