import 'dart:async';

import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Compact status for a retained evaluation whose cloud file still needs deletion.
class PracticeStorageCleanupRetry extends StatelessWidget {
  const PracticeStorageCleanupRetry({
    super.key,
    required this.evaluation,
    this.onDark = false,
  });

  final Evaluation evaluation;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (!evaluation.canRetryFileRemoval) return const SizedBox.shrink();
    final mediaId = evaluation.practiceMediaId;
    if (mediaId == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: memberDataController,
      builder: (context, _) {
        final busy = memberDataController.isStorageRemovalInFlight(mediaId);
        final labelColor = onDark ? Colors.white : kTextSecondary;
        final actionColor = onDark ? Colors.white : kAccent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File cleanup pending',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dashText(TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              )),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('retry_file_removal'),
                onPressed: busy
                    ? null
                    : () {
                        unawaited(_retry(context, mediaId));
                      },
                style: TextButton.styleFrom(
                  foregroundColor: actionColor,
                  disabledForegroundColor: actionColor.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: busy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: actionColor,
                        ),
                      )
                    : const Text(
                        'Retry File Removal',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _retry(BuildContext context, int mediaId) async {
    final err = await memberDataController.removePracticeEvaluationStorage(mediaId);
    if (!context.mounted) return;
    if (err != null) {
      showMobileToast(context, err, success: false);
      return;
    }
    showMobileToast(context, 'File removed. Your score is unchanged.', success: true);
  }
}
