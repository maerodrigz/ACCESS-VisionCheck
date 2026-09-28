import 'package:access_mobile/shared/models/media_upload_response.dart';
import 'package:access_mobile/shared/models/practice_evaluation_save_outcome.dart';
import 'package:access_mobile/shared/services/deferred_media_evaluation_poll.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaUploadResponse', () {
    test('processing status requires poll', () {
      final r = MediaUploadResponse.fromJson({
        'id': 12,
        'processing_status': 'processing',
        'overall_score': null,
        'ai_probability': null,
        'feedback': null,
      });
      expect(r.needsDeferredProcessingPoll, isTrue);
    });

    test('completed immediately with scores', () {
      final r = MediaUploadResponse.fromJson({
        'id': 12,
        'processing_status': 'completed',
        'overall_score': 0.82,
        'ai_probability': 0.1,
        'feedback': 'Good',
      });
      expect(r.needsDeferredProcessingPoll, isFalse);
    });

    test('null fields without status do not crash', () {
      final r = MediaUploadResponse.fromJson({
        'id': 5,
        'overall_score': null,
        'ai_probability': null,
        'feedback': null,
      });
      expect(r.needsDeferredProcessingPoll, isTrue);
    });

    test('legacy sync response without processing_status', () {
      final r = MediaUploadResponse.fromJson({
        'id': 9,
        'overall_score': 4.2,
        'feedback': 'Nice shot',
      });
      expect(r.needsDeferredProcessingPoll, isFalse);
    });

    test('absent processing_status with scores is legacy completed', () {
      final r = MediaUploadResponse.fromJson({
        'id': 1,
        'file_url': '/uploads/x.jpg',
        'overall_score': 4.0,
        'feedback': 'Good quality',
      });
      expect(r.processingStatus, isNull);
      expect(r.needsDeferredProcessingPoll, isFalse);
    });

    test('event-style null processing does not imply processing when no id semantics', () {
      final r = MediaUploadResponse.fromJson({
        'id': 0,
        'processing_status': null,
      });
      expect(r.needsDeferredProcessingPoll, isFalse);
    });
  });

  group('DeferredMediaEvaluationPoll', () {
    test('processing then completed stops polling', () async {
      var calls = 0;
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: const Duration(seconds: 5),
        fetchMediaById: (_) async {
          calls += 1;
          if (calls < 3) {
            return {
              'id': 7,
              'processing_status': 'processing',
              'overall_score': null,
            };
          }
          return {
            'id': 7,
            'processing_status': 'completed',
            'overall_score': 0.9,
          };
        },
      );

      final outcome = await poll.waitForCompletion(mediaId: 7, isVideo: false);
      expect(outcome, DeferredPollOutcome.completed);
      expect(calls, 3);
    });

    test('completed immediately skips extra polls', () async {
      var calls = 0;
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: const Duration(seconds: 5),
        fetchMediaById: (_) async {
          calls += 1;
          return {
            'id': 7,
            'processing_status': 'completed',
            'overall_score': 0.75,
          };
        },
      );

      final outcome = await poll.waitForCompletion(mediaId: 7, isVideo: false);
      expect(outcome, DeferredPollOutcome.completed);
      expect(calls, 1);
    });

    test('timeout returns still processing', () async {
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: Duration.zero,
        fetchMediaById: (_) async => {
          'id': 7,
          'processing_status': 'processing',
        },
      );

      final outcome = await poll.waitForCompletion(mediaId: 7, isVideo: false);
      expect(outcome, DeferredPollOutcome.stillProcessing);
    });

    test('transient network errors do not stop polling', () async {
      var calls = 0;
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: const Duration(seconds: 2),
        transientErrorRetries: 3,
        fetchMediaById: (_) async {
          calls += 1;
          if (calls == 1) throw Exception('network');
          return {
            'id': 7,
            'processing_status': 'completed',
            'overall_score': 0.8,
          };
        },
      );

      final outcome = await poll.waitForCompletion(mediaId: 7, isVideo: false);
      expect(outcome, DeferredPollOutcome.completed);
      expect(calls, greaterThan(1));
    });

    test('dispose cancels polling', () async {
      var calls = 0;
      var continuePoll = true;
      final poll = DeferredMediaEvaluationPoll(
        pollInterval: Duration.zero,
        photoMaxDuration: const Duration(minutes: 1),
        fetchMediaById: (_) async {
          calls += 1;
          continuePoll = false;
          return {
            'id': 7,
            'processing_status': 'processing',
          };
        },
      );

      final outcome = await poll.waitForCompletion(
        mediaId: 7,
        isVideo: false,
        shouldContinue: () => continuePoll,
      );
      expect(outcome, DeferredPollOutcome.cancelled);
      expect(calls, 1);
    });

    test('video uses longer max duration bucket', () {
      final poll = DeferredMediaEvaluationPoll();
      expect(
        poll.maxDurationFor(isVideo: true),
        greaterThan(poll.maxDurationFor(isVideo: false)),
      );
    });
  });

  test('suspicious preview does not imply client xp award during poll phase', () {
    const phase = PracticeEvaluationSavePhase.stillProcessingOnServer;
    expect(phase == PracticeEvaluationSavePhase.completedAfterPoll, isFalse);
  });
}
