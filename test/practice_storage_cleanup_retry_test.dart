import 'package:access_mobile/mobile_app/widgets/practice_storage_cleanup_retry.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _eval({
  bool storageRemoved = false,
  bool cleanupPending = false,
  double score = 4.2,
}) {
  return Evaluation(
    id: 'MED-15',
    title: 'Practice photo',
    score: score,
    composition: 'Good',
    lighting: 'Good',
    feedback: 'kept',
    date: 'Nov 18, 2026',
    reviewStatus: 'verified_human',
    storageRemoved: storageRemoved,
    storageCleanupPending: cleanupPending,
  );
}

void main() {
  test('removed file keeps the score and only pending cleanup can retry', () {
    final pending = _eval(storageRemoved: true, cleanupPending: true).markStorageRemoved(
      cleanupPending: true,
    );
    expect(pending.score, 4.2);
    expect(pending.feedback, 'kept');
    expect(pending.canRetryFileRemoval, isTrue);
    expect(pending.canRemovePracticeStorage, isFalse);

    final done = pending.markStorageRemoved();
    expect(done.score, 4.2);
    expect(done.storageCleanupPending, isFalse);
    expect(done.canRetryFileRemoval, isFalse);
  });

  testWidgets('history shows retry only while cleanup is pending', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeStorageCleanupRetry(
            evaluation: _eval(storageRemoved: true, cleanupPending: true),
          ),
        ),
      ),
    );

    expect(find.text('File cleanup pending'), findsOneWidget);
    expect(find.text('Retry File Removal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed deletion does not offer another retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeStorageCleanupRetry(
            evaluation: _eval(storageRemoved: true),
          ),
        ),
      ),
    );

    expect(find.text('File cleanup pending'), findsNothing);
    expect(find.text('Retry File Removal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
