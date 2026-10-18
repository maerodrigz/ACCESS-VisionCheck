import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';

Future<void> confirmAndRemovePracticeStorage(
  BuildContext context, {
  required Evaluation evaluation,
  bool popAfterSuccess = false,
}) async {
  if (!evaluation.canRemovePracticeStorage) return;
  final mediaId = evaluation.practiceMediaId;
  if (mediaId == null) return;

  final ok = await showMobileConfirmDialog(
    context,
    title: 'Remove file?',
    message:
        'This deletes the photo or video from cloud storage to save space. '
        'Your score, XP, and evaluation report stay on your account.',
    confirmLabel: 'Remove file',
    destructive: true,
  );
  if (!ok || !context.mounted) return;

  final err = await memberDataController.removePracticeEvaluationStorage(mediaId);
  if (!context.mounted) return;
  if (err != null) {
    showMobileToast(context, err, success: false);
    return;
  }
  showMobileToast(context, 'File removed. Your score is unchanged.', success: true);
  if (popAfterSuccess && Navigator.canPop(context)) {
    Navigator.pop(context);
  }
}
