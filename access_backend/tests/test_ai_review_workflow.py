"""Tests for AI review status after member upload."""

from unittest.mock import MagicMock, patch

from app.services.ai_review_workflow import apply_ai_review, initial_review_status
from app.services.media_pipeline import _ai_from_payload


def test_authentic_human_auto_verified_not_pending():
    """28% synthetic signal (authentic) must not sit in admin pending queue."""
    prob, label, _ = _ai_from_payload(
        {"verdict": "authentic", "confidence": 0.72, "probability": 0.28}
    )
    assert label == "human"
    assert prob == 0.28
    assert initial_review_status(label, prob) == "verified_human"


def test_suspicious_verdict_needs_review():
    prob, label, _ = _ai_from_payload(
        {"verdict": "suspicious", "confidence": 0.42, "probability": 0.42}
    )
    assert label == "suspicious"
    assert initial_review_status(label, prob) == "needs_further_review"


def test_ai_generated_pending_review():
    prob, label, _ = _ai_from_payload(
        {"verdict": "ai_generated", "confidence": 0.82, "probability": 0.82}
    )
    assert label == "ai_generated"
    assert initial_review_status(label, prob) == "pending_review"


def test_borderline_synthetic_signal_needs_review():
    prob, label, _ = _ai_from_payload(
        {"verdict": "authentic", "confidence": 0.60, "probability": 0.40}
    )
    assert label == "human"
    assert initial_review_status(label, prob) == "needs_further_review"


def test_confirm_ai_archives_media_for_gallery():
    row = MagicMock()
    row.id = 10
    row.media_id = 55
    row.review_status = "pending_review"
    row.detection_result = "ai_generated"
    row.ai_probability = 0.9
    row.admin_remarks = None
    row.media = MagicMock(uploaded_by=3)

    db = MagicMock()

    with patch("app.crud.archive.create_if_not_exists") as archive:
        with patch("app.services.notification_events.notify_user"):
            with patch("app.crud.user.get_by_id", return_value=None):
                with patch("app.services.ai_review_workflow.ranking_crud.add_points"):
                    apply_ai_review(
                        db,
                        row,
                        review_status="confirmed_ai_generated",
                        admin_remarks="Confirmed AI.",
                        reviewed_by=1,
                    )

    archive.assert_called_once_with(db, 55, 1)
