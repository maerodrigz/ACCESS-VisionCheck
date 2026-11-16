import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

void main() {
  group('Evaluation re-upload lock', () {
    test('uses server can_reupload when present', () {
      final ev = Evaluation(
        id: 'MED-1',
        title: 'Test',
        score: 0.8,
        composition: 'Good',
        lighting: 'Good',
        feedback: '',
        date: 'Today',
        reviewStatus: 'reupload_requested',
        canReupload: false,
        activeReplacementMediaId: null,
        awaitingReplacementMediaId: 1,
      );
      expect(ev.canSubmitLinkedReplacement, isFalse);
    });

    test('allows upload when server can_reupload is true', () {
      final ev = Evaluation(
        id: 'MED-1',
        title: 'Test',
        score: 0.8,
        composition: 'Good',
        lighting: 'Good',
        feedback: '',
        date: 'Today',
        reviewStatus: 'reupload_requested',
        canReupload: true,
        awaitingReplacementMediaId: 1,
      );
      expect(ev.canSubmitLinkedReplacement, isTrue);
    });

    test('replacement verified keeps workflow section visible', () {
      final ev = Evaluation(
        id: 'MED-1',
        title: 'Test',
        score: 0.8,
        composition: 'Good',
        lighting: 'Good',
        feedback: '',
        date: 'Today',
        reviewStatus: 'verified_human',
        canReupload: false,
        replacementVerified: true,
      );
      expect(ev.showReuploadWorkflowSection, isTrue);
      expect(ev.canSubmitLinkedReplacement, isFalse);
    });
  });
}
