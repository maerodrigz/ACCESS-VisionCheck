import 'dart:async';

import 'package:access_mobile/shared/models/media_upload_response.dart';

typedef FetchMediaById = Future<Map<String, dynamic>?> Function(int mediaId);

enum DeferredPollOutcome {
  completed,
  stillProcessing,
  cancelled,
}

class DeferredMediaEvaluationPoll {
  DeferredMediaEvaluationPoll({
    this.fetchMediaById,
    this.pollInterval = const Duration(milliseconds: 1200),
    this.photoMaxDuration = const Duration(minutes: 3),
    this.videoMaxDuration = const Duration(minutes: 6),
    this.transientErrorRetries = 2,
  });

  final FetchMediaById? fetchMediaById;
  final Duration pollInterval;
  final Duration photoMaxDuration;
  final Duration videoMaxDuration;
  final int transientErrorRetries;

  Duration maxDurationFor({required bool isVideo}) =>
      isVideo ? videoMaxDuration : photoMaxDuration;

  /// Poll until completed, timeout, or [shouldContinue] returns false.
  Future<DeferredPollOutcome> waitForCompletion({
    required int mediaId,
    required bool isVideo,
    bool Function()? shouldContinue,
  }) async {
    final fetch = fetchMediaById;
    if (fetch == null || mediaId <= 0) {
      return DeferredPollOutcome.stillProcessing;
    }

    final deadline = DateTime.now().add(maxDurationFor(isVideo: isVideo));
    var consecutiveErrors = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (shouldContinue != null && !shouldContinue()) {
        return DeferredPollOutcome.cancelled;
      }

      Map<String, dynamic>? row;
      try {
        row = await fetch(mediaId);
        consecutiveErrors = 0;
      } catch (_) {
        consecutiveErrors += 1;
        if (consecutiveErrors > transientErrorRetries) {
          await Future<void>.delayed(pollInterval);
          continue;
        }
        await Future<void>.delayed(pollInterval);
        continue;
      }

      if (row == null) {
        await Future<void>.delayed(pollInterval);
        continue;
      }

      final parsed = MediaUploadResponse.fromJson(row);
      if (_isServerCompleted(parsed)) {
        return DeferredPollOutcome.completed;
      }

      await Future<void>.delayed(pollInterval);
    }

    return DeferredPollOutcome.stillProcessing;
  }

  bool _isServerCompleted(MediaUploadResponse parsed) {
    if (parsed.isExplicitCompleted) return true;
    if (parsed.isExplicitProcessing) return false;
    return parsed.overallScore != null ||
        parsed.aiProbability != null ||
        (parsed.feedback != null && parsed.feedback!.trim().isNotEmpty);
  }
}
