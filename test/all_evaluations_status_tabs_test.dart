import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

Evaluation _ev({
  required String id,
  required String title,
  String? reviewStatus,
  double score = 4.0,
}) {
  return Evaluation(
    id: id,
    title: title,
    score: score,
    composition: 'Good',
    lighting: 'Good',
    feedback: 'ok',
    date: 'Nov 11, 2026',
    reviewStatus: reviewStatus,
    evaluatedAt: DateTime(2026, 11, 11),
  );
}

/// Mirrors All Evaluations tab partition in evaluation_screen.dart.
bool isPendingVerificationEval(Evaluation e) {
  if (MemberReviewStatus.isAdminVerified(e.reviewStatus)) return false;
  if (MemberReviewStatus.isReviewPending(e.reviewStatus)) return true;
  if (MemberReviewStatus.isReuploadRequested(e.reviewStatus)) return true;
  if (e.isPending) return true;
  return false;
}

bool isVerifiedEval(Evaluation e) => !isPendingVerificationEval(e);

void main() {
  group('All Evaluations status partition', () {
    test('pending_review stays pending; verified_human moves to verified', () {
      final pending = _ev(
        id: 'MED-1',
        title: 'Waiting',
        reviewStatus: 'pending_review',
      );
      final verified = _ev(
        id: 'MED-2',
        title: 'Done',
        reviewStatus: 'verified_human',
      );

      expect(isPendingVerificationEval(pending), isTrue);
      expect(isVerifiedEval(pending), isFalse);
      expect(isPendingVerificationEval(verified), isFalse);
      expect(isVerifiedEval(verified), isTrue);
    });

    test('partition has no duplicates across tabs', () {
      final all = [
        _ev(id: 'MED-1', title: 'a', reviewStatus: 'pending_review'),
        _ev(id: 'MED-2', title: 'b', reviewStatus: 'needs_further_review'),
        _ev(id: 'MED-3', title: 'c', reviewStatus: 'verified_human'),
        _ev(id: 'MED-4', title: 'd', reviewStatus: 'accepted_with_warning'),
        _ev(id: 'MED-5', title: 'e', reviewStatus: 'automated_low_ai_risk'),
        _ev(id: 'MED-6', title: 'f', reviewStatus: null, score: 0),
      ];

      final pending = all.where(isPendingVerificationEval).toList();
      final verified = all.where(isVerifiedEval).toList();
      final pendingIds = pending.map((e) => e.id).toSet();
      final verifiedIds = verified.map((e) => e.id).toSet();

      expect(pendingIds.intersection(verifiedIds), isEmpty);
      expect(pendingIds.union(verifiedIds), all.map((e) => e.id).toSet());
      expect(pending.length, 3);
      expect(verified.length, 3);
    });

    test('admin verified has no remove action eligibility', () {
      final verified = _ev(
        id: 'MED-9',
        title: 'Verified',
        reviewStatus: 'verified_human',
      );
      expect(verified.canRemovePracticeStorage, isFalse);
    });
  });
}
