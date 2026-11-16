import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _eval({
  String id = 'MED-42',
  double score = 4.0,
  String? reviewStatus,
  bool storageRemoved = false,
  bool analyzing = false,
}) {
  return Evaluation(
    id: id,
    title: 'Practice shot',
    score: score,
    composition: 'Good',
    lighting: 'Good',
    feedback: 'ok',
    date: 'Nov 11, 2026',
    reviewStatus: reviewStatus,
    storageRemoved: storageRemoved,
    isAnalysisInProgress: analyzing,
  );
}

void main() {
  group('canRemovePracticeStorage', () {
    test('allows remove for admin-verified human', () {
      final ev = _eval(reviewStatus: 'verified_human');
      expect(MemberReviewStatus.isAdminVerified(ev.reviewStatus), isTrue);
      expect(ev.canRemovePracticeStorage, isTrue);
    });

    test('allows remove for accepted_with_warning', () {
      final ev = _eval(reviewStatus: 'accepted_with_warning');
      expect(ev.canRemovePracticeStorage, isTrue);
    });

    test('keeps remove for pending_review when scored', () {
      final ev = _eval(reviewStatus: 'pending_review', score: 4.1);
      expect(ev.canRemovePracticeStorage, isTrue);
    });

    test('keeps remove for needs_further_review when scored', () {
      final ev = _eval(reviewStatus: 'needs_further_review', score: 3.8);
      expect(ev.canRemovePracticeStorage, isTrue);
    });

    test('keeps existing rule: pending score hides remove', () {
      final ev = _eval(reviewStatus: 'pending_review', score: 0);
      expect(ev.isPending, isTrue);
      expect(ev.canRemovePracticeStorage, isFalse);
    });

    test('keeps remove for automated_low_ai_risk when scored', () {
      final ev = _eval(reviewStatus: 'automated_low_ai_risk', score: 4.2);
      expect(ev.canRemovePracticeStorage, isTrue);
    });

    test('hides remove when storage already removed', () {
      final ev = _eval(reviewStatus: 'verified_human', storageRemoved: true);
      expect(ev.canRemovePracticeStorage, isFalse);
    });
  });
}
