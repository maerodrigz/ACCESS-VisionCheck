"""Tests for AI review status after member upload."""

from app.services.ai_review_workflow import initial_review_status
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
