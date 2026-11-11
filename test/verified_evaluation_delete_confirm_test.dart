import 'package:access_mobile/mobile_app/utils/practice_storage_removal.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _verified({String status = 'verified_human'}) {
  return Evaluation(
    id: 'MED-55',
    title: 'Verified shot',
    score: 4.0,
    composition: 'Good',
    lighting: 'Good',
    feedback: 'ok',
    date: 'Nov 11, 2026',
    reviewStatus: status,
    evaluatedAt: DateTime(2026, 11, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cancel on Delete dialog preserves evaluation (no busy flag)',
      (tester) async {
    var busy = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await confirmVerifiedEvaluationDelete(
                      context,
                      evaluation: _verified(),
                      isBusy: () => busy,
                      setBusy: () => busy = true,
                      clearBusy: () => busy = false,
                    );
                  },
                  child: const Text('Start'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Remove file?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(busy, isFalse);
    expect(find.text('Remove file?'), findsNothing);
  });

  testWidgets('Already-removed storage shows blocker toast without dialog',
      (tester) async {
    var busy = false;
    var removed = false;
    final ev = Evaluation(
      id: 'MED-55',
      title: 'Verified shot',
      score: 4.0,
      composition: 'Good',
      lighting: 'Good',
      feedback: 'ok',
      date: 'Nov 11, 2026',
      reviewStatus: 'verified_human',
      storageRemoved: true,
      evaluatedAt: DateTime(2026, 11, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    removed = await confirmVerifiedEvaluationDelete(
                      context,
                      evaluation: ev,
                      isBusy: () => busy,
                      setBusy: () => busy = true,
                      clearBusy: () => busy = false,
                    );
                  },
                  child: const Text('Start'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(removed, isFalse);
    expect(busy, isFalse);
    expect(find.text('Remove file?'), findsNothing);
    expect(
      find.text('This file was already removed from storage.'),
      findsOneWidget,
    );
  });
}
