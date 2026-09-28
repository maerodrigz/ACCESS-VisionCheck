import 'package:access_mobile/shared/models/media_upload_response.dart';
import 'package:access_mobile/shared/services/deferred_media_evaluation_poll.dart';

enum PracticeEvaluationSavePhase {
  completedImmediately,
  completedAfterPoll,
  stillProcessingOnServer,
  uploadFailed,
}

class PracticeEvaluationSaveOutcome {
  const PracticeEvaluationSaveOutcome({
    required this.phase,
    this.upload,
    this.pollOutcome,
  });

  final PracticeEvaluationSavePhase phase;
  final MediaUploadResponse? upload;
  final DeferredPollOutcome? pollOutcome;

  bool get uploadSucceeded =>
      phase != PracticeEvaluationSavePhase.uploadFailed;

  bool get evaluationSettledOnServer =>
      phase == PracticeEvaluationSavePhase.completedImmediately ||
      phase == PracticeEvaluationSavePhase.completedAfterPoll;
}
