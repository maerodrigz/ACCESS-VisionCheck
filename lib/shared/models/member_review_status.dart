/// Admin AI integrity review statuses from GET /evaluations (`review_status`).
abstract final class MemberReviewStatus {
  static String normalize(String? raw) => (raw ?? '').trim().toLowerCase();

  static bool isReviewPending(String? raw) {
    final n = normalize(raw);
    return n == 'pending_review' || n == 'needs_further_review';
  }

  /// Automated PROBE clearance — not a human admin decision and not a manual queue item.
  static bool isAutomatedLowAiRisk(String? raw) {
    return normalize(raw) == 'automated_low_ai_risk';
  }

  /// Final admin (or terminal) decision — not automated-only clearance.
  static bool isFinalAdminDecision(String? raw) {
    final n = normalize(raw);
    if (n.isEmpty) return false;
    if (isReviewPending(raw)) return false;
    if (n == 'automated_low_ai_risk') return false;
    return true;
  }

  static bool isAdminConfirmedHuman(String? raw) {
    final n = normalize(raw);
    return n == 'verified_human';
  }

  static bool isAdminConfirmedAi(String? raw) {
    final n = normalize(raw);
    return n == 'confirmed_ai_generated' ||
        n.contains('confirmed_ai') ||
        n.contains('verified_ai');
  }

  static bool isAdminRejected(String? raw) {
    final n = normalize(raw);
    return n == 'rejected';
  }

  static bool isReuploadRequested(String? raw) {
    final n = normalize(raw);
    return n.contains('reupload');
  }

  static bool isAcceptedWithWarning(String? raw) {
    final n = normalize(raw);
    return n.contains('accepted') && n.contains('warning');
  }
}
