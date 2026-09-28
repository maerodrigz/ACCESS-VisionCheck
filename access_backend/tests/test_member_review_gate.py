"""Review gate: held scores/Gemini/XP until admin final decision (mocked)."""

from __future__ import annotations

import io
import json
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from app.services.ai_authenticity_detector import detect_ai_generated
from app.services.camera_provenance import CameraProvenanceResult
from app.services.integrity_evaluation_policy import apply_integrity_evaluation_policy, xp_award_points_from_payload
from app.services.member_score_release import (
    member_may_view_scores,
    redact_criteria_json_for_member,
    release_member_evaluation_scores,
)
from app.services.ai_review_workflow import _award_pending_evaluation_xp

PROBE_BACKEND = "app.services.ai_authenticity_detector.active_ai_detector_backend"
PROBE_PROB = "app.services.ai_authenticity_detector.dedicated_ai_probability"
CLASSIFY = "app.services.camera_provenance.classify_photo_camera_provenance"


def _jpeg() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (24, 24)).save(buf, format="JPEG")
    return buf.getvalue()


def _detect(p: float, provenance: str) -> dict:
    prov = CameraProvenanceResult(provenance, reasons=["test"])
    with patch(PROBE_BACKEND, return_value="probe"):
        with patch(PROBE_PROB, return_value=p):
            with patch(CLASSIFY, return_value=prov):
                return detect_ai_generated(_jpeg(), file_name="t.jpg")


def _payload(ai: dict) -> dict:
    return apply_integrity_evaluation_policy(
        {
            "criteria": [{"name": "Sharpness", "score": 4, "explanation": "", "suggestion": ""}],
            "overall_score": 4.0,
            "legacy": {"overall_score": 0.8},
            "ai_detection": ai,
        }
    )


def test_clear_strong_low_releases_scores_and_xp() -> None:
    ai = _detect(0.05, "strong")
    payload = _payload(ai)
    assert payload["member_scores_released"] is True
    assert payload["show_quality_feedback"] is True
    assert payload["xp_pending"] is False
    assert xp_award_points_from_payload(payload) > 0


def test_source_unverified_holds_scores_and_gemini_slot() -> None:
    ai = _detect(0.05, "absent")
    payload = _payload(ai)
    assert ai["requires_review"] is True
    assert payload["member_scores_released"] is False
    assert payload["show_quality_feedback"] is False
    assert payload["xp_pending"] is True
    assert "gemini_feedback" not in payload
    assert not member_may_view_scores(payload, "needs_further_review")


def test_suspicious_holds_member_view() -> None:
    ai = _detect(0.35, "absent")
    payload = _payload(ai)
    assert payload["member_scores_released"] is False
    redacted = redact_criteria_json_for_member(payload, "needs_further_review")
    assert redacted.get("criteria") is None
    assert redacted.get("overall_score") is None


def test_admin_verify_human_releases_and_gemini_once() -> None:
    ai = _detect(0.35, "absent")
    payload = _payload(ai)
    criteria = json.dumps(payload)
    ev = MagicMock()
    ev.criteria_json = criteria
    ev.feedback = "held"

    with patch("app.services.member_score_release.eval_crud.get_for_media", return_value=ev):
        with patch(
            "app.services.member_score_release.gemini_service.generate_media_evaluation_feedback",
            return_value={"explanation": "Great job"},
        ) as gen:
            assert release_member_evaluation_scores(MagicMock(), 1, member_first_name="Alex") is True
            gen.assert_called_once()
            data = json.loads(ev.criteria_json)
            assert data["member_scores_released"] is True
            assert data.get("gemini_feedback")
            assert release_member_evaluation_scores(MagicMock(), 1) is True
            gen.assert_called_once()


def test_xp_awarded_once_after_verify() -> None:
    state = {"criteria_json": json.dumps({"xp_pending": True, "xp_points_preview": 25})}
    ev = MagicMock(**state)
    with patch("app.services.ai_review_workflow.eval_crud.get_for_media", return_value=ev):
        with patch("app.services.ai_review_workflow.ranking_crud.add_points") as add:
            assert _award_pending_evaluation_xp(MagicMock(), 9, 3) == 25
            assert _award_pending_evaluation_xp(MagicMock(), 9, 3) == 0
            assert add.call_count == 1
