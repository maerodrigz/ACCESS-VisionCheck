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
    evaluation_row_for_member,
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
    ev = MagicMock()
    ev.criteria_json = json.dumps({"xp_pending": True, "xp_points_preview": 25})
    award_calls: list[int] = []

    def _fake_award(_db, *, media_id, member_id, points):
        del media_id, member_id
        data = json.loads(ev.criteria_json)
        if data.get("xp_awarded_at_review"):
            return 0
        data["xp_awarded_at_review"] = True
        data["xp_pending"] = False
        ev.criteria_json = json.dumps(data)
        award_calls.append(points)
        return points

    with patch("app.services.ai_review_workflow.eval_crud.get_for_media", return_value=ev):
        with patch("app.services.chain_xp_award.apply_chain_xp_award", side_effect=_fake_award):
            assert _award_pending_evaluation_xp(MagicMock(), 9, 3) == 25
            assert _award_pending_evaluation_xp(MagicMock(), 9, 3) == 0
            assert award_calls == [25]


def _member_row(status: str, *, criteria_json: str | None = None):
    payload = {
        "overall_score": 4.0,
        "quality_level": "Fair",
        "member_scores_released": True,
        "criteria": [{"name": "Sharpness", "score": 4, "suggestion": ""}],
    }
    return evaluation_row_for_member(
        criteria_json=criteria_json if criteria_json is not None else json.dumps(payload),
        review_status=status,
        overall_score=0.8,
        feedback="Overall quality looks fair.",
        sharpness_score=4,
        brightness_score=4,
        contrast_score=4,
        blur_score=4,
        noise_score=4,
        quality_level="Fair",
        recommendation="Accepted",
    )


def test_pending_verification_withholds_member_quality() -> None:
    row = _member_row("pending_review")
    assert row[1] == 0.0
    assert row[8] is None
    assert row[9] is None
    assert "Sharpness" not in (row[0] or "")


def test_under_review_withholds_member_quality() -> None:
    row = _member_row("needs_further_review")
    assert row[1] == 0.0
    assert row[8] is None


def test_approved_member_response_keeps_quality() -> None:
    row = _member_row("verified_human")
    assert row[1] == 0.8
    assert row[8] == "Fair"
    assert row[3] == 4


def test_rejected_withholds_quality_even_when_criteria_json_is_invalid() -> None:
    row = _member_row("rejected", criteria_json="not-json")
    assert row[1] == 0.0
    assert row[8] is None
    assert row[3] == 0.0
